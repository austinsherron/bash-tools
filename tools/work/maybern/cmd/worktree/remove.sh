#!/usr/bin/env bash


# The "worktree remove" command; sourced by main.sh.

## help ########################################################################

function wt::help::remove() {
cat <<help
DESCRIPTION

    Kills the worktree's tmux window, archives its Claude session history into
    its category's default worktree, removes the worktree, and deletes the
    branch it held (see -b).

    The window is the one named after the worktree (see: [list]), killed on both
    the local env server and the current one; -w leaves it where it is.

    The window is killed first: a Claude session still running in the worktree
    recreates its transcript as fast as the archive moves it away, so its
    history can't be archived whole until it's gone. Archiving comes next, ahead
    of the removal: a failure there leaves both the worktree and its history
    intact. A category w/o a default worktree has nowhere to archive to, so the
    history is left where it is, w/ a warning.

    The branch goes last, after the worktree that held it: git won't delete a
    branch that's checked out anywhere. A branch that isn't fully merged is kept
    instead, w/ a warning, unless -f is given -- the worktree is gone by then
    either way, so the branch is never what fails the removal. A detached
    worktree has no branch, and so nothing to delete.

    The worktree is unregistered, not waited on: its directory is renamed aside
    and deleted in the background, so the removal returns in the time a rename
    takes rather than the time it takes to unlink a worktree's worth of
    installed deps.

    Refuses to remove the main worktree, a category's default worktree, or a
    worktree w/ uncommitted changes (see -f). Confirmation is required.

USAGE

    ${WT_USAGE[remove]}

ALIASES

    $(aliases_for WT_ALIASES remove)

POSITIONAL ARGUMENTS

    WORKTREE        optional, picked w/ fzf otherwise; the "<category>/<item>"
                    identifier of the worktree to remove

FLAGS

    -f              remove the worktree even if it has uncommitted changes, and
                    delete its branch even if it isn't fully merged
    -n              dry run: display what would be removed and archived, and
                    make no changes
    -k              keep the worktree's session history where it is instead of
                    archiving it
    -w, --keep-window
                    keep the worktree's tmux window instead of killing it
    -b, --keep-branch
                    keep the worktree's branch instead of deleting it
    -h, --help      display this message
help
}

## helpers #####################################################################

function __wt::confirmed() {
    local rc=0
    input::confirm "${1}" || rc=$?

    [[ "${rc}" -eq "${CONFIRM_RC_YES}" || "${rc}" -eq "${CONFIRM_RC_YES_ALL}" ]]
}

function __wt::category_default_path() {
    local category="${1}"
    echo "$(git::worktree_root)/${category}/${category}"
}

# Displays the path to archive a worktree's session history to, or nothing (w/ a
# warning) when its category has no default worktree to archive into.
function __wt::archive_destination() {
    local rel="${1}"
    local category="${rel%%/*}"

    local path ; path="$(__wt::category_default_path "${category}")"

    if [[ ! -d "${path}" ]]; then
        ulogger warn "category '${category}' has no default worktree; leaving session history where it is" >&2
        return 0
    fi

    echo "${path}"
}

function __wt::archive_history() {
    local path="${1}" ; shift
    local dest="${1}" ; shift

    "${BASH_TOOLS}/tools/claude/cld-archive" -s "${path}" -d "${dest}" "$@"
}

function __wt::display_removal_plan() {
    local rel="${1}"
    local path="${2}"
    local dest="${3}"
    local dry_run="${4}"
    local keep_window="${5}"
    local branch="${6}"
    local keep_branch="${7}"

    local verb="removing"
    [[ -n "${dry_run}" ]] && verb="would remove"

    printf '%s worktree %s\n' "${verb}" "${rel}"

    if [[ -n "${keep_window}" ]]; then
        printf 'leaving tmux window "%s" in place\n' "$(window::name "${rel}")"
    else
        printf 'killing tmux window "%s"\n' "$(window::name "${rel}")"
    fi

    # a detached worktree holds no branch, so it has none to report
    if [[ -n "${branch}" ]]; then
        if [[ -n "${keep_branch}" ]]; then
            printf 'leaving branch "%s" in place\n' "${branch}"
        else
            printf 'deleting branch "%s"\n' "${branch}"
        fi
    fi

    # the archive plan goes last: it's the only multi-line part, and it's what
    # this returns on
    if [[ -z "${dest}" ]]; then
        printf 'leaving session history in place\n'
        return 0
    fi

    __wt::archive_history "${path}" "${dest}" -n
}

# Folds the long flags into their short forms, writing the result to the array
# named for it: getopts owns the short flags, bundling and all, but can't parse
# the long forms itself.
function __wt::fold_long_flags() {
    local -n __wt_argv_out="${1}" ; shift

    local arg
    for arg in "$@"; do
        case "${arg}" in
          --keep-window) __wt_argv_out+=(-w) ;;
          --keep-branch) __wt_argv_out+=(-b) ;;
          *) __wt_argv_out+=("${arg}") ;;
        esac
    done
}

