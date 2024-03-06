#!/usr/bin/env bash

set -Eeuo pipefail


if dpkg -s mullvad-vpn &> /dev/null; then
    echo "[INFO] mullvad-vpn is already installed; exiting"
    exit 0
fi

VERSION="2023.4"
PKG="MullvadVPN-${VERSION}_amd64.deb"
URL="https://github.com/mullvad/mullvadvpn-app/releases/download/${VERSION}/${PKG}"

[[ -f "${PKG}" ]] || wget "${URL}"
sudo apt install -y "./${PKG}"
rm "${PKG}"

