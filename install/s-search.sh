#!/bin/bash

set -Eeo pipefail

source /etc/profile.d/shared_paths.sh

# source: https://github.com/zquestz/s#install (w/ significant modifications)


VERSION="v0.6.8"
PKG="github.com/zquestz/s"
DST="${EXTERNAL_PKGS}/s-search"
BIN="${DST}/s"

# clone repo
[[ -d "${DST}" ]] || git clone "https://${PKG}" "${DST}"

# build
cd "${DST}"
[[ -f "${BIN}" ]] || make

# install
sudo mv "${BIN}" "${SHARED_BINS}"

# "clean up"
cd -

