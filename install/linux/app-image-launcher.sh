#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://github.com/TheAssassin/AppImageLauncher/wiki/Install-on-Ubuntu-or-Debian


sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:appimagelauncher-team/stable
sudo apt update -y
sudo apt install -y appimagelauncher

