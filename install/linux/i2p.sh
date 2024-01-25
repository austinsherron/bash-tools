#!/bin/bash

set -Eeuo pipefail

# source: https://geti2p.net/en/download/debian


# for i2p
sudo apt-add-repository ppa:i2p-maintainers/i2p
# for i2pd (i2p daemon)
sudo add-apt-repository ppa:purplei2p/i2pd
sudo apt update 
sudo apt install i2p i2pd

