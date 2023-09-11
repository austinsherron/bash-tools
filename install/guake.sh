#!/bin/bash

set -Eeo pipefail

# source: https://guake.readthedocs.io/en/latest/user/installing.html#system-wide-installation


sudo add-apt-repository ppa:linuxuprising/guake
sudo apt-get update 
sudo apt install guake

