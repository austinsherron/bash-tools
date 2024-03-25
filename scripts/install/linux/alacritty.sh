#!/usr/bin/env bash

set -Eeuo pipefail


if which alacritty &> /dev/null; then
    echo "[INFO] alacritty is already installed; exiting"
    exit 0
fi

# validate dependencies

if ! which rustup &> /dev/null; then
    echo "[ERROR] rustup is required to build alacritty"
    exit 0
fi

if ! which cargo &> /dev/null; then
    echo "[ERROR] cargo is required to build alacritty"
    exit 0
fi

URL="https://github.com/alacritty/alacritty"
DST="${EXTERNAL_PKGS}/alacritty"
BIN="${DST}/target/release/alacritty"

# clone repo
[[ -d "${DST}" ]] || git clone "${URL}" "${DST}"
cd "${DST}"

# build
if [[ ! -f "${BIN}" ]]; then
    rustup override set stable
    rustup update stable
    cargo build --release
fi

# install
sudo mv "${BIN}" "${SYS_BIN}"

# "clean up"
cd -

