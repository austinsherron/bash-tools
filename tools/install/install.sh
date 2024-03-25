#!/usr/bin/env bash

set -Eeuo pipefail


INSTALL_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 || true ; pwd -P)"
TOOLS_ROOT="$(dirname "${INSTALL_DIR}")"
BASH_TOOLS="$(dirname "$(dirname "${INSTALL_DIR}")")"
ULOG_ROOT="${TOOLS_ROOT}/log"

source "${BASH_TOOLS}/lib/utils.sh"

export INSTALL_DIR
export TOOLS_ROOT
export BASH_TOOLS
export ULOG_ROOT

function __deploy_ulogger() {
    "${ULOG_ROOT}/install.sh"
    export ULOGGER_TYPE="install"
    export ULOGGER_PREFIX="tools"
}

function __deploy_deployer() {
    "${TOOLS_ROOT}/package/deploy/deploy" --self
}

function __deploy_common() {
    deploy -p "${TOOLS_ROOT}/git"
    deploy -p "${TOOLS_ROOT}/package/manage"
    deploy -p "${TOOLS_ROOT}/system/config"
    deploy -p "${TOOLS_ROOT}/system/snapshot"
    deploy -p "${TOOLS_ROOT}/utils/data"
    deploy -p "${TOOLS_ROOT}/utils/shell"
    deploy -p "${TOOLS_ROOT}/utils/shell"
    deploy -p "${TOOLS_ROOT}/utils/web"
}

function __install_os_specific() {
    # TODO: replace w/ os-type function after bash repo consolidation
    OS_TYPE="$(os-type)"
    export OS_TYPE

    "${TOOLS_ROOT}/install/${OS_TYPE}/main.sh"
}

__deploy_ulogger
__deploy_deployer
__deploy_common
__install_os_specific

