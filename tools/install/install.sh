#!/usr/bin/env bash

set -Eeuo pipefail


INSTALL_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 || true ; pwd -P)"
TOOLS_ROOT="$(dirname "${INSTALL_DIR}")"
CODE_ROOT="$(dirname "$(dirname "${INSTALL_DIR}")")"
ULOG_ROOT="${TOOLS_ROOT}/log"

# shellcheck source-path=SCRIPTDIR/../log/internal/log.sh
source "${ULOG_ROOT}/internal/log.sh"

export INSTALL_DIR
export TOOLS_ROOT
export CODE_ROOT
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
    deploy -p "${TOOLS_ROOT}/package/manage"
    deploy -p "${TOOLS_ROOT}/system/config"
    deploy -p "${TOOLS_ROOT}/system/snapshot"
    deploy -p "${TOOLS_ROOT}/utils/data"
    deploy -p "${TOOLS_ROOT}/utils/shell"
    # TODO: wip
    # deploy -p "${TOOLS_ROOT}/utils/secrets"
    deploy -p "${TOOLS_ROOT}/utils/shell"
    deploy -p "${TOOLS_ROOT}/utils/web"
}

function __install_os_specific() {
    # TODO: replace w/ os-type function after bash repo consolidation
    OS_TYPE="$(uname | tr '[:upper:]' '[:lower:]')"
    export OS_TYPE

    "${TOOLS_ROOT}/install/${OS_TYPE}/main.sh"
}

log::info "installing tools repo"

__deploy_ulogger
__deploy_deployer
__deploy_common
__install_os_specific

