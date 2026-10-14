#!/usr/bin/env bash


# The "worktree new" command; sourced by main.sh.

BRANCH_PREFIX="austin"

## help ########################################################################

function wt::help::new() {
cat <<help
DESCRIPTION

    Creates a worktree in a category and opens a window for it, as if by [open]
    but w/ all three panes rooted in the worktree itself.

    The worktree is created at "<worktree root>/<category>/<name>" on the branch
    "${BRANCH_PREFIX}/<name>[-<suffix>]", which is created from -s|<start-point> if it
    doesn't exist yet and checked out as-is if it does. The suffix is optional:
    w/o one the branch is just "${BRANCH_PREFIX}/<name>", w/ no trailing separator.

    The repo's own tooling provisions the worktree -- "mb setup worktree-link"
    -- so it comes w/ the symlinked config, the frontend deps and the generated
    API clients that a usable worktree needs. That step installs deps and runs
    codegen, so it takes a while.

    The category, the name and the suffix are prompted for when they're not
    given: the category w/ fzf, which accepts a typed-in category that doesn't
    exist yet.

USAGE

    ${WT_USAGE[new]}

ALIASES

    $(aliases_for WT_ALIASES new)

POSITIONAL ARGUMENTS

    NAME            optional, prompted for otherwise; the work item name, which
                    names both the worktree and its branch

OPTIONS

    -c              optional, prompted for otherwise; the category to create the
                    worktree in
    -x              optional, prompted for otherwise; the branch name's suffix
    -s              optional, defaults to "master"; the start point to create
                    the branch from

FLAGS

    -h, --help      display this message
help
}

## helpers #####################################################################

# Selects a category w/ fzf, accepting a typed-in category that doesn't exist yet.
function __wt::select_category() {
    git::list_categories | fzf --ansi --print-query --prompt='category> ' | tail -1
}

# Prompts for whichever of the category, the name and the branch suffix weren't
# given, writing each back to the variable named for it. Fails when the category
# or the name is still empty afterward; the suffix is optional.
function __wt::prompt_new_inputs() {
    local -n __wt_category_out="${1}"
    local -n __wt_name_out="${2}"
    local -n __wt_sfx_out="${3}"

    [[ -n "${__wt_category_out}" ]] || __wt_category_out="$(__wt::select_category)"
    validate_required "-c <category>" "${__wt_category_out}" || return 1

    [[ -n "${__wt_name_out}" ]] || __wt_name_out="$(input::text "worktree name:")"
    validate_required "<name>" "${__wt_name_out}" || return 1

    [[ -n "${__wt_sfx_out}" ]] || __wt_sfx_out="$(input::text "branch suffix (optional):")"
}

# Displays the branch for a work item: "<prefix>/<name>[-<suffix>]". W/o a suffix
# it's just "<prefix>/<name>", w/ no trailing separator.
function __wt::branch_name() {
    local name="${1}"
    local sfx="${2}"

    echo "${BRANCH_PREFIX}/${name}${sfx:+-${sfx}}"
}

# Fails, w/ an error, when something already exists at the worktree's path.
function __wt::ensure_absent() {
    local rel="${1}"
    local path="${2}"

    if [[ -e "${path}" ]]; then
        ulogger error "'${rel}' already exists"
        return 1
    fi
}

# Creates a branch from a start point, unless it already exists, in which case
# it's left as-is to be checked out.
function __wt::ensure_branch() {
    local branch="${1}"
    local start="${2}"
    local rel="${3}"

    if git::branch_exists "${branch}"; then
        ulogger info "checking out existing branch '${branch}' in '${rel}'"
        return 0
    fi

    ulogger info "creating branch '${branch}' from '${start}' in '${rel}'"

    # the branch is created ahead of the worktree, which is added on a branch it's
    # given and creates none of its own
    git::create_branch "${branch}" "${start}"
}

# Creates a worktree at a path, on an existing branch, then provisions it w/ the
# repo's own tooling: "mb setup worktree-link" symlinks the config the backend
# needs, installs the frontend deps and generates the API clients.
#
# The worktree is added here rather than by "mb setup worktree", which takes a
# single directory name and creates the worktree beside the canonical checkout:
# it has no way to express the "<category>/<item>" layout. "mb setup
# worktree-link" reads the worktree it acts on from its cwd, so it's run from
# the new worktree itself.
function __wt::create_worktree() {
    local path="${1}"
    local branch="${2}"

    local root ; root="$(git::root)" || return 1

    (cd "${root}" && git::create_worktree "${path}" "${branch}") || return 1
    (cd "${path}" && mb setup worktree-link) || return 1

    # the add happened in a subshell, so the listing this added to it was the
    # subshell's; the one in this shell is still memoized behind the git module's back
    git::reload_worktrees
}

# Adds a new worktree's directory to zoxide, so it can be jumped to by name. A
# missing zoxide is warned about rather than failed on: the worktree is usable w/out it.
function __wt::add_to_zoxide() {
    local path="${1}"

    if ! command -v zoxide > /dev/null; then
        ulogger warn "zoxide not found; '${path}' not added to it"
        return 0
    fi

    zoxide add "${path}"
}

# Opens a window for a new worktree, w/ all three panes rooted in it.
function __wt::open_new_window() {
    local path="${1}"

    window::use "${path}"

    # a new worktree's work -- the setup that follows, and the tooling that runs
    # across both halves of the repo -- starts at its root, not in the backend
    window::init_worktree "/" "/" "/"
}

## command #####################################################################

function wt::new() {
    local category="" name="" sfx="" start="master"

    local OPTIND=1
    while getopts "c:x:s:" opt; do
      case $opt in
        c) category="${OPTARG}" ;;
        x) sfx="${OPTARG}" ;;
        s) start="${OPTARG}" ;;
        \?) ulogger error "valid flags are -cxs" >&2 ; return 1 ;;
      esac
    done
    shift $((OPTIND - 1))

    name="${1:-}"

    __wt::prompt_new_inputs category name sfx || return 1

    local rel="${category}/${name}"
    local branch ; branch="$(__wt::branch_name "${name}" "${sfx}")"
    local path ; path="$(git::worktree_root)/${rel}"

    __wt::ensure_absent "${rel}" "${path}" || return 1
    __wt::ensure_branch "${branch}" "${start}" "${rel}" || return 1
    __wt::create_worktree "${path}" "${branch}" || return 1
    __wt::add_to_zoxide "${path}"
    __wt::open_new_window "${path}"
}
