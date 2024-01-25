#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://github.com/TheAssassin/AppImageLauncher/wiki/Install-on-Ubuntu-or-Debian


sudo apt install software-properties-common
sudo add-apt-repository ppa:appimagelauncher-team/stable
sudo apt update
sudo apt install appimagelauncher

