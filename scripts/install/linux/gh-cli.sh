#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://github.com/cli/cli/blob/trunk/docs/install_linux.md


if which gh &> /dev/null; then
    echo "[INFO] gh is already installed; exiting"
    exit 0
fi

curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
 |  sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
 && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
 |  sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
 && sudo apt update -y \
 && sudo apt install gh -y

