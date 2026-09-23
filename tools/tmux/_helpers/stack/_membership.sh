#!/usr/bin/env bash

set -Eeuo pipefail


# The stack a pane belongs to, empty if it isn't stacked. Stack names are always
# numeric; anything else is a hand-edited option, and is ignored rather than
# trusted as a path component.
function stack::group() {
    local group

    group="$(tmux show-options -p -t "${1}" -v "${__STACK_OPT}" 2> /dev/null || true)"
    [[ "${group}" =~ ^[0-9]+$ ]] || return 0

    echo "${group}"
}

# Checks whether a stack exists.
function stack::has() {
    [[ -f "$(__stack::file "${1}")" ]]
}

# Writes the name of every known stack to stdout.
function stack::groups() {
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
function stack::sessions() {
    tmux list-sessions -F '#{session_name}' 2> /dev/null \
        | grep "^${__STACK_SESS_PREFIX}" \
        | sed "s|^${__STACK_SESS_PREFIX}||" \
        || true
}

# Writes the pane holding a stack's slot--the one member that isn't detached--to
# stdout, or nothing at all when the stack is orphaned.
function stack::slot() {
    local -r group="${1}"
    local pane
    local -a panes=()

    mapfile -t panes < <(stack::ring "${group}")

    for pane in "${panes[@]}"; do
        if ! stack::is_detached "${pane}" "${group}"; then
            echo "${pane}"
            return 0
        fi
    done
}

# Writes the pane whose session/window a pane logically lives in to stdout:
# itself, or--when it's detached--the pane holding its stack's slot. A holding
# session is an implementation detail the user never navigates to, so anything
# naming a pane's location (a notification, a status indicator) wants this
# rather than where the pane happens to be parked.
#
# Resolved from the panes themselves rather than from the stack's stores: it
# costs a single tmux call, and it still answers for a stack whose state was
# lost while its panes kept their marks. An orphaned stack--one w/ no member
# outside the holding session--anchors to the pane itself; there's nowhere
# better to point.
function stack::anchor() {
    local -r pane="${1}"
    local group sess id pgroup psess

    group="$(stack::group "${pane}")"

    if [[ -z "${group}" ]] || ! stack::is_detached "${pane}" "${group}"; then
        echo "${pane}"
        return 0
    fi

    sess="$(stack::session "${group}")"

    # the stack name comes before the session name: a session name may contain
    # spaces, and read gives whatever is left over to the last variable
    while read -r id pgroup psess; do
        [[ "${pgroup}" == "${group}" ]] || continue
        [[ "${psess}" == "${sess}" ]] && continue

        echo "${id}"
        return 0
    done < <(
        tmux list-panes -a -F "#{pane_id} #{${__STACK_OPT}} #{session_name}" 2> /dev/null
    )

    echo "${pane}"
}

# Checks whether a pane is detached, i.e.: waiting in its stack's holding session
# rather than sitting in a real window.
function stack::is_detached() {
    local -r pane="${1}" group="${2}"
    local sess

    sess="$(tmux display-message -pt "${pane}" '#{session_name}' 2> /dev/null || true)"
    [[ "${sess}" == "$(stack::session "${group}")" ]]
}

# Marks a pane as a member of a stack. remain-on-exit keeps a dying shell's slot
# alive long enough for the pane-died hook to promote a replacement into it.
function stack::mark() {
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
function stack::relabel() {
    local -r group="${1}"
    local label
    local -a panes=() labels=()
    local -i i n

    mapfile -t panes < <(stack::ring "${group}")
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
