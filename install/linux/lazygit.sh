#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://github.com/jesseduffield/lazygit#installation


VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
PKG="lazygit_${VERSION}_Linux_x86_64.tar.gz"
URL="https://github.com/jesseduffield/lazygit/releases/latest/download/${PKG}"
OUT="lazygit-${VERSION}"

# download
[[ -f "${PKG}" ]] || curl -Lo lazygit.tar.gz "${URL}"
# extract
[[ -d "${OUT}" ]] || mkdir "${OUT}"
[[ -f "${OUT}/lazygit" ]] || tar -xvf lazygit.tar.gz lazygit -C "${OUT}"
# install
sudo mv lazygit "${SHARED_BINS}"
# clean up
rm -rf "${OUT}" lazygit*.tar.gz

