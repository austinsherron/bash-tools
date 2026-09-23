#!/usr/bin/env bash

set -Eeuo pipefail


# update [-p path] [-s session]
#
# Records one session. Reads the title from its sidecar, falling back to the
# record the index already holds--so that a session titled before Claude Code
# wrote sidecars doesn't lose its title--and then to a transcript scan.
function cmd::update() {
    local -r path="${1}"
    local -r dir="$(projects::dir_for "${path}")"
    local -r file="$(index::file_for "${path}")"
    local branch title mtime existing scanned

    validate_required "-s|--session" "${SESSION}" || return 1

    # cheap enough to run on every turn's Stop
    branch="$(git -C "${path}" branch --show-current 2> /dev/null || true)"

    if title="$(projects::title_of "${dir}" "${SESSION}")"; then
        # fractional, to match index::title_mtimes--a whole-second mtime would
        # hide a second rename made in the same second as the one recorded here
        mtime="$(stat -f '%Fm' "$(projects::title_file_for "${dir}" "${SESSION}")" 2> /dev/null || echo "-")"
    elif existing="$(store::kv::get "${file}" "${SESSION}")"; then
        # no sidecar: keep the title (and its provenance) we already have
        existing="${existing#*$'\t'}"
        existing="${existing#*$'\t'}"
        mtime="${existing%%$'\t'*}"
        title="${existing#*$'\t'}"
    else
        scanned="$(index::scan_transcript "${dir}" "${SESSION}" || true)"
        title="${scanned#*$'\t'}"
        [[ "${scanned}" != *$'\t'* ]] && title=""
        [[ -z "${branch}" ]] && branch="${scanned%%$'\t'*}"
        mtime="-"
    fi

    index::upsert "${path}" "${SESSION}" "${branch}" "${mtime}" "${title}"
    ulogger debug "recorded ${SESSION} (${branch:--}) as '${title}'"
}
