#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://zoom.us/download?os=linux


PKG="zoom_amd64.deb"
VERSION="5.16.2.8828"
URL="https://zoom.us/client/${VERSION}/${PKG}"

if [[ "$(which zoom)" ]]; then
    # cleanup may still be necessary
    rm -f "${PKG}"
    echo "zoom is already installed; exiting"
    exit 0
fi

[[ -f "${PKG}" ]] && echo "${PKG} already downloaded" || wget "${URL}"
sudo apt install ./${PKG}

rm -f "${PKG}"

