#!/usr/bin/env bash

set -Eeuo pipefail

source /etc/profile.d/shared_paths.sh


VERSION="1.6.4"
PKG="whatsapp-for-linux-${VERSION}-x86_64"
APP_IMAGE="${PKG}.AppImage"
URL="https://github.com/eneshecan/whatsapp-for-linux/releases/download/v${VERSION}/${APP_IMAGE}"

if ls ${ADMIN_HOME}/Applications/${PKG}*.AppImage &> /dev/null; then
    echo "[INFO] ${APP_IMAGE} exists and appears to be integrated; exiting"
    exit 0
fi

[[ -f "${APP_IMAGE}" ]] || wget "${URL}"
ail-cli integrate "${APP_IMAGE}"

