#!/bin/bash

set -Eeo pipefail


VERSION="2023.4"
PKG="MullvadVPN-${VERSION}_amd64.deb"
URL="https://github.com/mullvad/mullvadvpn-app/releases/download/${VERSION}/${PKG}"

[[ -f "${PKG}" ]] || wget "${URL}"
sudo apt install "./${PKG}"
rm "${PKG}"

