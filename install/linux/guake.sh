#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://guake.readthedocs.io/en/latest/user/installing.html#system-wide-installation


if dpkg -s guake &> /dev/null; then
    echo "guake is already installed; exiting"
    exit 0
fi

sudo add-apt-repository -y ppa:linuxuprising/guake
sudo apt-get update -y
sudo apt install -y guake

