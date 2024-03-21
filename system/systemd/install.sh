#!/usr/bin/env bash

set -Eeuo pipefail

source /etc/profile.d/shared_paths.sh


SYSTEMD_UNITS="${TOOLS_ROOT}/system/systemd/units"

ulogger info "installing systemd unitsa"

ulogger info "installing \"run-syngestures\" systemd unit"
"${SYSTEMD_UNITS}"/run-syngestures/install.sh

