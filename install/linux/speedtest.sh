#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://www.speedtest.net/apps/cli


if which speedtest > /dev/null; then
    echo "speedtest is already installed; exiting"
    exit 0
fi

sudo apt-get install curl
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
sudo apt-get install speedtest

