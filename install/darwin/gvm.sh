#!/usr/bin/env bash

set -Eeuo pipefail


function install-gvm() {
    if which gvm &> /dev/null; then
        echo "[INFO] gvm is already installed"
        return 0
    fi

    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
}

function is-go-version-installed() {
    gvm list | tail --lines=+4 | sed 's/[[:space:]]*//' | sed 's/=> //' | grep -q "${1}"
}

function install-go-version() {
    if is-go-version-installed "${1}"; then
        echo "[INFO] ${1} is already installed"
        return 0
    fi

    gvm install "${1}"
}

if ! install-gvm; then
    echo "[ERROR] unable to install gvm"
    exit 1
fi

for GO_VERSION in "${@:1}"; do
    if ! install-go-version "${GO_VERSION}"; then
        echo "[ERROR] unable to install ${GO_VERSION}"
        exti 1
    fi
done

