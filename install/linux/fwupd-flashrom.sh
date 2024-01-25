#!/usr/bin/env bash

set -Eeuo pipefail


# as presented in the standard documentation
sudo add-apt-repository ppa:starlabs/main
sudo add-apt-repository universe
sudo apt update
sudo apt install fwupd libflashrom1

# from 
# sudo add-apt-repository ppa:starlabs/main
# # not in source
# # sudo add-apt-repository ppa:starlabs/coreboot
# sudo add-apt-repository universe
# sudo apt update
# sudo apt full-upgrade -y
# sudo apt install fwupd
# sudo apt -f install
# # in source
# # fwupdmgr refresh --force
# # fwupdmgr switch-branch

