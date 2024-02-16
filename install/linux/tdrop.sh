#!/usr/bin/env bash

set -Eeuo pipefail

source /etc/profile.d/shared_paths.sh


if which tdrop &> /dev/null; then
    echo "tdrop already installed; exiting"
    exit 0
fi

PKG="github.com/noctuid/tdrop"
DST="${EXTERNAL_PKGS}/tdrop"

# clone repo
[[ -d "${DST}" ]] || git clone "https://${PKG}" "${DST}"

# build + install
cd "${DST}"
sudo make install

# "clean up"
cd -

