#!/usr/bin/env bash

set -Eeuo pipefail


function __store_for() {
    echo "${STORE_PREFIX}${1}"
}

# The style to paint a state w/: the tmux option if the config defines one,
# the built-in fallback otherwise.
function __style_for() {
    local style ; style="$(tmux show-options -gqv "${STYLE_OPT_PREFIX}${1}" 2> /dev/null || true)"

    [[ -z "${style}" ]] && style="${DEFAULT_STYLES[${1}]}"
    echo "${style}"
}

# The background a style paints with, i.e.: the color that *is* the entry.
function __style_bg() {
    [[ "${1}" =~ bg=([^],[:space:]]+) ]] && echo "${BASH_REMATCH[1]}"
    return 0
}

# Applies a window's options as <opt> <val> pairs, unsetting the ones whose value
# is empty. Every pair goes out in a single tmux invocation so the whole set lands
# in one pass of the server's command queue and the status bar is redrawn once.
#
# Deliberately one invocation per window rather than one for the whole sweep so
# errors are localized.
function __write_opts() {
    local -r win="${1}" ; shift
    local -a cmds=()
    local opt val

    while [[ $# -gt 0 ]]; do
        opt="${1}" ; val="${2}" ; shift 2

        # a lone ";" argument is what separates one tmux command from the next
        [[ "${#cmds[@]}" -gt 0 ]] && cmds+=(";")

        if [[ -n "${val}" ]]; then
            cmds+=(set-option -w -t "${win}" "${opt}" "${val}")
        else
            cmds+=(set-option -w -t "${win}" -u "${opt}")
        fi
    done

    tmux "${cmds[@]}" 2> /dev/null || true
}

# A state's place in the precedence order (see: STATES); sorts loudest first.
function __rank_of() {
    local -i i

    for ((i = 0; i < ${#STATES[@]}; i++)); do
        [[ "${STATES[i]}" == "${1}" ]] && { echo "${i}" ; return 0 ; }
    done

    echo "${#STATES[@]}"
}

# Checks whether a session exists to hold panes rather than to be worked in --
# naming one in an indicator would point somewhere the user can't usefully go.
function __is_private_session() {
    [[ "${1}" =~ ${PRIVATE_SESSION_RE} ]]
}

# The session a window belongs to.
function __session_of() {
    tmux display-message -pt "${1}" '#{session_name}' 2> /dev/null || true
}

# Checks whether the first state outranks the second (see: STATES).
function __louder_than() {
    local -r lhs="${1}" rhs="${2}"
    local -i i

    for ((i = 0; i < ${#STATES[@]}; i++)); do
        [[ "${STATES[i]}" == "${lhs}" ]] && return 0
        [[ "${STATES[i]}" == "${rhs}" ]] && return 1
    done

    return 1
}

# The window a pane should color. Usually the pane's or a detached stacked pane's 
# parent window (see: tmux-stack).
function __window_for() {
    local -r pane="${1}"
    local target="${pane}"
    local group slot

    group="$(stack::group "${pane}")"

    if [[ -n "${group}" ]] && stack::is_detached "${pane}" "${group}"; then
        slot="$(stack::slot "${group}")"
        [[ -n "${slot}" ]] && target="${slot}"
    fi

    tmux display-message -pt "${target}" '#{window_id}' 2> /dev/null || true
}

# Writes "<state> <pane>" for every flagged pane that still exists, loudest state
# last so a caller overwriting as it reads ends up w/ the loudest. Dead panes are
# dropped from their store on the way past.
function __flagged_panes() {
    local pane state
    local -i i
    local -A alive=()

    while read -r pane; do
        [[ -n "${pane}" ]] && alive["${pane}"]=1
    done < <(tmux list-panes -a -F '#{pane_id}' 2> /dev/null)

    # a server that can't be asked what it's running isn't evidence that nothing
    # is: pruning against an empty snapshot would empty every store
    if [[ "${#alive[@]}" -eq 0 ]]; then
        ulogger debug "no panes to check state against"
        return 0
    fi

    for ((i = ${#STATES[@]} - 1; i >= 0; i--)); do
        state="${STATES[i]}"

        while read -r pane; do
            [[ -z "${pane}" ]] && continue

            if [[ -z "${alive[${pane}]:-}" ]]; then
                store remove "$(__store_for "${state}")" "${pane}" || true
                continue
            fi

            echo "${state} ${pane}"
        done < <(store list "$(__store_for "${state}")")
    done
}
