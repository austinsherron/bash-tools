#!/usr/bin/env bash

set -Eeuo pipefail


INSTALL_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 || true ; pwd -P)"
TOOLS_ROOT="$(dirname "${INSTALL_DIR}")"
CODE_ROOT="$(dirname "$(dirname "${INSTALL_DIR}")")"
ULOG_ROOT="${TOOLS_ROOT}/log"

source "${ULOG_ROOT}/internal/log.sh"
source "${CODE_ROOT}/lib/bash/utils.sh"

OS_TYPE="$(os-type)"

export INSTALL_DIR
export TOOLS_ROOT
export CODE_ROOT
export ULOG_ROOT
export OS_TYPE

function __deploy_ulogger() {
    "${ULOG_ROOT}/install.sh"
    export ULOGGER_TYPE="install"
    export ULOGGER_PREFIX="tools"
}

function __deploy_deployer() {
    "${TOOLS_ROOT}/package/deploy/deploy" --self
}

function __deploy_common() {
    deploy -s package manage
    deploy -s system config
    deploy -s system snapshot
    deploy -s utils data
    deploy -s utils shell
    deploy -s utils secrets
    deploy -s utils shell
    deploy -s utils web
}

function __install_os_specific() {
    "${TOOLS_ROOT}/install/${OS_TYPE}/main.sh"
}

log::info "installing tools repo"

__deploy_ulogger
__deploy_deployer
__deploy_common
__install_os_specific

