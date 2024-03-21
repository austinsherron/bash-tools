#!/usr/bin/env bash

set -Eeuo pipefail

source /etc/profile.d/shared_paths.sh


ulogger info "installing ${OS_TYPE} specific tool packages"

ulogger info "deploying system/cron/util module"
deploy -s system/cron util

ulogger info "deploying system/misc module"
deploy -s system misc

ulogger info "deploying system/pkg module"
deploy -s system pkg

ulogger info "deploying system/status module"
deploy -s system status

ulogger info "deploying system/systemd/utils module"
deploy -s system/systemd utils

"${TOOLS_ROOT}"/system/systemd/install.sh
"${TOOLS_ROOT}"/system/cron/install.sh

