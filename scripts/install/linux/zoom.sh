#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://zoom.us/download?os=linux


if dpkg -s zoom &> /dev/null; then
    echo "[INFO] zoom is already installed; exiting"
    exit 0
fi

PKG="zoom_amd64.deb"
VERSION="5.16.2.8828"
URL="https://zoom.us/client/${VERSION}/${PKG}"

[[ -f "${PKG}" ]] && echo "[INFO] ${PKG} already downloaded" || wget "${URL}"
sudo apt install -y ./${PKG}

rm -f "${PKG}"

