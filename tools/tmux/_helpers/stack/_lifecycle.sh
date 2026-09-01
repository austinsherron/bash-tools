#!/usr/bin/env bash

set -Eeuo pipefail


# Tears a stack down--a stack of one pane is just a normal pane. Detached panes
# are never killed: an orphaned stack (i.e.: one whose slot was destroyed by
# kill-window/kill-session) keeps its shell alive in the holding session.
function stack::teardown() {
    local -r group="${1}"
    local -r sess="$(stack::session "${group}")"
    local pane detached=""
    local -a panes=()

    mapfile -t panes < <(stack::ring "${group}")

    for pane in "${panes[@]}"; do
        [[ -z "${pane}" ]] && continue

        __stack::unmark "${pane}"
        stack::is_detached "${pane}" "${group}" && detached="${pane}"
    done

    if [[ -n "${detached}" ]]; then
        ulogger warn "stack ${group} torn down w/ pane ${detached} still detached; it lives on in session ${sess}"
    elif tmux::is_session "${sess}"; then
        tmux kill-session -t "=${sess}" 2> /dev/null || true
    fi

    rm -rf "$(__stack::file "${group}")" "$(__stack::file "${group}").lock" \
           "$(__stack::mru_file "${group}")" "$(__stack::mru_file "${group}").lock"
    ulogger debug "tore down stack ${group}"
}

# Drops a pane from a stack and promotes the last-viewed stacked pane into its
# slot, then kills it.
function stack::promote() {
    local -r group="${1}" closing="${2}"
    local replacement=""
    local -a mru=()

    stack::forget "${group}" "${closing}"

    mapfile -t mru < <(stack::mru "${group}")
    (( ${#mru[@]} > 0 )) && replacement="${mru[-1]}"

    if [[ -n "${replacement}" ]]; then
        stack::swap_in "${replacement}" "${closing}" "${group}"
        ulogger info "promoted pane ${replacement} into the slot vacated by ${closing}"
    else
        ulogger debug "stack ${group} has no pane left to promote into ${closing}'s slot"
    fi

    # the closing pane is detached by now, so killing it can't disturb the layout
    stack::reap "${group}" "${closing}"
    tmux refresh-client -S 2> /dev/null || true
}

# Swaps the ring neighbor of a slot's pane into that slot.
function stack::cycle() {
    local -r dir="${1}" slot="${2}"
    local group target=""
    local -a ring=()
    local -i i n idx=-1

    group="$(stack::group "${slot}")"

    if [[ -z "${group}" ]]; then
        ulogger debug "pane ${slot} isn't stacked"
        return 0
    fi

    mapfile -t ring < <(stack::ring "${group}")
    n="${#ring[@]}"

    if (( n < 2 )); then
        ulogger debug "stack ${group} has nothing to cycle to"
        return 0
    fi

    for (( i = 0; i < n; i++ )); do
        if [[ "${ring[i]}" == "${slot}" ]]; then
            idx="${i}"
            break
        fi
    done

    if (( idx < 0 )); then
        ulogger warn "pane ${slot} claims stack ${group} but isn't in its ring"
        return 0
    fi

    if [[ "${dir}" == "next" ]]; then
        target="${ring[(idx + 1) % n]}"
    else
        target="${ring[(idx - 1 + n) % n]}"
    fi

    [[ "${target}" == "${slot}" ]] && return 0

    stack::swap_in "${target}" "${slot}" "${group}"
    ulogger debug "cycled ${dir} from pane ${slot} to ${target} (stack ${group})"
}

# Focuses a pane, attaching it to its slot first if it's waiting in a holding
# session. A detached pane's stack is where the user actually wants to land--the
# holding session is an implementation detail, and switching a client to it
# would strand them in a session w/ none of their layout.
function stack::focus() {
    local -r pane="${1}"
    local group slot

    group="$(stack::group "${pane}")"

    if [[ -n "${group}" ]] && stack::is_detached "${pane}" "${group}"; then
        slot="$(stack::slot "${group}")"

        if [[ -n "${slot}" ]]; then
            stack::swap_in "${pane}" "${slot}" "${group}"
            ulogger info "attached pane ${pane} to stack ${group}'s slot"
        else
            # orphaned: the holding session is the only place it still exists
            ulogger warn "stack ${group} has no slot to attach pane ${pane} to"
        fi
    fi

    tmux::focus_pane "${pane}"
}
