#!/usr/bin/env bash

set -Eeuo pipefail


VERSION="4.2.5"
PKG="Homebrew-${VERSION}.pkg"
URL="https://github.com/Homebrew/brew/releases/download/${VERSION}/${PKG}"
DST="${HOME}/Downloads"

if which brew &> /dev/null; then
    echo "[INFO] Homebrew is already installed"
    exit 0
fi

if [[ -f "${DST}/${PKG}" ]]; then
    echo "[INFO] ${DST}/${PKG} already exists"
    exit 0
fi

cd "${DST}" && curl -fLO "${URL}"

