<!--
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2020-2024 MDAD project contributors
SPDX-FileCopyrightText: 2020-2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara
SPDX-FileCopyrightText: 2026 shukon

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up LibreBooking

This is an [Ansible](https://www.ansible.com/) role which installs [LibreBooking](https://github.com/LibreBooking/librebooking) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

LibreBooking is a resource scheduling application and a FOSS fork of Booked Scheduler.

See the project's [documentation](https://librebooking.readthedocs.io/) to learn what LibreBooking does and why it might be useful to you.

## Prerequisites

To run a LibreBooking instance it is necessary to prepare a [MySQL](https://www.mysql.com/) compatible database server.

If you are looking for an Ansible role for [MariaDB](https://mariadb.org/), you can check out [this role (ansible-role-mariadb)](https://github.com/mother-of-all-self-hosting/ansible-role-mariadb) maintained by the [Mother-of-All-Self-Hosting (MASH)](https://github.com/mother-of-all-self-hosting) team.

## Adjusting the playbook configuration

To enable LibreBooking with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# librebooking                                                         #
#                                                                      #
########################################################################

librebooking_enabled: true

# Protects the /Web/install/ setup wizard. Use a strong password.
librebooking_environment_variables_lb_install_password: "your-strong-install-password-here"

# Optional: set the timezone
# librebooking_environment_variables_lb_default_timezone: "Europe/Berlin"

# Optional: enable background cron jobs (for reminder emails, etc.)
# librebooking_environment_variables_lb_cron_enabled: true

# Optional: allow users to self-register accounts (disabled by default).
# Enable temporarily if you need to register your admin account manually.
# librebooking_environment_variables_lb_registration_allow_self_registration: true

# Optional: pass extra LB_ environment variables to configure the application.
# See: https://librebooking.readthedocs.io/en/stable/BASIC-CONFIGURATION.html
# librebooking_environment_variables_additional_variables: |
#   LB_APP_TITLE='My Booking System'

########################################################################
#                                                                      #
# /librebooking                                                        #
#                                                                      #
########################################################################
```

### Set the hostname

To enable LibreBooking you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
librebooking_hostname: "example.com"
```

After adjusting the hostname, make sure to adjust your DNS records to point the domain to your server.

**Note**: hosting LibreBooking under a subpath (by configuring the `librebooking_path_prefix` variable) does not seem to be possible due to LibreBooking's technical limitations.

### Set variables for the database server

To have the LibreBooking instance connect to your MySQL-compatible database server, add the following configuration to your `vars.yml` file.

```yaml
librebooking_database_hostname: YOUR_MYSQL_SERVER_HOSTNAME_HERE
librebooking_database_username: YOUR_MYSQL_SERVER_USERNAME_HERE
librebooking_database_password: YOUR_MYSQL_SERVER_PASSWORD_HERE
librebooking_database_name: YOUR_MYSQL_SERVER_DATABASE_NAME_HERE
```

### Extending the configuration

There are some additional things you may wish to configure about the service.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `librebooking_environment_variables_additional_variables` variable

See [the official documentation](https://librebooking.readthedocs.io/en/latest/ADVANCED-CONFIGURATION.html#environment-variable-override) for a complete list of LibreBooking's config options that you could put in `librebooking_environment_variables_additional_variables`.

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, LibreBooking becomes available at the specified hostname like `https://example.com`.

To get started, open the URL `https://example.com/Web/install/` with a web browser, and follow the set up wizard.

On the set up wizard,

- Enter the database credentials
- **Check "Import sample data"** — this creates the database schema and an initial `admin`/`password` account
- Do **NOT** check "Create the database" or "Create the database user" — both already exist

Once the installation is complete, keep `librebooking_environment_variables_lb_install_password` set to a strong value to prevent unauthorized access to the setup page.

### Outputting database credentials

On the set up wizard, it is required to input database credentials to use a MySQL compatible database. You can output its credentials by running the playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=print-db-credentials-librebooking
```

### Configuring OAuth2 login (optional)

LibreBooking supports OAuth2 authentication with any compliant IdP (e.g. authentik, Keycloak). See the [upstream OAuth2 docs](https://librebooking.readthedocs.io/en/stable/Oauth2-Configuration.html) for the full list of settings.

**IdP setup:** create a confidential client and configure the redirect URI to:

```text
https://booking.example.com/Web/oauth2-auth.php
```

Pass settings via `librebooking_environment_variables_additional_variables`:

```yaml
librebooking_environment_variables_additional_variables: |
  LB_AUTHENTICATION_OAUTH2_LOGIN_ENABLED=true
  LB_AUTHENTICATION_OAUTH2_NAME=authentik
  LB_AUTHENTICATION_OAUTH2_URL_AUTHORIZE=https://auth.example.com/application/o/authorize/
  LB_AUTHENTICATION_OAUTH2_URL_TOKEN=https://auth.example.com/application/o/token/
  LB_AUTHENTICATION_OAUTH2_URL_USERINFO=https://auth.example.com/application/o/userinfo/
  LB_AUTHENTICATION_OAUTH2_CLIENT_ID=your-client-id
  LB_AUTHENTICATION_OAUTH2_CLIENT_SECRET=your-client-secret
  LB_AUTHENTICATION_OAUTH2_CLIENT_URI=/Web/oauth2-auth.php
```

To redirect straight to your IdP without showing the built-in login form:

```yaml
  LB_AUTHENTICATION_HIDE_LOGIN_PROMPT=true
```

Some IdPs require a trailing slash on the authorize URL — by default LibreBooking strips it. To preserve it:

```yaml
  LB_AUTHENTICATION_OAUTH2_STRIP_TRAILING_SLASH=false
```

## Maintenance

### Upgrading LibreBooking

After a major version upgrade, you may need to run database migrations. Navigate to:

```text
https://booking.example.com/Web/install/configure.php
```

If you need your database credentials, you can output its credentials by running the playbook as below:

```bash
ansible-playbook -i inventory/hosts setup.yml --tags=print-db-credentials-librebooking
```

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu librebooking` (or how you/your playbook named the service, e.g. `mash-librebooking`).
