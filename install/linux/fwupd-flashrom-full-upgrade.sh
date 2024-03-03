#!/usr/bin/env bash

set -Eeuo pipefail


sudo add-apt-repository -y ppa:starlabs/main
sudo add-apt-repository -y ppa:starlabs/coreboot
sudo add-apt-repository -y universe
sudo apt update -y
sudo apt full-upgrade -y
sudo apt install -y fwupd
sudo apt -f -y install
# fwupdmgr refresh --force
# fwupdmgr switch-branch
