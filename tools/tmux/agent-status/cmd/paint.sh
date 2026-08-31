#!/usr/bin/env bash

set -Eeuo pipefail


# Collects the state each window should wear into the associative array named by
# the argument, keyed by window id.
#
# A window holding several flagged panes uses the loudest one, so a louder
# state replaces one already recorded.
function _build_desired_map() {
    local -n _desired="${1}"
    local state pane win

    while read -r state pane; do
        [[ -z "${pane}" ]] && continue

        win="$(__window_for "${pane}")"
        [[ -z "${win}" ]] && continue

        if [[ -z "${_desired[${win}]:-}" ]] || __louder_than "${state}" "${_desired[${win}]}"; then
            _desired["${win}"]="${state}"
        fi
    done < <(__flagged_panes)
}

# The three styles a state paints a window with--its body, and the separator
# glyphs on either side--into the variables named by the last three arguments.
# The edges are derived from the body's "bg", so a state whose style sets no
# background gets a body and no edges. An empty state clears all three.
function _get_desired_state() {
    local -r state="${1}"
    local -n _body="${2}" _edge_in="${3}" _edge_out="${4}"
    local bg

    _body="" ; _edge_in="" ; _edge_out=""

    [[ -z "${state}" ]] && return 0

    _body="$(__style_for "${state}")"
    bg="$(__style_bg "${_body}")"

    [[ -z "${bg}" ]] && return 0

    _edge_in="#[bg=${bg}]"
    _edge_out="#[fg=${bg}]"
}

# Whether a window's options differ from what its state calls for.
#
# All three are compared, not just the body: the edges are derived from it but
# aren't guaranteed to have been *written* from it. A window painted by a version
# of this that didn't know about edges carries a body and nothing else, and
# diffing on the body alone would leave it that way forever.
function _needs_paint() {
    local -r cur="${1}" cur_in="${2}" cur_out="${3}"
    local -r want="${4}" want_in="${5}" want_out="${6}"

    if [[ "${cur}" != "${want}" ]] \
        || [[ "${cur_in}" != "${want_in}" ]] \
        || [[ "${cur_out}" != "${want_out}" ]]; then
        return 0
    fi

    return 1
}

function _write_state() {
    local -r win="${1}" want="${2}" want_in="${3}" want_out="${4}"

    __write_opts "${win}" \
        "${WINDOW_OPT}" "${want}" \
        "${EDGE_IN_OPT}" "${want_in}" \
        "${EDGE_OUT_OPT}" "${want_out}"
}

function _list_windows() {
    tmux list-windows -a -F \
        "#{window_id}${SEP}#{${WINDOW_OPT}}${SEP}#{${EDGE_IN_OPT}}${SEP}#{${EDGE_OUT_OPT}}" \
        2> /dev/null
}

# paint
#
# Recolors every window from the stores. A window is only written when what it
# wears differs from what its state calls for, so the common case--a sweep that
# finds nothing new--costs two tmux calls and no redraw. Prints nothing: it runs
# from the status bar as part of a "#()" format, where any output would be drawn.
function cmd::paint() {
    local -A desired=()
    local win cur cur_in cur_out want want_in want_out
    local changed=""

    _build_desired_map desired

    while IFS="${SEP}" read -r win cur cur_in cur_out; do
        [[ -z "${win}" ]] && continue

        _get_desired_state "${desired[${win}]:-}" want want_in want_out
        _needs_paint "${cur}" "${cur_in}" "${cur_out}" \
                     "${want}" "${want_in}" "${want_out}" || continue

        _write_state "${win}" "${want}" "${want_in}" "${want_out}"
        changed="true"
    done < <(_list_windows)

    # a server w/out an attached client has nothing to redraw and says so w/ a
    # non-zero exit. The options are written either way, so not a failure
    if [[ -n "${changed}" ]]; then
        tmux refresh-client -S 2> /dev/null || true
    fi

    return 0
}
