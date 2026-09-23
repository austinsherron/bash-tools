#!/usr/bin/env bash

source "${BASH_LIB}/args/validate.sh"
source "${BASH_LIB}/core/_shared.sh"


# An insertion-ordered store backed by a plain, newline-delimited file. All
# functions operate on a store *file path*; callers are responsible for resolving
# a store name to a path. Mutations are serialized w/ an atomic-mkdir lock so
# concurrent writers (i.e.: many processes) don't clobber each other.
#
# NOTE: entries must not contain newlines. "Oldest" is the first-inserted entry
# (top of the file), "newest" is the last-inserted (bottom).
#
# A store comes in one of two kinds, and the public API is split to match:
#
#   value stores    entries are opaque strings, deduped by exact value.
#                   Written w/ store::push; addressed by value (store::remove,
#                   store::has).
#
#   keyed stores    entries are records whose first tab-delimited field is a
#                   key, deduped by that key. Written w/ store::kv::upsert;
#                   addressed by key (store::kv::get, store::kv::remove).
#
# A store is one kind or the other--store::push on a keyed store appends a
# duplicate key rather than replacing the record, which breaks the uniqueness
# store::kv::get and store::kv::upsert rely on. Nothing enforces this at runtime;
# it's the caller's job to use one family per store.
#
# The remaining functions--store::list, store::count, store::clear, store::peek, 
# store::pop, store::stores--address entries positionally or not at all, and so 
# are safe on either kind.

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

## internal (unlocked) implementations: any store ##############################

function __store::ensure() {
    local -r file="${1}"
    local -r dir="$(dirname "${file}")"

    [[ -d "${dir}" ]] || mkdir -p "${dir}"
    [[ -f "${file}" ]] || touch "${file}"
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

function __store::clear_impl() {
    local -r file="${1}"

    [[ -f "${file}" ]] && : > "${file}"
    return 0
}

## internal (unlocked) implementations: value stores ###########################

function __store::push_impl() {
    local -r file="${1}"
    local -r value="${2}"

    __store::ensure "${file}"

    # dedup by exact value; keep the original position (oldest == first-seen)
    grep -qxF -e "${value}" "${file}" && return 0
    printf '%s\n' "${value}" >> "${file}"
}

function __store::remove_impl() {
    local -r file="${1}"
    local -r value="${2}"
    local -r tmp="${file}.tmp.$$"

    [[ -f "${file}" ]] || return 0

    # grep exits 1 when nothing matches (i.e.: every line removed); that's fine
    grep -vxF -e "${value}" "${file}" > "${tmp}" || true
    mv "${tmp}" "${file}"
}

## internal (unlocked) implementations: keyed stores ###########################

function __store::kv::upsert_impl() {
    local -r file="${1}"
    local -r key="${2}"
    local -r value="${3}"
    local -r tmp="${file}.tmp.$$"

    __store::ensure "${file}"

    # one awk pass, so the record's position is preserved on replace and the
    # read can't interleave w/ the write. key and value go through the
    # environment rather than -v, which would expand escapes in them.
    #
    # the second key rule drops any further record carrying the key, so a store
    # that already holds duplicates is collapsed rather than left as-is (see:
    # __store::kv::upsert_many_impl, which must agree w/ this).
    if ! __STORE_KEY="${key}" __STORE_VALUE="${value}" awk -F'\t' '
        BEGIN { key = ENVIRON["__STORE_KEY"] ; value = ENVIRON["__STORE_VALUE"] }
        $1 == key && !replaced { print value ; replaced = 1 ; next }
        $1 == key { next }
        { print }
        END { if (!replaced) print value }
    ' "${file}" > "${tmp}"; then
        rm -f "${tmp}"
        return 1
    fi

    mv "${tmp}" "${file}"
}

function __store::kv::upsert_many_impl() {
    local -r file="${1}"
    local -r batch="${2}"
    local -r tmp="${file}.tmp.$$"

    __store::ensure "${file}"

    # the batch is read first, then the store is streamed through it: a record
    # whose key is in the batch is replaced where it stands, and the rest of the
    # batch is appended in the order it was given. One rewrite for the whole
    # batch, where an upsert per record would rewrite the file each time.
    if ! awk -F'\t' '
        NR == FNR {
            if ($0 == "") next
            if (!($1 in batch)) order[++n] = $1
            batch[$1] = $0
            next
        }
        $1 in batch && !seen[$1] { print batch[$1] ; seen[$1] = 1 ; next }
        $1 in batch { next }
        { print }
        END { for (i = 1; i <= n; i++) if (!seen[order[i]]) print batch[order[i]] }
    ' "${batch}" "${file}" > "${tmp}"; then
        rm -f "${tmp}"
        return 1
    fi

    mv "${tmp}" "${file}"
}

function __store::kv::remove_impl() {
    local -r file="${1}"
    local -r key="${2}"
    local -r tmp="${file}.tmp.$$"

    [[ -f "${file}" ]] || return 0

    if ! __STORE_KEY="${key}" awk -F'\t' '
        BEGIN { key = ENVIRON["__STORE_KEY"] }
        $1 != key
    ' "${file}" > "${tmp}"; then
        rm -f "${tmp}"
        return 1
    fi

    mv "${tmp}" "${file}"
}

## public API: any store #######################################################

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

## public API: value stores ####################################################

#######################################
# Appends a value to the store if it isn't already present (idempotent).
#
# NOTE: for value stores only--on a keyed store this appends a duplicate key
# rather than replacing the record (see: store::kv::upsert).
#
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
# Removes the entry matching value from the store (no-op if absent). Matches the
# entry in full, so removing a keyed record this way means passing the whole
# record -- store::kv::remove takes the key instead.
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

    __store::with_lock "${file}" __store::remove_impl "${file}" "${value}"
}

