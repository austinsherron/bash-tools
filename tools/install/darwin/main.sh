#!/usr/bin/env bash

set -Eeuo pipefail


ulogger info "installing ${OS_TYPE} specific tool packages"

ulogger info "deploying darwin module"
deploy -s "${TOOLS_ROOT}/darwin" -n darwin

ulogger info "deploying work module"
deploy -s "${TOOLS_ROOT}/work/maybern" -n work

