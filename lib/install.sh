#!/usr/bin/env bash

set -Eeuo pipefail


if [[ -z "${LOCAL_LIB+x}" ]]; then
    echo "[ERROR] LOCAL_LIB is not set"
    exit 1
fi

LIB_SRC="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 || true ; pwd -P)/src"
LIB_DST="${LOCAL_LIB}/bash"

if [[ ! -d "${LIB_DST}" ]]; then
    echo "[INFO] installing bash lib at ${LIB_SRC} to ${LIB_DST}"
    sudo ln -s "${LIB_SRC}" "${LIB_DST}" || exit 1
else
    echo "[INFO] bash lib already exists at ${LIB_DST}"
fi