# Fails, w/ an error, when the worktree is the main one or its category's default.
function __wt::ensure_removable() {
    local rel="${1}"
    local main_rel="${2}"

    if [[ "${rel}" == "${main_rel}" ]]; then
        ulogger error "refusing to remove the main worktree"
        return 1
    fi

    if window::is_category_default "${rel}"; then
        ulogger error "refusing to remove '${rel}': it's the default worktree for the '${rel%%/*}' category"
        return 1
    fi
}

# Fails, w/ an error, when the worktree has uncommitted changes and -f wasn't given.
function __wt::ensure_clean() {
    local rel="${1}"
    local path="${2}"
    local force="${3}"

    if [[ -z "${force}" ]] && ! git::is_clean "${path}"; then
        ulogger error "worktree '${rel}' has uncommitted changes; pass -f to remove it anyway"
        return 1
    fi
}

function __wt::remove_worktree() {
    local path="${1}"
    local force="${2}"

    # -a: the worktree's files are deleted in the background, so the removal
    # doesn't sit on an unlink per file -- which, for a worktree carrying its
    # installed deps, is nearly all of the time this used to take
    local args=(-a)
    [[ -n "${force}" ]] && args+=(-f)

    git::remove_worktree "${path}" "${args[@]}"
}

# Deletes the branch a removed worktree held, unless it had none or it's being
# kept, and reports how the removal went.
function __wt::delete_removed_branch() {
    local rel="${1}"
    local branch="${2}"
    local force="${3}"
    local keep_branch="${4}"

    if [[ -z "${branch}" || -n "${keep_branch}" ]]; then
        ulogger info "removed worktree '${rel}'${branch:+; its branch was left in place}"
        return 0
    fi

    local args=()
    [[ -n "${force}" ]] && args=(-f)

    # the worktree is already gone, so a branch that won't delete is reported
    # rather than failed over -- git says why, and nothing was lost
    if git::delete_branch "${branch}" ${args[@]+"${args[@]}"}; then
        ulogger info "removed worktree '${rel}' and deleted its branch '${branch}'"
    else
        ulogger warn "removed worktree '${rel}', but kept its branch '${branch}'; pass -f to delete it anyway"
    fi
}

## command #####################################################################

function wt::remove() {
    local force=""
    local dry_run=""
    local keep_history=""
    local keep_window=""
    local keep_branch=""

    local argv=()
    __wt::fold_long_flags argv "$@"
    set -- ${argv[@]+"${argv[@]}"}

    local OPTIND=1
    while getopts "fnkwb" opt; do
      case $opt in
        f) force="true" ;;
        n) dry_run="true" ;;
        k) keep_history="true" ;;
        w) keep_window="true" ;;
        b) keep_branch="true" ;;
        \?) ulogger error "valid flags are -fnkwb" >&2 ; return 1 ;;
      esac
    done
    shift $((OPTIND - 1))

    local rel="${1:-}"
    local main_rel ; main_rel="$(git::worktree_rel "$(git::root)")"

    [[ -n "${rel}" ]] || rel="$(__wt::select "remove" "${main_rel}")"
    [[ -n "${rel}" ]] || return 0

    __wt::ensure_removable "${rel}" "${main_rel}" || return 1

    local path ; path="$(__wt::resolve "${rel}")" || return 1

    __wt::ensure_clean "${rel}" "${path}" "${force}" || return 1

    local dest=""
    [[ -n "${keep_history}" ]] || dest="$(__wt::archive_destination "${rel}")"

    # read while the worktree is still there to read it from: a removed worktree
    # is out of the listing, and its branch w/ it. Empty when it's detached.
    local branch ; branch="$(git::worktree_branch "${path}")"

    __wt::display_removal_plan \
        "${rel}" "${path}" "${dest}" "${dry_run}" "${keep_window}" "${branch}" "${keep_branch}"
    [[ -n "${dry_run}" ]] && return 0

    __wt::confirmed "remove worktree '${rel}'?" || return 0

    # the window goes first: a Claude session still running in the worktree
    # recreates its transcript the moment the archive moves it away, so its
    # history can't be archived whole while it's alive
    [[ -n "${keep_window}" ]] || window::kill "$(window::name "${rel}")"

    # archived before the worktree goes: a failure here leaves both the worktree
    # and its history intact
    if [[ -n "${dest}" ]]; then
        __wt::archive_history "${path}" "${dest}" || return 1
    fi

    __wt::remove_worktree "${path}" "${force}" || return 1

    # the branch goes after the worktree: git won't delete one that's checked out
    __wt::delete_removed_branch "${rel}" "${branch}" "${force}" "${keep_branch}"
}
