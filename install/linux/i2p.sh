#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://geti2p.net/en/download/debian


# for i2p
sudo apt-add-repository -y ppa:i2p-maintainers/i2p
# for i2pd (i2p daemon)
sudo add-apt-repository -y ppa:purplei2p/i2pd
sudo apt update -y 
sudo apt install -y i2p i2pd

