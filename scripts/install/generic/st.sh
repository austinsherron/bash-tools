#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://github.com/nferraz/st


VERSION="1.1.4"
PKG="v${VERSION}.tar.gz"
URL="https://github.com/nferraz/st/archive/refs/tags/${PKG}"

DST="${EXTERNAL_PKGS}"
TGT="${DST}/${PKG}"
OUT="${DST}/st-${VERSION}"

function __clean() {
    sudo rm -rf "${TGT}" "${OUT}"
}

if which st &> /dev/null; then
    echo "[INFO] st is already installed"
    __clean || exit 1
    exit 0
fi

cd "${EXTERNAL_PKGS}" || exit 1

## download

if [[ -f "${TGT}" ]]; then
    echo "[INFO] ${TGT} already exists"
else
    echo "[INFO] fetching ${URL} to ${TGT}"
    wget "${URL}"
fi

if [[ -d "${OUT}" ]]; then
    echo "[INFO] ${OUT} already exists"
else
    echo "[INFO] untarring ${TGT}"
    tar -xvf "${TGT}"
fi

## build

cd "${OUT}"

perl Makefile.PL
sudo make install

## clean

__clean

