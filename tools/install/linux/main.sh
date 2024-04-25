#!/usr/bin/env bash

set -Eeuo pipefail

source /etc/profile.d/shared_paths.sh


ulogger info "installing ${OS_TYPE} specific tool packages"

deploy -s "${TOOLS_ROOT}/system/cron/util" -n cron-util
deploy -s "${TOOLS_ROOT}/system/misc" -n sys-misc
deploy -s "${TOOLS_ROOT}/system/status" -n sys-status
deploy -s "${TOOLS_ROOT}/system/systemd/utils" -n systemd-utils

"${TOOLS_ROOT}/system/cron/install.sh"
"${TOOLS_ROOT}/system/systemd/install.sh"

