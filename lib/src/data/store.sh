#!/usr/bin/env bash

source "${BASH_LIB}/args/validate.sh"
source "${BASH_LIB}/core/_shared.sh"


# A generic, insertion-ordered, deduped-by-value store backed by a plain,
# newline-delimited file. All functions operate on a store *file path*;
# callers are responsible for resolving a store name to a path. Mutations
# are serialized w/ an atomic-mkdir lock so concurrent writers (e.g.: many
# processes) don't clobber each other.
#
# NOTE: entries must not contain newlines. "Oldest" is the first-inserted entry
# (top of the file), "newest" is the last-inserted (bottom).

## locking #####################################################################

#######################################
# Runs a command while holding an exclusive lock for the provided store file.
#
# The lock is an atomic mkdir of "${file}.lock". If the lock can't be acquired
# within a short window it's assumed to be stale (held by a dead process) and is
# stolen. The lock is always released, whether the command succeeds or fails.
# Arguments:
#   file: the store file to lock
#   cmd: the command (and its args) to run under the lock
# Returns:
#   the return code of the provided command, or 1 if the lock can't be acquired
#######################################
function __store::with_lock() {
    local file="${1}" ; shift
    local -r lock="${file}.lock"
    local -i tries=0
    local -ri max_tries=100

    # the lock is a sibling of the store file, so its parent must exist first
    mkdir -p "$(dirname "${file}")"

    while ! mkdir "${lock}" 2> /dev/null; do
        tries+=1
        if (( tries >= max_tries )); then
            # the holder is almost certainly dead (ops are sub-ms); steal the lock
            ulogger warn "store: stealing stale lock for ${file}" >&2 || true
            rmdir "${lock}" 2> /dev/null || true
            mkdir "${lock}" 2> /dev/null && break
            ulogger error "store: unable to acquire lock for ${file}" >&2 || true
            return 1
        fi
        sleep 0.01
    done

    local -i rc=0
    "$@" || rc=$?
    rmdir "${lock}" 2> /dev/null || true

    return "${rc}"
}

## internal (unlocked) implementations #########################################

function __store::ensure() {
    local -r file="${1}"
    local -r dir="$(dirname "${file}")"

    [[ -d "${dir}" ]] || mkdir -p "${dir}"
    [[ -f "${file}" ]] || touch "${file}"
}

function __store::push_impl() {
    local -r file="${1}"
    local -r value="${2}"

    __store::ensure "${file}"

    # dedup by exact value; keep the original position (oldest == first-seen)
    grep -qxF -e "${value}" "${file}" && return 0
    printf '%s\n' "${value}" >> "${file}"
}

function __store::pop_impl() {
    local -r file="${1}"
    local -r which="${2}"
    local -r tmp="${file}.tmp.$$"
    local value

     [[ -f "${file}" ]] || return 1

    if [[ "${which}" == "newest" ]]; then
        value="$(tail -n 1 "${file}")"
        sed '$d' "${file}" > "${tmp}"
    else
        value="$(head -n 1 "${file}")"
        tail -n +2 "${file}" > "${tmp}"
    fi

    [[ -z "${value}" ]] && return 1
    mv "${tmp}" "${file}"

    printf '%s\n' "${value}"
}

function __store::remove_impl() {
    local -r file="${1}"
    local -r tmp="${file}.tmp.$$"

    [[ -f "${file}" ]] || return 0

    # grep exits 1 when nothing matches (i.e.: every line removed); that's fine
    grep -vxF -e "${value}" "${file}" > "${tmp}" || true
    mv "${tmp}" "${file}"
}

function __store::clear_impl() {
    local -r file="${1}"

    [[ -f "${file}" ]] && : > "${file}"
    return 0
}

## public API ##################################################################

#######################################
# Appends a value to the store if it isn't already present (idempotent).
# Arguments:
#   file: the store file
#   value: the value to append
# Returns:
#   0 on success, non-zero on lock/write failure
#######################################
function store::push() {
    local -r file="${1}"
    local value="${2}"

    validate_required_positional "store file" "${file}" || return 1
    validate_required_positional "value" "${2:-}" || return 1

    __store::with_lock "${file}" __store::push_impl "${file}" "${value}"
}

