#!/usr/bin/env bash

set -Eeuo pipefail


if dpkg -s veracrypt &> /dev/null; then
    echo "[INFO] veracrypt is already installed; exiting"
    exit 0
fi

VERSION="1.26.7"
PKG="veracrypt-${VERSION}-Ubuntu-22.04-amd64.deb"
SIG="${PKG}.sig"
URL="https://github.com/veracrypt/VeraCrypt/releases/download/VeraCrypt_${VERSION}/${PKG}"
RC=0

# download package
[[ -f "${PKG}" ]] || wget "${URL}"

# build + install

chmod +x ${PKG}
sudo apt update -y

if ! sudo apt install -y ./${PKG}; then
    echo "[ERROR] unable to install veracrypt"
    RC=1
fi

# "clean up"

rm -rf ${PKG} ${SIG}
exit $RC

