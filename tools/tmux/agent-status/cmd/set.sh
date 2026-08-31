#!/usr/bin/env bash

set -Eeuo pipefail


# set <state> [pane]
#
# Flags a pane, defaulting to the calling pane. States are mutually exclusive, so
# the pane is dropped from every other state first. A pane the user is already
# looking at isn't flagged at all (see: tmux-pane-store add-pane).
function cmd::set() {
    local pane="" state=""

    while [[ $# -gt 0 ]]; do
      case $1 in
        -v*|-q*) shift ;;
        *) [[ -z "${state}" ]] && state="${1}" || pane="${1}" ; shift ;;
      esac
    done

    validate_one_of "state" "${state}" "${STATES[@]}" || return 1

    [[ -z "${pane}" ]] && pane="$(tmux::pane_id)"

    local other
    for other in "${STATES[@]}"; do
        [[ "${other}" == "${state}" ]] && continue
        tmux-pane-store remove-pane "${pane}" -s "$(__store_for "${other}")"
    done

    tmux-pane-store add-pane "${pane}" -s "$(__store_for "${state}")"
    cmd::paint
}