#######################################
# Checks whether the store contains value. Matches the entry in full, so a keyed
# record has to be passed whole (see: store::remove).
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

## public API: keyed stores ####################################################

#######################################
# Writes a keyed record to the store, replacing the record carrying the same key
# if there is one and appending it otherwise. A record's key is its first
# tab-delimited field; a replaced record keeps its position in the store. Any
# further record carrying the key is dropped, so duplicates are collapsed.
#
# The key is passed separately rather than derived from the value so that a
# caller can rekey a record, and so that a malformed value fails loudly.
# Arguments:
#   file: the store file
#   key: the key to write under, i.e.: the value's first tab-delimited field
#   value: the record to write
# Returns:
#   0 on success, non-zero on lock/write failure
#######################################
function store::kv::upsert() {
    local -r file="${1}"
    local -r key="${2:-}"
    local -r value="${3:-}"

    validate_required_positional "store file" "${file}" || return 1
    validate_required_positional "key" "${key}" || return 1
    validate_required_positional "value" "${value}" || return 1

    if [[ "${value%%$'\t'*}" != "${key}" ]]; then
        ulogger error "store: value's first field is not '${key}': ${value}" >&2 || true
        return 1
    fi

    __store::with_lock "${file}" __store::kv::upsert_impl "${file}" "${key}" "${value}"
}

#######################################
# Writes many keyed records to the store at once, reading them from stdin, one
# per line. Equivalent to a store::kv::upsert per record -- each replaces the
# record carrying its key, in place, and is appended otherwise -- but takes the
# lock once and rewrites the store once, so a bulk rebuild doesn't cost a rewrite
# per record. Where two records share a key, the last wins.
# Arguments:
#   file: the store file
# Inputs:
#   the records to write, one per line, read from stdin
# Returns:
#   0 on success, non-zero on lock/write failure
#######################################
function store::kv::upsert_many() {
    local -r file="${1}"

    validate_required_positional "store file" "${file}" || return 1

    local -r batch="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '${batch}'" RETURN

    cat > "${batch}"
    [[ -s "${batch}" ]] || return 0

    __store::with_lock "${file}" __store::kv::upsert_many_impl "${file}" "${batch}"
}

#######################################
# Writes the keyed record matching key to stdout.
# Arguments:
#   file: the store file
#   key: the key whose record to display
# Outputs:
#   the matching record, if any
# Returns:
#   0 if a record was found, 1 otherwise
#######################################
function store::kv::get() {
    local -r file="${1}"
    local -r key="${2:-}"

    validate_required_positional "store file" "${file}" || return 1
    validate_required_positional "key" "${key}" || return 1

    [[ -f "${file}" ]] || return 1

    # awk compares the key as a literal field, so no regex escaping is needed
    local record
    record="$(__STORE_KEY="${key}" awk -F'\t' '
        BEGIN { key = ENVIRON["__STORE_KEY"] }
        $1 == key { print ; exit }
    ' "${file}")"

    [[ -z "${record}" ]] && return 1
    printf '%s\n' "${record}"
}

#######################################
# Removes the record matching key from the store, if any.
# Arguments:
#   file: the store file
#   key: the key whose record to remove
# Returns:
#   0 on success, non-zero on lock/write failure
#######################################
function store::kv::remove() {
    local -r file="${1}"
    local -r key="${2:-}"

    validate_required_positional "store file" "${file}" || return 1
    validate_required_positional "key" "${key}" || return 1

    __store::with_lock "${file}" __store::kv::remove_impl "${file}" "${key}"
}
