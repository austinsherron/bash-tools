#!/usr/bin/env bash

set -Eeuo pipefail

source /etc/profile.d/shared_paths.sh


ulogger info "installing ${OS_TYPE} specific tool packages"

deploy -p "${TOOLS_ROOT}/system/cron/util"
deploy -p "${TOOLS_ROOT}/system/misc"
deploy -p "${TOOLS_ROOT}/system/status"
deploy -p "${TOOLS_ROOT}/system/systemd/utils"

"${TOOLS_ROOT}/system/cron/install.sh"
"${TOOLS_ROOT}/system/systemd/install.sh"

