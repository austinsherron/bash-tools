#!/usr/bin/env bash

set -Eeuo pipefail

source /etc/profile.d/shared_paths.sh


ulogger info "installing ${OS_TYPE} specific tool packages"

deploy -s system/cron util
deploy -s system misc
deploy -s system status
deploy -s system/systemd utils

"${TOOLS_ROOT}/system/cron/install.sh"
"${TOOLS_ROOT}/system/systemd/install.sh"

