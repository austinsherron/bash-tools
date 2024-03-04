#!/usr/bin/env bash

set -Eeuo pipefail


## source: https://software.opensuse.org//download.html?project=home%3Aungoogled_chromium&package=ungoogled-chromium


if dpkg -s ungoogled-chromium &> /dev/null; then
    echo "ungoogled-chromium is already installed; exiting"
    exit 0
fi

## install ungoogled-chromium from "jammy jellyfish" (22.04) type ubuntu systems
echo 'deb http://download.opensuse.org/repositories/home:/ungoogled_chromium/Ubuntu_Jammy/ /' \
    | sudo tee /etc/apt/sources.list.d/home:ungoogled_chromium.list

curl -fsSL https://download.opensuse.org/repositories/home:ungoogled_chromium/Ubuntu_Jammy/Release.key \
    | gpg --dearmor \
    | sudo tee /etc/apt/trusted.gpg.d/home_ungoogled_chromium.gpg > /dev/null

sudo apt update -y
sudo apt install -y ungoogled-chromium
