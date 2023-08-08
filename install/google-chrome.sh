#!/bin/bash

set -Eeo pipefail

# source: https://itsfoss.com/install-chrome-ubuntu/


PKG="google-chrome-stable_current_amd64.deb"

# download
wget "https://dl.google.com/linux/direct/${PKG}"
# install
sudo dpkg -i "${PKG}"
# clean up
rm "${PKG}"

