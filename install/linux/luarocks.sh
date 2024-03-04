#!/usr/bin/env bash

set -Eeuo pipefail


function installed-version() {
    luarocks --version | head -1 | awk '{print $2}'
}

VERSION="3.9.2"
DIR="luarocks-${VERSION}"
PKG="${DIR}.tar.gz"

if which luarocks &> /dev/null && [[ "$(installed-version)" == "${VERSION}" ]]; then
    echo "luarocks already installed at version ${VERSION}; exiting"
    exit 0
fi

wget https://luarocks.org/releases/${PKG}
tar zxpf ${PKG}

cd ${DIR}

./configure && make && sudo make install
sudo luarocks install luasocket
lua

cd .. && rm -rf ${DIR} ${PKG}

