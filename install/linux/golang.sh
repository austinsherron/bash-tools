#!/usr/bin/env bash

set -Eeuo pipefail

source /etc/profile.d/shared_paths.sh


function installed-version()  {
    go version | awk '{print $3}' | sed 's/go//'
}

CHECKSUM="f0a87f1bcae91c4b69f8dc2bc6d7e6bfcd7524fceec130af525058c0c17b1b44"
VERSION="1.20.7"
PKG="go${VERSION}.linux-amd64.tar.gz"
OUT="golang-${VERSION}"

if which go &> /dev/null && [[ "$(installed-version)" == "${VERSION}" ]]; then
    echo "go already installed at version ${VERSION}; exiting"
    exit 0
fi

# download package if it doesn't exist
[[ -f "${PKG}" ]] || wget "https://go.dev/dl/${PKG}"
# check sha256 checksum
echo "${CHECKSUM} ${PKG}" | sha256sum --check --status
# create output dir
[[ -d "${OUT}" ]] || mkdir "${OUT}"
# untar
[[ -d "${OUT}/go" ]] || tar -xvf "${PKG}" -C "${OUT}"

# validate extracts
if [[ ! -d "${OUT}/go" ]]; then
    echo "No 'go' dir found in pkg extracts; unrecoverable error"
    exit 1
fi

# install
mv "${OUT}/go" "${GO_ROOT}"
# clean up
rm -rf "${OUT}" "${PKG}"

