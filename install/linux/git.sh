#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://git-scm.com/download/linux


# NOTE: this is duplicated in the dotfiles repo: we need to install up-to-date git to
# clone this repo

VERSION="2.43.0"

if which git &> /dev/null && [[ "$(git --version | awk '{print $3}')" == "${VERSION}" ]]; then
    echo "git already installed at version ${VERSION}; exiting"
    exit 0
fi

echo  "[INFO] adding git-core apt repo"
sudo add-apt-repository -y ppa:git-core/ppa

echo  "[INFO] installing git"
sudo apt update -y && sudo apt install -y git

