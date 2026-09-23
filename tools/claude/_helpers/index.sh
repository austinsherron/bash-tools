#!/usr/bin/env bash

source "${BASH_LIB}/data/store.sh"

source "${BASH_TOOLS}/tools/claude/_helpers/projects.sh"


# A cache of the session metadata cld-ls displays, so that listing sessions costs
# a directory read rather than a scan of every transcript.
#
# One store per project directory (see: projects), holding one keyed record per
# session (see: store, which owns the file format and the locking):
#
#     <session id>\t<branch>\t<title mtime>\t<title>
#
# A session's date isn't stored: it's the transcript's mtime, which is a stat at
# read time and therefore never stale.
#
# An empty title means "known to have no title", which is what keeps reconcile
# from rescanning untitled sessions. "<title mtime>" is the mtime of the title
# sidecar the title was read from, or "-" when it was read from the transcript
# (see: index::stale_titles, which uses it to notice renames).

export STORE_ROOT="${STORE_ROOT:-${XDG_STATE_HOME:-${HOME}/.local/state}/claude}"

__INDEX_DIR="sessions"
# no title sidecar, i.e.: the title came from the transcript
__INDEX_NO_MTIME="-"

# Extracts each transcript's latest title and branch, emitting
# "<session id>\t<branch>\t<title>" per file. Used only to backfill sessions the
# index hasn't seen; thereafter the (far cheaper) title sidecar is the source of
# truth. One awk process covers the whole batch, which is what keeps a cold
# rebuild from costing a process per session.
#
# NOTE: a title containing an escaped quote is truncated here, as the pattern
# stops at the first '"'. The sidecar is parsed w/ jq and so is exact, which
# means any such title is corrected as soon as the session is next written to.
#
# shellcheck disable=SC2016
__INDEX_SCAN_AWK='
    function flush() { if (id != "") print id "\t" branch "\t" title }
    FNR == 1 {
        flush()
        id = FILENAME
        sub(/.*\//, "", id)
        sub(/\.jsonl$/, "", id)
        title = "" ; branch = ""
    }
    {
        if (match($0, /"customTitle":"[^"]*"/))
            title = substr($0, RSTART + 15, RLENGTH - 16)
        if (match($0, /"gitBranch":"[^"]*"/))
            branch = substr($0, RSTART + 13, RLENGTH - 14)
    }
    END { flush() }
'

## paths #######################################################################

#######################################
# Displays the store file backing a path's session index. The file need not
# exist.
# Arguments:
#   path: the directory whose index to display, i.e.: a session's cwd
#######################################
function index::file_for() {
    echo "${STORE_ROOT}/${__INDEX_DIR}/$(projects::encode "${1}")"
}

#######################################
# Displays the store file backing a project directory's session index. The file
# need not exist.
#
# A project directory and its index share a basename--both are the encoded
# path--so a caller holding a project directory can reach its index w/out
# recovering the path it was encoded from, which the encoding makes impossible
# (see: projects). That's what lets a caller act on exactly the directories it
# has already resolved, rather than re-globbing for them.
# Arguments:
#   dir: the project directory whose index to display
#######################################
function index::file_for_dir() {
    echo "${STORE_ROOT}/${__INDEX_DIR}/$(basename "${1}")"
}

#######################################
# Displays the store files backing the session indexes for a path and for any
# directory beneath it, mirroring projects::dirs_under.
# Arguments:
#   path: the directory whose indexes to display
# Outputs:
#   Writes existing index file paths to stdout
#######################################
function index::files_under() {
    local -r encoded="$(projects::encode "${1}")"
    local -r root="${STORE_ROOT}/${__INDEX_DIR}"
    local file

    for file in "${root}/${encoded}" "${root}/${encoded}"-*; do
        [[ -f "${file}" ]] && echo "${file}"
    done

    return 0
}

## records #####################################################################

#######################################
# Displays a session's index record, assembled from its fields.
# Arguments:
#   session: the session id
#   branch: the session's git branch, or "" if unknown
#   mtime: the mtime of the sidecar the title came from, or "-" if it came from
#          the transcript
#   title: the session's title, or "" if it has none
#######################################
function index::record() {
    printf '%s\t%s\t%s\t%s\n' "${1}" "${2:--}" "${3:-${__INDEX_NO_MTIME}}" "${4:-}"
}

#######################################
# Writes a session's record to a path's index, replacing any record it already
# holds for that session.
# Arguments:
#   path: the directory whose index to write, i.e.: the session's cwd
#   session: the session id
#   branch: the session's git branch
#   mtime: the mtime of the sidecar the title came from, or "-"
#   title: the session's title
#######################################
function index::upsert() {
    local -r file="$(index::file_for "${1}")"
    local -r session="${2}"

    store::kv::upsert "${file}" "${session}" "$(index::record "${2}" "${3}" "${4}" "${5}")"
}

#######################################
# Displays every record in a path's index, in insertion order.
# Arguments:
#   path: the directory whose index to read
#######################################
function index::records() {
    store::list "$(index::file_for "${1}")"
}

#######################################
# Merges the indexes of the named project directories into a path's index, then
# removes the ones it merged.
#
# Every field of a record--the session id, its branch, its title and that title's
# sidecar mtime--survives a move of the transcripts, so the records can be carried
# over rather than rebuilt by rescanning moved transcripts. Records are keyed by
# session id, so a session already known to the destination is replaced rather
# than duplicated.
#
# The project directories are named rather than globbed for, so only the ones the
# caller actually moved are merged (see: index::file_for_dir). They need not
# still exist: only their names are used.
# Arguments:
#   dest: the directory whose index to merge into
#   dirs: the project directories whose indexes to merge
# Outputs:
#   Writes the merged index files' paths to stdout, one per line
#######################################
function index::merge() {
    local -r dest="$(index::file_for "${1}")" ; shift
    local -a sources=()
    local dir file

    for dir in "$@"; do
        file="$(index::file_for_dir "${dir}")"

        [[ -f "${file}" ]] || continue
        # a directory that is already the destination has nothing to merge
        [[ "${file}" == "${dest}" ]] && continue

        sources+=("${file}")
    done

    [[ "${#sources[@]}" -eq 0 ]] && return 0

    cat "${sources[@]}" | store::kv::upsert_many "${dest}" || return 1
    rm -f "${sources[@]}"

    printf '%s\n' "${sources[@]}"
}

#######################################
# Removes a path's index, and those of any directory beneath it. The records are
# derived from the transcripts, so a dropped index is rebuilt by the next
# reconcile rather than lost.
# Arguments:
#   path: the directory whose indexes to remove
#######################################
function index::drop() {
    local file

    while IFS= read -r file; do
        rm -f "${file}"
        ulogger debug "dropped index ${file}"
    done < <(index::files_under "${1}")

    return 0
}

## reads #######################################################################

#######################################
# Displays "<session id>\t<mtime>" for every transcript in a project directory,
# w/ the mtime formatted as a display date. One stat call covers the entire
# directory.
# Arguments:
#   dir: the project directory to read
#######################################
function index::transcript_dates() {
    local -r dir="${1}"
    local files=("${dir}"/*.jsonl)

    [[ -e "${files[0]}" ]] || return 0

    # "<date>\t<path>" -> "<session id>\t<date>"
    stat -f '%Sm	%N' -t '%Y-%m-%d %H:%M' "${files[@]}" 2> /dev/null \
        | awk -F'\t' -v OFS='\t' '
            {
                id = $2
                sub(/.*\//, "", id)
                sub(/\.jsonl$/, "", id)
                print id, $1
            }
        '
}

#######################################
# Displays "<session id>\t<mtime>" for every title sidecar in a project
# directory, w/ the mtime as a raw epoch (it's compared, never displayed).
# Sessions w/out a sidecar are absent rather than reported, so this globs the
# sidecars instead of statting a path per session.
#
# The mtime is fractional: two renames in the same second would otherwise be
# indistinguishable, leaving the second one's title unnoticed until the session's
# next turn.
# Arguments:
#   dir: the project directory to read
#######################################
function index::title_mtimes() {
    local -r dir="${1}"
    local files=("${dir}"/*/custom-title.json)

    [[ -e "${files[0]}" ]] || return 0

    # "<mtime>\t<path>" -> "<session id>\t<mtime>"
    stat -f '%Fm	%N' "${files[@]}" 2> /dev/null \
        | awk -F'\t' -v OFS='\t' '
            {
                id = $2
                sub(/\/custom-title\.json$/, "", id)
                sub(/.*\//, "", id)
                print id, $1
            }
        '
}

#######################################
# Displays "<session id>\t<branch>\t<title>" for each of the named sessions, read
# from their transcripts in a single pass.
#
# A session whose transcript is empty--one that has only just started -- yields
# no line at all, so callers must treat a missing line as "no title yet" rather
# than assume one per session.
# Arguments:
#   dir: the sessions' project directory
#   sessions: the session ids to scan
#######################################
function index::scan_transcripts() {
    local -r dir="${1}" ; shift
    local files=() id

    for id in "$@"; do
        files+=("$(projects::transcript_for "${dir}" "${id}")")
    done

    [[ "${#files[@]}" -eq 0 ]] && return 0
    awk "${__INDEX_SCAN_AWK}" "${files[@]}" 2> /dev/null
}

#######################################
# Displays "<branch>\t<title>" for a single session, read from its transcript.
# Arguments:
#   dir: the session's project directory
#   session: the session id
#######################################
function index::scan_transcript() {
    local -r scanned="$(index::scan_transcripts "${1}" "${2}")"

    [[ -z "${scanned}" ]] && return 1

    # drop the session id the batch form leads with
    printf '%s\n' "${scanned#*$'\t'}"
}
