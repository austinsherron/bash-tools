#!/usr/bin/env bash

set -Eeuo pipefail


function _should_report_session() {
    local sess="${1}"
    local viewing="${2}"

    [[ -z "${sess}" ]] && return 1
    [[ "${sess}" == "${viewing}" ]] && return 1
    __is_private_session "${sess}" && return 1

    return 0
}

function _get_count_map() {
    local -n _counts="${1}"
    local -n _loudest="${2}"
    local viewing="${3}"
    local state pane win sess

    while read -r state pane; do
        [[ -z "${pane}" ]] && continue

        # by the window it colors, not the one it sits in: a pane detached in a
        # stack belongs to the session holding that stack's slot
        win="$(__window_for "${pane}")"
        [[ -z "${win}" ]] && continue

        sess="$(__session_of "${win}")"
        _should_report_session "${sess}" "${viewing}" || continue

        _counts["${sess}"]=$(( ${_counts["${sess}"]:-0} + 1 ))

        if [[ -z "${_loudest[${sess}]:-}" ]] || __louder_than "${state}" "${_loudest[${sess}]}"; then
            _loudest["${sess}"]="${state}"
        fi
    done < <(__flagged_panes)
}

function _write_status() {
    # shellcheck disable=SC2178
    local -n _counts="${1}"
    # shellcheck disable=SC2178
    local -n _loudest="${2}"
    local -n _ordered="${3}"
    local sess out=""

    # loudest first, then by name: the sessions that want something come before
    # the ones that are merely finished, and the order holds between redraws
    mapfile -t _ordered < <(
        for sess in "${!_counts[@]}"; do
            printf '%s\t%s\n' "$(__rank_of "${_loudest[${sess}]}")" "${sess}"
        done | sort -t$'\t' -k1,1n -k2,2 | cut -f2-
    )

    for sess in "${_ordered[@]}"; do
        out+="$(__style_for "${_loudest[${sess}]}") ${sess} ${_counts[${sess}]} ${RESET_STYLE} "
    done

    printf '%s\n' "${out}"
}

# status [session]
#
# Prints one indicator per session holding flagged panes: its name, how many of
# its panes are flagged, and the color of the loudest of them. Prints nothing
# when no other session is flagged.
#
# The session named by the argument is left out -- it's the one being looked at,
# and its own windows already wear their state in the window list; the segment is
# for the sessions the user can't see. Meant to be embedded in the status bar as
#
#     #(tmux-agent-status status "#{client_session}")
#
# which tmux expands per client, so each attached session is told what it's
# looking at (and, the command string differing, gets its own cached run). Called
# w/out one, no session is left out.
#
# Sweeps before printing, so the counts here and the colors the window list is
# wearing come from a single read of the stores.
function cmd::status() {
    local viewing=""
    # shellcheck disable=SC2034
    local -A counts=() loudest=()
    # shellcheck disable=SC2034
    local -a ordered=()

    while [[ $# -gt 0 ]]; do
      case $1 in
        -v*|-q*) shift ;;
        *) viewing="${1}" ; shift ;;
      esac
    done

    cmd::paint

    _get_count_map counts loudest "${viewing}"
    [[ "${#counts[@]}" -eq 0 ]] && return 0

    _write_status counts loudest ordered
}
