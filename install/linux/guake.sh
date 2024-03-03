#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://guake.readthedocs.io/en/latest/user/installing.html#system-wide-installation


sudo add-apt-repository -y ppa:linuxuprising/guake
sudo apt-get update -y
sudo apt install -y guake

