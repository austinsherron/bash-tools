#!/usr/bin/env bash

set -Eeuo pipefail


# populated by __reconcile, keyed by session id:
#   DATES    the transcript's mtime, as a display date (i.e.: the session exists)
#   TITLES   the title sidecar's mtime, as an epoch (absent when there's none)
#   RECORDS  "<branch>\t<title mtime>\t<title>", i.e.: the record minus its key
declare -A DATES=()
declare -A TITLES=()
declare -A RECORDS=()

# how many records the reconcile wrote
CHANGED=0

# Reads the session id and cwd from a hook event on stdin, leaving any value
# given on the command line in place.
function __read_hook_event() {
    local input ; input="$(< /dev/stdin)"

    [[ -z "${SESSION}" ]] \
        && SESSION="$(jq -r '.session_id // empty' <<< "${input}" 2> /dev/null || true)"
    [[ -z "${PATH_ARG}" ]] \
        && PATH_ARG="$(jq -r '.cwd // empty' <<< "${input}" 2> /dev/null || true)"

    return 0
}

# Loads a project directory's transcripts, sidecars and records into DATES,
# TITLES and RECORDS. Takes the project directory and the directory it belongs
# to.
function __load() {
    local -r dir="${1}"
    local -r path="${2}"
    local id value branch mtime title

    while IFS=$'\t' read -r id value; do
        [[ -n "${id}" ]] && DATES["${id}"]="${value}"
    done < <(index::transcript_dates "${dir}")

    while IFS=$'\t' read -r id value; do
        [[ -n "${id}" ]] && TITLES["${id}"]="${value}"
    done < <(index::title_mtimes "${dir}")

    # a record's branch and mtime are never empty (see: index::record), which is
    # what lets read split them: tab is IFS whitespace, so an empty field in the
    # middle of a record would collapse and shift the ones after it
    while IFS=$'\t' read -r id branch mtime title; do
        [[ -n "${id}" ]] || continue
        RECORDS["${id}"]="$(printf '%s\t%s\t%s' "${branch}" "${mtime}" "${title}")"
    done < <(index::records "${path}")
}

# Records a session--path, session id, branch, title mtime, title--updating
# RECORDS to match.
function __record() {
    local -r path="${1}"
    local -r session="${2}"

    index::upsert "${path}" "${2}" "${3}" "${4}" "${5}" || return 1

    RECORDS["${session}"]="$(printf '%s\t%s\t%s' "${3:--}" "${4:--}" "${5:-}")"
    CHANGED=$((CHANGED + 1))

    return 0
}

# Records every session that has a transcript but no record, reading their titles
# and branches from their transcripts. Takes the directory whose index to write
# and its project directory.
#
# This is the only path that reads a transcript, and it runs once per session
# ever--but on a cold index that's every session in the directory, so both the
# scan and the write are done in one batch rather than per session.
function __backfill() {
    local -r path="${1}"
    local -r dir="${2}"
    local -a missing=() batch=()
    local id branch title mtime scanned
    local -A scans=()

    for id in "${!DATES[@]}"; do
        [[ -n "${RECORDS[${id}]+x}" ]] || missing+=("${id}")
    done

    [[ "${#missing[@]}" -eq 0 ]] && return 0
    ulogger debug "backfilling ${#missing[@]} session(s) from their transcripts"

    while IFS=$'\t' read -r id branch title; do
        [[ -n "${id}" ]] && scans["${id}"]="$(printf '%s\t%s' "${branch:--}" "${title}")"
    done < <(index::scan_transcripts "${dir}" "${missing[@]}")

    for id in "${missing[@]}"; do
        if [[ -n "${scans[${id}]+x}" ]]; then
            scanned="${scans[${id}]}"
            branch="${scanned%%$'\t'*}"
            title="${scanned#*$'\t'}"
        else
            # a session that has only just started has nothing to scan yet
            branch="-"
            title=""
        fi

        # a sidecar, where there is one, is exact where the scan is best-effort
        mtime="${TITLES[${id}]:-}"
        if [[ -n "${mtime}" ]]; then
            title="$(projects::title_of "${dir}" "${id}" || echo "${title}")"
        else
            mtime="-"
        fi

        RECORDS["${id}"]="$(printf '%s\t%s\t%s' "${branch}" "${mtime}" "${title}")"
        batch+=("$(index::record "${id}" "${branch}" "${mtime}" "${title}")")
        CHANGED=$((CHANGED + 1))
    done

    # the batch is written outside the loop: piping the loop itself would run it
    # in a subshell, losing RECORDS and CHANGED
    printf '%s\n' "${batch[@]}" | store::kv::upsert_many "$(index::file_for "${path}")"
}

# Backfills sessions the index hasn't seen, refreshes titles whose sidecar has
# been rewritten, and prunes records whose transcript is gone. Loads the
# directory's state as a side effect (see: __load), so it has to run in the
# caller's own shell rather than a subshell.
function __reconcile() {
    local -r path="${1}"
    local -r dir="$(projects::dir_for "${path}")"
    local id record branch title mtime want

    __load "${dir}" "${path}"
    __backfill "${path}" "${dir}"

    # refresh: the sidecar has been rewritten since the title was read, i.e.:
    # the session was renamed w/out a hook recording it.
    for id in "${!RECORDS[@]}"; do
        [[ -n "${DATES[${id}]+x}" ]] || continue

        record="${RECORDS[${id}]}"
        branch="${record%%$'\t'*}"
        record="${record#*$'\t'}"
        mtime="${record%%$'\t'*}"
        title="${record#*$'\t'}"

        want="${TITLES[${id}]:--}"
        [[ "${want}" == "${mtime}" ]] && continue

        # a sidecar that's gone leaves the title as-is; recording the absence
        # keeps this from retrying on every read
        [[ "${want}" != "-" ]] \
            && title="$(projects::title_of "${dir}" "${id}" || echo "${title}")"

        ulogger debug "refreshing ${id} from its title sidecar"
        __record "${path}" "${id}" "${branch}" "${want}" "${title}"
    done

    # prune: a record whose transcript is gone, i.e.: archived or deleted
    for id in "${!RECORDS[@]}"; do
        [[ -n "${DATES[${id}]+x}" ]] && continue

        ulogger debug "pruning ${id}: its transcript is gone"
        store::kv::remove "$(index::file_for "${path}")" "${id}" || continue

        unset "RECORDS[${id}]"
        CHANGED=$((CHANGED + 1))
    done

    return 0
}
