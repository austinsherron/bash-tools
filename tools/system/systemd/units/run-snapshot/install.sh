#!/usr/bin/env bash

set -Eeuo pipefail


# note: must be run in root user login shell (i.e.: sudo -i)

if ! which deploy; then
    echo "[ERROR] install: deploy not installed"
    exit 1
fi

if ! which snapshot; then
    deploy snapshot -s "${TOOLS_ROOT}/system"
fi

# install config
mkdir -p "${SYS_CONFIG}/snapshot"
cp -r "${CONFIG_ROOT_PUB}/snapshot/" "${SYS_CONFIG}/"

# install systemd system units
install-units -d "${TOOLS_ROOT}/system/systemd/units/run-snapshot" -o system -t timer

systemctl enable run-snapshot.service
systemctl start run-snapshot.service

