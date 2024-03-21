#!/usr/bin/env bash

set -Eeuo pipefail


ulogger info "installing ${OS_TYPE} specific tool packages"

ulogger info "deploying work module"
deploy work

