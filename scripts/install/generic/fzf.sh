#!/usr/bin/env bash

source "${BASH_LIB}/args/check.sh"

set -Eeuo pipefail


URL="https://github.com/junegunn/fzf"
DEST="${EXTERNAL_PKGS}/fzf"
TGT="${XDG_CONFIG_HOME}/fzf"

## download

if [[ -d "${DEST}" ]]; then
    ulogger info "${DEST} already exists"
else
    ulogger info "cloning ${URL} to ${DEST}"
    git clone --depth 1 "${URL}" "${DEST}" || exit 1
fi

## install

deploy install -s "${DEST}" -d "${ADMIN_HOME}" -n fzf-root -t lib --target .fzf --strict info
deploy install -s "${DEST}/bin/fzf" -n fzf --strict info

if [[ -f "${TGT}/fzf.bash" ]]; then
    ulogger info "fzf is already installed"
else
    ulogger info "running ${DEST}/install"
    "${DEST}/install" --xdg --key-bindings --completion --update-rc --no-zsh --no-fish
fi

