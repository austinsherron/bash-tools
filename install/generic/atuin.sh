#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://github.com/atuinsh/atuin

if which atuin &> /dev/null; then
    echo "[INFO] atuin is already installed"
    exit 0
fi

echo "[INFO] installing atuin"
bash <(curl https://raw.githubusercontent.com/atuinsh/atuin/main/install.sh)
atuin import auto

