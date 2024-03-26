#!/usr/bin/env bash

set -Eeuo pipefail


# TODO: test

if dpkg -s delta &> /dev/null; then
    ulogger info "delta is already installed; exiting" -t install -t script
    exit 0
fi

VERSION="0.17.0"
PKG="git-delta_${VERSION}_amd64.deb"
SIG="${PKG}.sig"
URL="https://github.com/dandavison/delta/releases/download/${VERSION}/${PKG}"
RC=0

# download package
[[ -f "${PKG}" ]] || wget "${URL}"

# install
chmod +x ${PKG}
sudo apt update -y

if ! sudo apt install -y ./${PKG}; then
    echo "[ERROR] unable to install veracrypt"
    RC=1
fi

# "clean up"
rm -rf ${PKG} ${SIG}
exit $RC

