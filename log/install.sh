#!/usr/bin/env bash

set -Eeuo pipefail


function usage() {
    echo "install.sh [-c|-r|-p]"
}

SRC="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 || true ; pwd -P )/core"
DST="/usr/local/ulogger/bin"

TOOLS="$(dirname "$(dirname "${SRC}")")"
DEPLOY="${TOOLS}/package/deploy/deploy"
TQ="${TOOLS}/utils/data"

CLEAN=""
REMOVE=""
PATH_ONLY=""

function __update_path_if_necessary() {
    [[ -z "${PATH_ONLY}" ]] && return 0

    [[ ! -d "${DST}" ]] && echo "[WARN] adding non-existing dir ${DST} to PATH"
    echo "[INFO] adding ${DST} to PATH"
    PATH="${PATH}:${DST}"
    export PATH
    exit 0
}

function __remove_dst_if_necessary() {
    [[ ! -d "${DST}" ]] || [[ -z "${CLEAN}" && -z "${REMOVE}" ]] && return 0

    [[ -n "${REMOVE}" ]] && echo "[INFO] -r detected, removing ${DST}"
    [[ -n "${CLEAN}" && -z "${REMOVE}" ]] && "[INFO] -r detected, removing ${DST}"

    sudo rm -rf "${DST}"/* || exit 1
    [[ -n "${REMOVE}" ]] && exit 0
}

function __deploy_log_file_if_necessary() {
    local file="${1}"
    local -r target="${DST}/$(basename "${file}")"

    [[ -s "${target}" ]] && echo "[INFO] ${target} already exists" && return 0

    echo "[INFO] linking $(basename "${file}") to ${DST}"
    sudo ln -s "${file}" "${DST}" || exit 1
}

function __deploy_log_files_if_necessary() {
    local dir="${1}"

    for file in "${dir}"/*; do
        if [[ -d "${file}" ]]; then
            __deploy_log_files_if_necessary "${file}" || return 1
        else
            __deploy_log_file_if_necessary "${file}" || return 1
        fi
    done
}

function __install_ulogger_if_necessary() {
    if [[ ! -d "${DST}" ]]; then
        echo "[INFO] creating ${DST}"
        sudo mkdir -p "${DST}"
    fi

    __deploy_log_files_if_necessary "${SRC}"
    __update_path_if_necessary
}

function __install_dependencies_if_necessary() {
    if ! which rq &> /dev/null; then
        echo "[INFO] installing rq"
        brew install rq || exit 1
    else
        echo "[INFO] rq already installed"
    fi

    if ! which tq &> /dev/null; then
        echo "[INFO] installing tq"
        "${DEPLOY}" -p "${TQ}" || exit 1
    else
        echo "[INFO] tq already installed"
    fi
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -c) CLEAN="true"; shift; ;;
    -r) REMOVE="true"; shift ;;
    -p) PATH_ONLY="true"; shift; ;;
    *) usage && exit 1
        ;;
  esac
done


__update_path_if_necessary || exit 1
__remove_dst_if_necessary || exit 1
__install_dependencies_if_necessary || exit 1
__install_ulogger_if_necessary || exit 1

