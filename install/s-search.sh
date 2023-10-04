#!/bin/bash

set -Eeuo pipefail

source /etc/profile.d/shared_paths.sh

# source: https://github.com/zquestz/s#install (w/ significant modifications)


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

