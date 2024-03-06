#!/usr/bin/env bash

set -Eeuo pipefail


function is-plugin-installed() {
    helm plugin list | tail --lines=+2 | awk '{print $1}' | grep "${1}" -q
}

if ! which helm &> /dev/null; then
    echo "[ERROR] helm must be installed to install helm plugins"
    exit 1
fi

if [[ $# -ne 2 ]]; then
    echo "[ERROR] helm-plugins.sh requires two positional arguments (plugin-name, plugin-url)"
    exit 1
fi

if is-plugin-installed "${1}"; then
    echo "[INFO] '${1}' helm plugin is already installed"
else
    echo "[INFO] installing '${1}' helm plugin"
    helm plugin install "${2}"
fi

