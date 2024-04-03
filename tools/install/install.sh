#!/usr/bin/env bash

set -Eeuo pipefail


# NOTE: these are defined in /etc/profile.d/shared_paths.sh, but depending on when this is
# called, that script may not exists yet
[[ -z "${LOCAL_BIN+x}" ]] && export LOCAL_BIN="/usr/local/bin"
[[ -z "${LOCAL_LIB+x}" ]] && export LOCAL_LIB="/usr/local/lib"

INSTALL_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 || true ; pwd -P)"
TOOLS_ROOT="$(dirname "${INSTALL_DIR}")"
BASH_TOOLS="$(dirname "$(dirname "${INSTALL_DIR}")")"
ULOG_ROOT="${TOOLS_ROOT}/log"

source "${BASH_TOOLS}/lib/src/utils.sh"

export INSTALL_DIR
export TOOLS_ROOT
export BASH_TOOLS
export ULOG_ROOT

function __deploy_ulogger() {
    "${ULOG_ROOT}/install.sh"
    export ULOGGER_TYPE="install"
    export ULOGGER_PREFIX="tools"
}

function __install_bash_lib() {
    "${BASH_TOOLS}/lib/install.sh"
}

function __deploy_deployer() {
    "${TOOLS_ROOT}/package/deploy/deploy" --self
}

function __deploy_common() {
    deploy -p "${TOOLS_ROOT}/git"
    deploy -p "${TOOLS_ROOT}/package/manage"
    deploy -p "${TOOLS_ROOT}/system/config"
    deploy -p "${TOOLS_ROOT}/system/snapshot"
    deploy -p "${TOOLS_ROOT}/tmux"
    deploy -p "${TOOLS_ROOT}/utils/data"
    deploy -p "${TOOLS_ROOT}/utils/shell"
    deploy -p "${TOOLS_ROOT}/utils/shell"
    deploy -p "${TOOLS_ROOT}/utils/web"
}

function __install_os_specific() {
    OS_TYPE="$(os-type)"
    export OS_TYPE

    "${TOOLS_ROOT}/install/${OS_TYPE}/main.sh"
}

# NOTE: order matters here
__deploy_ulogger
__install_bash_lib
__deploy_deployer
__deploy_common
__install_os_specific

