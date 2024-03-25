#!/usr/bin/env bash

set -Eeuo pipefail

source /etc/profile.d/shared_paths.sh


# note: make sure to permanently add the nvim install's bin, i.e.: /usr/local/nvim/bin, to PATH

# FIXME: if this script is used to upgrade nvim, there's an issue w/ builtin treesitter
#        parsers + queries that can cause them to take precedence over those that come w/
#        treesitter; if this happens, follow the instructions here,
#        https://github.com/nvim-treesitter/nvim-treesitter/issues/3092, and remove/rename
#        the relevant builtin treesitter dirs

VERSION="v0.9.2"
PKG="nvim-linux64.tar.gz"
URL="https://github.com/neovim/neovim/releases/download/${VERSION}/${PKG}"

OUT="${PKG%.tar.gz}"
DST="${SYS_ROOT}/nvim"


# TODO: add ability to change VERSION and automatically update w/o manually removing the
#       current install
nvim_version() {
    nvim -v | head -1 | cut -d ' ' -f2
}

if [[ -f "${DST}/bin/nvim" ]]; then # && [[ "$(which nvim)" ]] && [[ "$(nvim_version)" == "${VERSION}" ]]; then
    echo "[INFO] nvim binary exists in ${DST}; exiting"

    # clean up, if necessary
    echo "[INFO] cleaning up, if necessary"
    rm -rf "${PKG}" "${OUT}"

    exit 0
fi

# if for some reason the nvim install dir exists but the binary doesn't, remove
# everything so we can reinstall
if [[ -d "${DST}" ]]; then
    echo "[INFO] found ${DST} w/out corresponding binary; removing it"
    sudo rm -rf "${DST}"
fi

# download tarball if it doesn't already exist in the cwd
if [[ ! -f "${PKG}" ]]; then
    echo "[INFO] downloading ${PKG}"
    wget "${URL}"
else
    echo "[INFO] ${PKG} already exists"
fi

# remove contents of output dir, if they exist
if [[ -d "${OUT}" ]]; then
    echo "[INFO] ${OUT} already exists; removing before extracting tar"
    rm -rf "${OUT}"
fi

# extract
echo "[INFO] extracting tarball contents to ${OUT}"
tar -xzf "${PKG}"

# install
if [[ ! -d "${DST}" ]]; then
    echo "[INFO] installing nvim to ${DST}"
    sudo cp -r "${OUT}" "${DST}"
else
    echo "[INFO] ${DST} already exists"
fi

# clean up
echo "[INFO] cleaning up"
rm -rf "${PKG}" "${OUT}"

