#!/usr/bin/env bash

set -Eeuo pipefail


# note: must be run in root user login shell (i.e.: sudo -i)

# make systemd dir, if necessary
mkdir -p /usr/local/systemd/
# install runnable
cp "${TOOLS_ROOT}"/system/systemd/units/mv-stg-backups/mv-stg-backups /usr/local/systemd/
# install systemd user units
install-units -d "${TOOLS_ROOT}"/system/systemd/units/mv-stg-backups -o user -t path

systemctl --user enable mv-stg-backups.service
systemctl --user start mv-stg-backups.service

