#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://bisq.network/getting-started/


VERSION="1.9.14"
BASE_URL="https://bisq.network/downloads/v${VERSION}"
APP="bisq"
OUT="${HOME}/Downloads/${APP}"

PKG="Bisq-64bit-${VERSION}.deb"
PKG_URL="${BASE_URL}/${PKG}"
PKG_OUT="${OUT}/${PKG}"

SIG="${PKG}.asc"
SIG_URL="${BASE_URL}/${SIG}"
SIG_OUT="${OUT}/${SIG}"

PUB_KEY_ID="E222AA02"
PUB_KEY="${PUB_KEY_ID}.asc"
PUB_KEY_URL=${BASE_URL}/${PUB_KEY}

if dpkg -s "${APP}" &> /dev/null; then
    echo "[INFO] ${APP} is already installed; exiting"
    exit 0
fi

# exit early if the application is already installed
[[ "$(dpkg -S "${APP}" 2>/dev/null)" ]] && echo "[INFO] ${APP} already installed; exiting" && exit 0
# create output dir, if necessary
[[ -d "${OUT}" ]] || mkdir -p "${OUT}"
# download package, if necessary
[[ -f "${PKG_OUT}" ]] || wget "${PKG_URL}" -P "${OUT}"
# download pgp signature, if necessary
[[ -f "${SIG_OUT}" ]] || wget "${SIG_URL}" -P "${OUT}"
# download and import public key, if necessary
# TODO: while this imports the key, it doesn't trust or sign it; think (carefully!) about
# automating that process
[[ "$(gpg --list-public-keys "${PUB_KEY_ID}")" ]] || wget "${PUB_KEY_URL}" | gpg --import

# make executable
sudo chmod +x "${PKG_OUT}"
# install, if necessary
sudo apt install -y "${PKG_OUT}"
# clean up
rm -rf "${OUT}"

