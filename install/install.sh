#!/usr/bin/env bash

set -Eeuo pipefail

source /etc/profile.d/shared_paths.sh
source "${CODE_ROOT}/lib/bash/utils.sh"


DEPLOY="${TOOLS_ROOT}"/system/deploy/deploy
ULOGGER="${TOOLS_ROOT}"/log/ulogger

export OS_TYPE="$(os-type)"
INSTALL_TOOLS_OS="${TOOLS_ROOT}/install/${OS_TYPE}/main.sh"

"${ULOGGER}" info "installing tools repo for os=${OS_TYPE}"
"${ULOGGER}" info "installing common tool packages"

"${ULOGGER}" info "deploying log module"
"${DEPLOY}" log

ulogger info "deploying system/deploy module"
"${DEPLOY}"  -s system deploy

ulogger info "deploying system/config module"
deploy -s system config

ulogger info "deploying system/snapshot module"
deploy -s system snapshot

ulogger info "deploying utils/secrets module"
deploy -s utils secrets

ulogger info "deploying utils/shell module"
deploy -s utils shell

ulogger info "deploying utils/web module"
deploy -s utils web

"${INSTALL_TOOLS_OS}"

