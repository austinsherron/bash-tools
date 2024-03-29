#!/usr/bin/env bash

set -Eeuo pipefail


ulogger info "installing ${OS_TYPE} specific tool packages"

ulogger info "deploying work module"
deploy -p "${TOOLS_ROOT}/work/granica"
deploy -p "${TOOLS_ROOT}/work/granica/cmd"

