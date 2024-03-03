#!/usr/bin/env bash

set -Eeuo pipefail


PKG="git-credential-manager"
VERSION="2.4.1"
OUT="gcm-linux_amd64.${VERSION}.deb"
URL="https://github.com/git-ecosystem/${PKG}/releases/download/v${VERSION}/${OUT}"
CHECKSUM="d65a166f6fc3d6638b356b84b4e1274a95352455f448b06a34926bf6568cd995"

if which ${PKG} &> /dev/null; then
    echo "${PKG} is already installed; exiting"
    exit 0
fi

# download package if it doesn't exist
[[ -f "${OUT}" ]] || wget "${URL}"
# check sha256 checksum
echo "${CHECKSUM} ${OUT}" | sha256sum --check --status
# make executable
chmod +x ${OUT}
# install
sudo apt install ./${OUT}
# clean up
rm -rf "${OUT}"

