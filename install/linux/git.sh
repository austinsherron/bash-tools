#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://git-scm.com/download/linux


# NOTE: this is duplicated in the dotfiles repo: we need to install up-to-date git to
# clone this repo

echo  "[INFO] adding git-core apt repo"
sudo add-apt-repository -y ppa:git-core/ppa

echo  "[INFO] installing git"
sudo apt update -y && sudo apt install -y git

