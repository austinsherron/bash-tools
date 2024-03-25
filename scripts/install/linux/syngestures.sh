#!/usr/bin/env bash

set -Eeuo pipefail


if which syngestures &> /dev/null; then
    echo "[INFO] syngestures already installed; exiting"
    exit 0
fi

if ! which cargo &> /dev/null; then
    echo "[ERROR] cargo must be installed to continue"
    exit 1
fi

echo "[INFO] installing syngestures"
cargo install syngestures
echo "[INFO] adding user=${USER} to input group"
sudo usermod -a -G input "${USER}"

