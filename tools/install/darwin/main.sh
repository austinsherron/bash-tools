#!/usr/bin/env bash

set -Eeuo pipefail


ulogger info "installing ${OS_TYPE} specific tool packages"

ulogger info "deploying shim module"
deploy -s "${TOOLS_ROOT}/darwin/shim" -n mac-shims

ulogger info "deploying work module"
deploy -s "${TOOLS_ROOT}/work/granica" -n granica

