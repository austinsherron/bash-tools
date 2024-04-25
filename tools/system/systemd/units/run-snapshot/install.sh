#!/usr/bin/env bash

set -Eeuo pipefail


# note: must be run in root user login shell (i.e.: sudo -i)

# install executables
deploy link -s "${TOOLS_ROOT}/system/snapshot" -n snapshot --strict info

# install config
mkdir -p "${SYS_CONFIG}/snapshot"
cp -r "${CONFIG_ROOT_PUB}/snapshot/" "${SYS_CONFIG}/"

# install systemd system units
install-units -d "${TOOLS_ROOT}/system/systemd/units/run-snapshot" -o system -t timer

systemctl enable run-snapshot.service
systemctl start run-snapshot.service

