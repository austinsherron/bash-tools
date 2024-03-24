#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://itsfoss.com/install-chrome-ubuntu/


if which google-chrome &> /dev/null; then
    echo "[INFO] google-chrome is already installed; exiting"
    exit 0
fi

PKG="google-chrome-stable_current_amd64.deb"

# download
wget "https://dl.google.com/linux/direct/${PKG}"
# install
sudo dpkg -i "${PKG}"
# clean up
rm "${PKG}"

