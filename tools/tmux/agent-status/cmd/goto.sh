#!/usr/bin/env bash

set -Eeuo pipefail


# goto [oldest|newest]
#
# Focuses a flagged pane and unflags it, walking the states loudest first so the
# panes that want something come before the ones that are merely finished.
# Defaults to the oldest pane of that state.
function cmd::goto() {
    local which="oldest"

    while [[ $# -gt 0 ]]; do
      case $1 in
        -v*|-q*) shift ;;
        *) which="${1}" ; shift ;;
      esac
    done

    validate_one_of "which" "${which}" oldest newest || return 1

    local state
    for state in "${STATES[@]}"; do
        [[ "$(store count "$(__store_for "${state}")")" -eq 0 ]] && continue

        tmux-pane-store goto "${which}" -s "$(__store_for "${state}")"
        cmd::paint
        return 0
    done

    ulogger debug "no flagged panes"
}
