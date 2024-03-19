#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://github.com/akinomyoga/ble.sh


BLESH="${XDG_DATA_HOME}/blesh/ble.sh"

if [[ -s "${BLESH}" ]]; then
    echo "[INFO] ble.sh is already installed"
    exit 0
fi

echo "[INFO] installing ble.sh"

wget -O - https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz | tar xJf -
bash ble-nightly/ble.sh --install "${XDG_DATA_HOME}"

