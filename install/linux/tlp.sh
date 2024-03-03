#!/usr/bin/env bash

set -Eeuo pipefail


sudo apt install -y tlp
sudo systemctl enable tlp.service && sudo tlp start

