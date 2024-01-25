#!/usr/bin/env bash

set -Eeuo pipefail


VERSION="1.6.4"
PKG="whatsapp-for-linux-${VERSION}-x86_64.AppImage"
URL="https://github.com/eneshecan/whatsapp-for-linux/releases/download/v${VERSION}/${PKG}"

[[ -f "${PKG}" ]] || wget "${URL}"
ail-cli integrate "${PKG}"

