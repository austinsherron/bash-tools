#!/bin/bash

set -Eeo pipefail


sudo add-apt-repository ppa:starlabs/main
sudo add-apt-repository ppa:starlabs/coreboot
sudo add-apt-repository universe
sudo apt update
sudo apt full-upgrade -y
sudo apt install fwupd
sudo apt -f install
# fwupdmgr refresh --force
# fwupdmgr switch-branch
