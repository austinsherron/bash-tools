#!/usr/bin/env bash

set -Eeuo pipefail


if dpkg -s tlp &> /dev/null; then
    echo "[INFO] tlp is already installed; exiting"
    exit 0
fi

sudo apt install -y tlp
sudo systemctl enable tlp.service && sudo tlp start

