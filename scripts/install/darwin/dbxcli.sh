#!/usr/bin/env bash

source "${BASH_LIB}/args/check.sh"
source "${BASH_LIB}/utils/sys.sh"

set -Eeuo pipefail


# TODO: make this os agnostic so it can be used on linux in the near feature

VERSION="3.0.0"
PKG="dbxcli-$(sys::os_type)-amd64"
URL="https://github.com/dropbox/dbxcli/releases/download/v${VERSION}/${PKG}"
DST="${LOCAL_BIN:-/usr/local/bin}"

function clean() {
    if [[ -f "${PKG}" ]]; then
        ulogger info "removing ${PKG}"
        rm "${PKG}"
    fi
}

if check::installed dbxcli; then
    ulogger info "dbxcli is already installed"
    clean || exit 1
    exit 0
fi

## download

if [[ -f "${PKG}" ]]; then
    ulogger info "${PKG} already exists"
else
    ulogger info "fetching ${URL} to ${PKG}"
    wget "${URL}" || exit 1
fi

## install

chmod +x "${PKG}"
install install -s "${PKG}" -d "${DST}" -n dbxcli || exit 1

## clean up

clean

