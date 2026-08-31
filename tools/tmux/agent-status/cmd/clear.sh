#!/usr/bin/env bash

set -Eeuo pipefail


# clear [pane]
#
# Unflags a pane, defaulting to the calling pane. Cheap and quiet so it can run
# from a pane-focus-in hook on every pane switch (set ULOGGER_DISABLED=true in
# the hook to silence it entirely).
function cmd::clear() {
    local pane=""

    while [[ $# -gt 0 ]]; do
      case $1 in
        -v*|-q*) shift ;;
        *) pane="${1}" ; shift ;;
      esac
    done

    [[ -z "${pane}" ]] && pane="$(tmux::pane_id)"

    local state
    for state in "${STATES[@]}"; do
        tmux-pane-store remove-pane "${pane}" -s "$(__store_for "${state}")"
    done

    cmd::paint
}
