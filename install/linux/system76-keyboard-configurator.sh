#!/usr/bin/env bash

set -Eeuo pipefail


VERSION="1.3.9"
PKG="keyboard-configurator-${VERSION}-x86_64.AppImage"
URL="https://github.com/pop-os/keyboard-configurator/releases/download/v${VERSION}/${PKG}"

[[ -f "${PKG}" ]] || wget "${URL}"
ail-cli integrate "${PKG}"