#######################################
# Writes the store's entries to stdout, oldest first, one per line.
# Arguments:
#   file: the store file
# Outputs:
#   the store's entries, one per line
#######################################
function store::list() {
    local -r file="${1}"

    validate_required_positional "store file" "${file}" || return 1

    [[ -f "${file}" ]] || return 0
    cat "${file}"
}

#######################################
# Writes the number of entries in the store to stdout.
# Arguments:
#   file: the store file
# Outputs:
#   the entry count
#######################################
function store::count() {
    local -r file="${1}"

    validate_required_positional "store file" "${file}" || return 1

    if [[ ! -f "${file}" ]]; then
        echo 0
        return 0
    fi

    local -r n="$(wc -l < "${file}")"
    echo "$(( n ))"
}

#######################################
# Writes the names of all stores under a root directory to stdout, one per line.
# A store is any regular file under root; lock dirs and transient temp files are
# excluded. Names are paths relative to root.
# Arguments:
#   root: the store root directory
# Outputs:
#   store names, one per line, sorted
#######################################
function store::stores() {
    local -r root="${1}"

    validate_required_positional "store root" "${root}" || return 1
    [[ -d "${root}" ]] || return 0

    (
        cd "${root}" || exit 0
        find . -type d -name '*.lock' -prune -o -type f -not -name '*.tmp.*' -print
    ) 2> /dev/null | sed 's|^\./||' | sort
}

function __store::peek_impl() {
    local -r file="${1}"
    local -r which="${2}"

    if [[ "${which}" == "newest" ]]; then
        tail -n 1 "${file}"
    else
        head -n 1 "${file}"
    fi
}

#######################################
# Writes a single entry to stdout without removing it.
# Arguments:
#   file: the store file
#   -o|--oldest: peek the oldest entry (default)
#   -n|--newest: peek the newest entry
# Outputs:
#   the peeked entry
# Returns:
#   0 if an entry was found, 1 if the store is empty
#######################################
function store::peek() {
    local -r file="${1}" ; shift
    local which="oldest"

    validate_required_positional "store file" "${file}" || return 1

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -o|--oldest) which="oldest" ; shift ;;
            -n|--newest) which="newest" ; shift ;;
            *) shift ;;
        esac
    done

    [[ -f "${file}" ]] || return 1

    local value
    value="$(__store::peek_impl "${file}" "${which}")"
    [[ -z "${value}" ]] && return 1

    printf '%s\n' "${value}"
}

#######################################
# Writes a single entry to stdout and removes it from the store (atomically).
# Arguments:
#   file: the store file
#   -o|--oldest: pop the oldest entry (default)
#   -n|--newest: pop the newest entry
# Outputs:
#   the popped entry
# Returns:
#   0 if an entry was popped, 1 if the store is empty
#######################################
function store::pop() {
    local -r file="${1}" ; shift
    local which="oldest"

    validate_required_positional "store file" "${file}" || return 1

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -o|--oldest) which="oldest" ; shift ;;
            -n|--newest) which="newest" ; shift ;;
            *) shift ;;
        esac
    done

    __store::with_lock "${file}" __store::pop_impl "${file}" "${which}"
}

#######################################
# Removes the entry matching value from the store (no-op if absent).
# Arguments:
#   file: the store file
#   value: the value to remove
# Returns:
#   0 on success, non-zero on lock/write failure
#######################################
function store::remove() {
    local -r file="${1}"
    local value="${2:-}"

    validate_required_positional "store file" "${file}" || return 1
    validate_required_positional "value" "${value}" || return 1

    __store::with_lock "${file}" __store::remove_impl "${file}" "${2}"
}

#######################################
# Checks whether the store contains value.
# Arguments:
#   file: the store file
#   value: the value to check for
# Returns:
#   0 if the store contains value, 1 otherwise
#######################################
function store::has() {
    local -r file="${1}"
    local -r value="${2:-}"

    [[ -f "${file}" ]] || return 1
    grep -qxF -e "${value}" "${file}"
}

#######################################
# Removes all entries from the store.
# Arguments:
#   file: the store file
# Returns:
#   0 on success, non-zero on lock failure
#######################################
function store::clear() {
    local -r file="${1}"

    validate_required_positional "store file" "${file}" || return 1

    __store::with_lock "${file}" __store::clear_impl "${file}"
}
