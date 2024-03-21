#!/usr/bin/env bash

set -Eeuo pipefail


# note: must be run in root user login shell (i.e.: sudo -i)

if ! which syngestures &> /dev/null; then
    echo "[ERROR] install: syngestures not installed"
    exit 1
fi

# note: must be run in root user login shell (i.e.: sudo -i)

# make systemd dir, if necessary
sudo mkdir -p /usr/local/systemd/
# install runnable
sudo cp "${TOOLS_ROOT}"/system/systemd/units/run-syngestures/run-syngestures /usr/local/systemd/
# install systemd user units
install-units -d "${TOOLS_ROOT}"/system/systemd/units/run-syngestures -o user

systemctl --user enable run-syngestures.service
systemctl --user start run-syngestures.service

