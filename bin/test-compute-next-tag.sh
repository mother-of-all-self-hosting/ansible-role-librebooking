#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role files and
# a release history, and then replays a series of merges through the real script,
# tagging as it goes just like the autotag workflow does. This repository is never
# touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at LibreBooking 4.3.0 which has already seen one
# release of it (v4.3.0-0), plus `v4-0` and `v4.3-0`. Docker Hub publishes flavoured
# tags alongside the real ones, and the commit-message era read the version straight
# out of Renovate's subject line - which is how this repository ended up with a real
# `v5-0` tag on a commit that set `librebooking_version: 5.3.0`. Tags shaped like that
# are exactly what a regression would produce, and must not be counted as releases of
# anything.
#
# The defaults file carries the traps this role's real one has: a commented-out example
# of the version variable, the Renovate annotation that has to keep sitting on the leaf
# literal, and an image tag derived from it. Neither may be picked up as the version.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/meta" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	cat > defaults/main.yml <<-'YAML'
		# librebooking_version: 9.9.9
		# renovate: datasource=docker depName=librebooking/librebooking versioning=semver
		librebooking_version: 4.3.0
		librebooking_container_image: "{{ librebooking_container_image_registry_prefix }}librebooking/librebooking:{{ librebooking_container_image_tag }}"
		librebooking_container_image_tag: "{{ librebooking_version }}"
	YAML
	printf 'placeholder\n' > meta/main.yml
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	git add -A
	git commit -qm 'Initial commit'

	local tag
	for tag in v4-0 v4.3-0 v4.3.0-0; do
		git tag "$tag"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be. Prints
# the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version="sed -i 's|^librebooking_version: 4.3.0|librebooking_version: 5.3.0|' defaults/main.yml"
revert_version="sed -i 's|^librebooking_version: 5.3.0|librebooking_version: 4.3.0|' defaults/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_meta="printf 'a field\n' >> meta/main.yml"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with every
# update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v5.3.0-0 "$(merge "$bump_version")"
expect 'task edit'    v5.3.0-1 "$(merge "$edit_task")"
expect 'template'     v5.3.0-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v4.3.0-1 "$(merge "$edit_task")"
expect 'version bump' v5.3.0-0 "$(merge "$bump_version")"

# `v4-0` and `v4.3-0` exist in every scenario, and `v5-0` is a tag this repository
# really carries. If the version were ever read as a bare major or as `major.minor` -
# which is exactly what the commit-message era did here - the counter would continue
# from those instead of starting afresh.
scenario 'The truncated tags that a version misread would land on'
expect 'a task' v4.3.0-1 "$(merge "$edit_task")"

scenario 'A version bump onto a major that was mistagged as `v5-0`'
git tag v5-0
expect 'version bump' v5.3.0-0 "$(merge "$bump_version")"

# The annotation Renovate edits has to stay on `librebooking_version`. If a refactor
# ever moved it onto the derived image tag, the leaf the script reads and the leaf
# Renovate writes would drift apart, so the fixture keeps both lines and the derived
# one must never be picked up.
scenario 'The derived image tag is not the version'
expect 'a template' v4.3.0-1 "$(merge "$edit_template")"

scenario 'Commits that do not affect the role'
expect 'README'   ''          "$(merge "$edit_readme")"
expect 'a script' ''          "$(merge "$edit_script")"
expect 'meta'     v4.3.0-1    "$(merge "$edit_meta")"

scenario 'Release numbers past 9'
for release_number in 1 2 3 4 5 6 7 8 9 10; do
	git tag "v4.3.0-$release_number"
done
expect 'a task' v4.3.0-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v4.3.0-0 already published, so there is nothing new
# to release.
expect 'a revert' '' "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v4.3.0-1 "$(merge "$revert_version && $edit_task")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
