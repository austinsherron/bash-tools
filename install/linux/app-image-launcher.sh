#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://github.com/TheAssassin/AppImageLauncher/wiki/Install-on-Ubuntu-or-Debian


if dpkg -s appimagelauncher &> /dev/null; then
    echo "[INFO] appimagelauncher is already installed; exiting"
    exit 0
fi

sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:appimagelauncher-team/stable
sudo apt update -y
sudo apt install -y appimagelauncher

