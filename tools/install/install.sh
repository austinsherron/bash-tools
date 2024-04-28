#!/usr/bin/env bash

set -Eeuo pipefail


# NOTE: these are defined in /etc/profile.d/shared_paths.sh, but depending on when this is
# called, that script may not exists yet
[[ -z "${LOCAL_BIN+x}" ]] && export LOCAL_BIN="/usr/local/bin"
[[ -z "${LOCAL_LIB+x}" ]] && export LOCAL_LIB="/usr/local/lib"

INSTALL_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 || true ; pwd -P)"
TOOLS_ROOT="$(dirname "${INSTALL_DIR}")"
BASH_TOOLS="$(dirname "$(dirname "${INSTALL_DIR}")")"
BASH_LIB="${BASH_TOOLS}/lib/src"
ULOG_ROOT="${TOOLS_ROOT}/log"

source "${BASH_TOOLS}/lib/src/utils/sys.sh"

export INSTALL_DIR
export TOOLS_ROOT
export BASH_TOOLS
export BASH_LIB
export ULOG_ROOT

# globals for deploy
export DEPLOY_DEFAULT_CMD="link"
export DEPLOY_STRICT="info"

# globals for ulogger
export ULOGGER_TYPE="install"
export ULOGGER_PREFIX="tools"

function deploy_deployer() {
    "${TOOLS_ROOT}/package/deploy/deploy" --self
}

function install_bash_lib() {
    deploy -s "${BASH_TOOLS}/lib/src" -d "${LOCAL_LIB}" -n bash-lib -t lib --target bash
}

function deploy_ulogger() {
    deploy -s "${ULOG_ROOT}/core" -n ulogger
}

function deploy_common() {
    deploy -s "${TOOLS_ROOT}/git" -n git
    deploy -s "${TOOLS_ROOT}/package/manage" -n pkgmgr
    deploy -s "${TOOLS_ROOT}/system/config" -n sys-config
    deploy -s "${TOOLS_ROOT}/system/network" -n network
    deploy -s "${TOOLS_ROOT}/system/snapshot" -n snapshot
    deploy -s "${TOOLS_ROOT}/tmux" -n tmux
    deploy -s "${TOOLS_ROOT}/utils/clipboard" -n clipboard
    deploy -s "${TOOLS_ROOT}/utils/data" -n data-utils
    deploy -s "${TOOLS_ROOT}/utils/shell" -n shell-utils
    deploy -s "${TOOLS_ROOT}/utils/web" -n web-utils
}

function install_os_specific() {
    OS_TYPE="$(sys::os_type)"
    export OS_TYPE

    "${TOOLS_ROOT}/install/${OS_TYPE}/main.sh"
}

# NOTE: order matters here
deploy_deployer
install_bash_lib
deploy_ulogger
deploy_common
install_os_specific

