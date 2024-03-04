#!/usr/bin/env bash

set -Eeuo pipefail

source /etc/profile.d/shared_paths.sh

# source: https://github.com/zquestz/s#install (w/ significant modifications)


if which s &> /dev/null; then
    echo "s is already installed"
    exit 0
fi

PKG="github.com/zquestz/s"
DST="${EXTERNAL_PKGS}/s-search"
SBIN="${DST}/s"

# clone repo
[[ -d "${DST}" ]] || git clone "https://${PKG}" "${DST}"

# build
cd "${DST}"
[[ -f "${SBIN}" ]] || go build # NOTE: `make` isn't working...

# install
sudo mv "${SBIN}" "${SYS_BIN}"

# "clean up"
cd -

