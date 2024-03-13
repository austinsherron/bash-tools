#!/usr/bin/env bash

set -Eeuo pipefail


USAGE="usage: gvm.sh {version} [-u version]"

usage() {
    echo "${USAGE}"
}

help() {
cat <<help
DESCRIPTION

    Install gvm, and optionally, multiple go versions. Also optionally sets the go version.

USAGE

    ${USAGE}

POSITIONAL

    VERSION         optional, multi-valued; go versions to install; should be of the format "go{major}.{minor}", i.e.: "go1.22".

OPTIONS

    -u, --use       optional; a go version to use; should be installed and in the same format as provided versions
    -h, --help      display this message

help
}


VERSIONS=()
USE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -u|--use)
      USE="${2}"
      shift
      shift
      ;;
    -h|--help)
      help
      exit 0
      ;;
    *)
      VERSIONS+=("${1}")
      shift
      ;;
  esac
done


function __install_gvm() {
    if which gvm &> /dev/null; then
        echo "[INFO] gvm is already installed"
        return 0
    fi

    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
    source ~/.gvm/scripts/gvm
}

function __is_go_version_installed() {
    gvm list | tail --lines=+4 | sed 's/[[:space:]]*//' | sed 's/=> //' | grep -q "${1}" && return 0 || return 1
}

function __install_go_version() {
    echo "[INFO] installing ${1}"
    gvm install "${1}"
}

if ! __install_gvm; then
    echo "[ERROR] unable to install gvm"
    exit 1
fi

for VERSION in ${VERSIONS[@]}; do
    if __is_go_version_installed "${VERSION}"; then
        echo "[INFO] go version=${VERSION} is already installed"
    else
        __install_go_version "${VERSION}"
    fi

done

# FIXME: this is currently broken: https://github.com/moovweb/gvm/issues/188
# [[ -n "${USE}" ]] && gvm use "${USE}"

