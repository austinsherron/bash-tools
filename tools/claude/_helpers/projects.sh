#!/usr/bin/env bash


# Claude Code stores a session's transcripts in a directory named for the cwd it
# was launched in, w/ "/" and "." replaced by "-": a session started in
# "/home/me/repo" writes to "<projects root>/-home-me-repo". Sessions launched
# from a sub-directory get their own project directory.
#
# The encoding is lossy -- "/" and "." and "-" all become "-" -- so an encoded
# name can't be decoded back to a path. Callers that need to know which path a
# project directory belongs to must encode candidates and compare.

__CLAUDE_PROJECTS_ROOT="${CLAUDE_CONFIG_DIR}/projects"


function projects::root() {
    echo "${__CLAUDE_PROJECTS_ROOT}"
}

#######################################
# Displays the encoded project directory name for a path.
# Arguments:
#   path: the path to encode
#######################################
function projects::encode() {
    echo "${1}" | tr '/.' '-'
}

#######################################
# Displays the project directory for a path. The directory need not exist.
# Arguments:
#   path: the path whose project directory to display
#######################################
function projects::dir_for() {
    echo "${__CLAUDE_PROJECTS_ROOT}/$(projects::encode "${1}")"
}

#######################################
# Displays the existing project directories for a path and for any directory
# beneath it (i.e.: sessions launched from a sub-directory of the path).
#
# Because the encoding is lossy, the sub-directory glob can also match a sibling
# path -- "<path>-1" matches the glob for "<path>". Callers that can enumerate
# real sibling paths should filter the results.
# Arguments:
#   path: the path whose project directories to display
# Outputs:
#   Writes matching project directory paths to stdout
#######################################
function projects::dirs_under() {
    local encoded ; encoded="$(projects::encode "${1}")"
    local root="${__CLAUDE_PROJECTS_ROOT}"
    local dir

    for dir in "${root}/${encoded}" "${root}/${encoded}"-*; do
        [[ -d "${dir}" ]] && echo "${dir}"
    done

    return 0
}

#######################################
# Displays the path of a session's transcript. The file need not exist.
# Arguments:
#   dir: the session's project directory
#   session: the session id
#######################################
function projects::transcript_for() {
    echo "${1}/${2}.jsonl"
}

#######################################
# Displays the path of a session's title sidecar, which Claude Code rewrites
# whenever the session is renamed. The file need not exist: it's only written
# once a session has been given a title, and sessions titled before Claude Code
# began writing it have none (their title lives in the transcript alone).
# Arguments:
#   dir: the session's project directory
#   session: the session id
#######################################
function projects::title_file_for() {
    echo "${1}/${2}/custom-title.json"
}

#######################################
# Displays a session's title as recorded in its sidecar, if it has one.
# Arguments:
#   dir: the session's project directory
#   session: the session id
# Outputs:
#   Writes the session's title to stdout, or nothing if it has no sidecar
# Returns:
#   0 if a title was found, 1 otherwise
#######################################
function projects::title_of() {
    local -r file="$(projects::title_file_for "${1}" "${2}")"

    [[ -f "${file}" ]] || return 1

    local title
    title="$(jq -r '.customTitle // empty' "${file}" 2> /dev/null)" || return 1

    [[ -z "${title}" ]] && return 1
    printf '%s\n' "${title}"
}

#######################################
# Displays the number of sessions in a project directory, i.e.: its transcripts.
# Arguments:
#   dir: the project directory to count
#######################################
function projects::session_count() {
    local dir="${1}"
    local count=0
    local file

    for file in "${dir}"/*.jsonl; do
        [[ -f "${file}" ]] && count=$((count + 1))
    done

    echo "${count}"
}
