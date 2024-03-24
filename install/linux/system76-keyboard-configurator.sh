#!/usr/bin/env bash

set -Eeuo pipefail

source /etc/profile.d/shared_paths.sh


VERSION="1.3.9"
PKG="keyboard-configurator-${VERSION}-x86_64"
APP_IMAGE="${PKG}.AppImage"
URL="https://github.com/pop-os/keyboard-configurator/releases/download/v${VERSION}/${APP_IMAGE}"

if ls ${ADMIN_HOME}/Applications/${PKG}*.AppImage &> /dev/null; then
    echo "[INFO] ${APP_IMAGE} exists and appears to be integrated; exiting"
    exit 0
fi

[[ -f "${APP_IMAGE}" ]] || wget "${URL}"
ail-cli integrate "${APP_IMAGE}"

