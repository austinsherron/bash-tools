#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://www.dropbox.com/install-linux


# note: script must be run w/ `sudo`

URL="https://linux.dropbox.com/packages/dropbox.py"
OUT="${EXTERNAL_PKGS}/dropbox"
DROPBOX_PATH="${OUT}/dropbox"

if [[ ! -d "${OUT}" ]]; then
    echo "dropbox dir doesn't exist in external packages; creating"
    mkdir -p "${OUT}"
else
    echo "dropbox dir already exists in external packages"
fi

if [[ ! -f "${DROPBOX_PATH}" ]]; then
    echo "dropbox executable doesn't exist in dropbox external package dir; downloading"
    curl "${URL}" -o "${DROPBOX_PATH}"
else
    echo "dropbox executable already exists in dropbox external package dir"
fi

chmod +x "${DROPBOX_PATH}"

if [[ ! "$(which dropbox)" ]]; then
    [[ ! "$(which deploy)" ]] && echo "Error: missing 'deploy' dependency; exiting" && exit 1
    echo "deploying dropbox"
    deploy -s "${EXTERNAL_PKGS}" dropbox
else
    echo "dropbox already deployed"
fi

