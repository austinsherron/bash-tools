#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://www.dropbox.com/install-linux


# note: script must be run w/ `sudo`


if which dropbox &> /dev/null; then
    echo "[INFO] dropbox is already installed; exiting"
    exit 0
fi

URL="https://linux.dropbox.com/packages/dropbox.py"
OUT="${EXTERNAL_PKGS}/dropbox"
DROPBOX_PATH="${OUT}/dropbox"

if [[ ! -d "${OUT}" ]]; then
    echo "[INFO] dropbox dir doesn't exist in external packages; creating"
    mkdir -p "${OUT}"
else
    echo "[INFO] dropbox dir already exists in external packages"
fi

if [[ ! -f "${DROPBOX_PATH}" ]]; then
    echo "[INFO] dropbox executable doesn't exist in dropbox external package dir; downloading"
    curl "${URL}" -o "${DROPBOX_PATH}"
else
    echo "[INFO] dropbox executable already exists in dropbox external package dir"
fi

chmod +x "${DROPBOX_PATH}"

echo "deploying dropbox"
deploy -s "${EXTERNAL_PKGS}" dropbox

