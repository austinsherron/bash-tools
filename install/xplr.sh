#!/bin/bash

set -Eeuo pipefail

source /etc/profile.d/shared_paths.sh


PLATFORM="linux"  # one of ["linux"|"linux-musl"|"macos"]
PKG="xplr-${PLATFORM}.tar.gz"
OUT="xplr-${PLATFORM}"

# download package if it doesn't already exist
[[ -f "${PKG}" ]] || wget "https://github.com/sayanarijit/xplr/releases/latest/download/${PKG}"
# create output dir if it doesn't already exist
[[ -d "${OUT}" ]] || mkdir "${OUT}"
# extract
[[ -f "${OUT}/xplr" ]] || tar -xzvf "${PKG}" -C "${OUT}"

# validate extracts
if [[ ! -f "${OUT}/xplr" ]]; then
    echo "No 'xplr' binary found in pkg extracts; unrecoverable error"
    exit 1
fi

# install (i.e.: mv to path dir)
sudo mv "${OUT}/xplr" "${SHARED_BINS}"
# clean up
rm -rf "${OUT}" "${PKG}"

