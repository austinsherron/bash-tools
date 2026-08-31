#!/usr/bin/env bash

set -Eeuo pipefail


# The stack a pane belongs to, empty if it isn't stacked. Stack names are always
# numeric; anything else is a hand-edited option, and is ignored rather than
# trusted as a path component.
function __stack::group() {
    local group

    group="$(tmux show-options -p -t "${1}" -v "${__STACK_OPT}" 2> /dev/null || true)"
    [[ "${group}" =~ ^[0-9]+$ ]] || return 0

    echo "${group}"
}

# Checks whether a stack exists.
function __stack::has() {
    [[ -f "$(__stack::file "${1}")" ]]
}

# Writes the name of every known stack to stdout.
function __stack::groups() {
    local file base

    [[ -d "${__STACK_DIR}" ]] || return 0

    for file in "${__STACK_DIR}"/*; do
        [[ -f "${file}" ]] || continue

        base="$(basename "${file}")"
        [[ "${base}" =~ ^[0-9]+$ ]] || continue

        echo "${base}"
    done
}

# Writes the name of every stack w/ a holding session to stdout, whether or not
# the stack behind it still exists.
function __stack::sessions() {
    tmux list-sessions -F '#{session_name}' 2> /dev/null \
        | grep "^${__STACK_SESS_PREFIX}" \
        | sed "s|^${__STACK_SESS_PREFIX}||" \
        || true
}

# Writes the pane holding a stack's slot--the one member that isn't detached--to
# stdout, or nothing at all when the stack is orphaned.
function __stack::slot() {
    local -r group="${1}"
    local pane
    local -a panes=()

    mapfile -t panes < <(__stack::ring "${group}")

    for pane in "${panes[@]}"; do
        if ! __stack::is_detached "${pane}" "${group}"; then
            echo "${pane}"
            return 0
        fi
    done
}

# Checks whether a pane is detached, i.e.: waiting in its stack's holding session
# rather than sitting in a real window.
function __stack::is_detached() {
    local -r pane="${1}" group="${2}"
    local sess

    sess="$(tmux display-message -pt "${pane}" '#{session_name}' 2> /dev/null || true)"
    [[ "${sess}" == "$(__stack::session "${group}")" ]]
}

# Marks a pane as a member of a stack. remain-on-exit keeps a dying shell's slot
# alive long enough for the pane-died hook to promote a replacement into it.
function __stack::mark() {
    tmux set-option -p -t "${1}" "${__STACK_OPT}" "${2}"
    tmux set-option -p -t "${1}" remain-on-exit on
}

function __stack::unmark() {
    tmux set-option -p -t "${1}" -u "${__STACK_OPT}" 2> /dev/null || true
    tmux set-option -p -t "${1}" -u "${__STACK_POS_OPT}" 2> /dev/null || true
    tmux set-option -p -t "${1}" -u "${__STACK_CRUMBS_OPT}" 2> /dev/null || true
    tmux set-option -p -t "${1}" -u remain-on-exit 2> /dev/null || true
}

# Writes a stack's panes to stdout as a " > " trail, w/ the entry at the provided
# index prominent and the rest dimmed.
# Arguments:
#   focused: the index (0-based) of the entry to render prominently
#   the entries, in ring order
function __stack::crumbs() {
    local -ri focused="${1}" ; shift
    local -a labels=("$@")
    local -i i
    local out="" sep=""

    # dim for the whole trail, undimmed only around the focused entry
    for (( i = 0; i < ${#labels[@]}; i++ )); do
        if (( i == focused )); then
            out+="${sep}#[nodim]${labels[i]}#[dim]"
        else
            out+="${sep}${labels[i]}"
        fi

        sep=" > "
    done

    echo "#[dim]${out}"
}

# Stamps each of a stack's panes w/ its place in the ring. Positions shift
# whenever the ring gains or loses a pane, so every member is re-stamped at once.
# A pane's own title (@pane_title) is left alone--it outlives the stack.
function __stack::relabel() {
    local -r group="${1}"
    local label
    local -a panes=() labels=()
    local -i i n

    mapfile -t panes < <(__stack::ring "${group}")
    n="${#panes[@]}"

    # a pane is listed by its title, or by its position when it hasn't got one.
    # "#" is doubled: the trail is rendered as a format, and a title is arbitrary
    # text that shouldn't be able to introduce format directives of its own
    for (( i = 0; i < n; i++ )); do
        label="$(tmux show-options -p -t "${panes[i]}" -v "${__PANE_TITLE_OPT}" 2> /dev/null || true)"
        [[ -z "${label}" ]] && label="$(( i + 1 ))"
        labels+=("${label//#/##}")
    done

    for (( i = 0; i < n; i++ )); do
        tmux set-option -p -t "${panes[i]}" "${__STACK_POS_OPT}" \
            "$(( i + 1 )) of ${n}" 2> /dev/null || true
        tmux set-option -p -t "${panes[i]}" "${__STACK_CRUMBS_OPT}" \
            "$(__stack::crumbs "${i}" "${labels[@]}")" 2> /dev/null || true
    done
}
