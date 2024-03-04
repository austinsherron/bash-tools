#!/usr/bin/env bash

set -Eeuo pipefail


function installed-version() {
    lua -v | awk '{print $2}'
}

VERSION="5.3.6"
DIR="lua-${VERSION}"
PKG="${DIR}.tar.gz"

if which lua &> /dev/null && [[ "$(installed-version)" == "${VERSION}" ]]; then
    echo "lua already installed at version ${VERSION}; exiting"
    exit 0
fi

curl -R -O http://www.lua.org/ftp/${PKG}
tar -zxf ${PKG}

cd ${DIR}

make linux test
sudo make install 

cd .. && rm -rf ${DIR} ${PKG}

