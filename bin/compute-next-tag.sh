#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Prints the tag that the currently checked out commit should be released as,
# or nothing at all if it does not warrant a release.
#
# Usage: bin/compute-next-tag.sh
#
# Tags look like `v<LibreBooking version>-<release>`, which is what this repository
# publishes (v4.2.0-1 ... v4.3.0-0):
#
# - if defaults/main.yml points at a LibreBooking version that has never been released,
#   the release counter restarts at 0 (`v5.3.0-0`)
# - otherwise the counter is incremented (`v5.3.0-1`), but only if something that
#   actually affects the role has changed since the last release
#
# Determining the version from defaults/main.yml, rather than from the commit message
# of the pull request that got merged, makes the result independent of the order in
# which pull requests get merged, and lets any change to the role (bugfix, feature,
# dependency bump) release itself without a human tagging.
#
# The commit-message approach this replaced read the version out of Renovate's subject
# line, and this repository has the scar to show for it: Renovate titled a major bump
# "Update librebooking/librebooking Docker tag to v5", so the old workflow cut a tag
# named `v5-0` for a commit that had actually set `librebooking_version: 5.3.0`. It
# also meant a commit landing any other way - a fix pushed from a phone, a rebase that
# reworded the subject - was never released at all.

set -euo pipefail

repository_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$repository_path"

defaults_path='defaults/main.yml'

# Paths that shape the behavior of the role for its consumers. A commit touching only
# other paths (a README fix, CI configuration, Molecule tests) does not change what a
# playbook run does, and releasing it would only create churn in the repositories that
# consume this role.
role_defining_paths=(
	'defaults'
	'meta'
	'tasks'
	'templates'
)

# Anchored on `librebooking_version:` so that neither a commented-out example nor
# `librebooking_container_image_tag`, which is derived from it, can be mistaken for it.
version="$(sed -nE 's|^librebooking_version:[[:space:]]*"?([^"[:space:]]+)"?.*$|\1|p' "$defaults_path" | head -n1)"

if [ -z "$version" ]; then
	echo >&2 "Could not determine the LibreBooking version from $defaults_path"
	exit 1
fi

# LibreBooking's own version is carried without a leading `v` (the `v` lives only in
# the tags), but tolerate one so that a future change of convention does not produce a
# doubled prefix.
tag_prefix="v${version#v}-"

# Of all releases of this version, the highest release number. Sorted numerically, so
# that -10 is recognized as newer than -9.
last_release="$(git tag --list "${tag_prefix}*" | sed -e "s|^${tag_prefix}||" | grep -E '^[0-9]+$' | sort -n | tail -n1 || true)"

if [ -z "$last_release" ]; then
	echo >&2 "Version $version has never been released"
	echo "${tag_prefix}0"
	exit 0
fi

previous_tag="${tag_prefix}${last_release}"

if git diff --quiet "$previous_tag" HEAD -- "${role_defining_paths[@]}"; then
	echo >&2 "Nothing affecting the role has changed since $previous_tag"
	exit 0
fi

echo >&2 "The role has changed since $previous_tag"
echo "${tag_prefix}$((last_release + 1))"
