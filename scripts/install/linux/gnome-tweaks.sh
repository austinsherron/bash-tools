#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://www.geeksforgeeks.org/how-to-install-and-use-gnome-tweak-tool-on-ubuntu/


if dpkg -s gnome-tweaks &> /dev/null; then
    echo "[INFO] gnome-tweaks is already installed; exiting"
    exit 0
fi

sudo add-apt-repository -y universe
sudo apt install -y gnome-tweaks

