#!/bin/bash

set -Eeo pipefail


# source: https://git-scm.com/download/linux

sudo add-apt-repository ppa:git-core/ppa
sudo apt update
sudo apt install git

