#!/usr/bin/env bash

source "${BASH_LIB}/args/validate.sh"


# Config is keyed by *category*: the directory a worktree lives in beneath the
# worktree root (see: git::worktree_category). The main worktree, which has no
# category directory, is its own category (i.e.: the repo name).

__GIT_CONFIG_FILE="${XDG_CONFIG_HOME}/git/config.toml"
__GIT_REPO_NAME=""

declare -A __GIT_INDICATOR_BY_CATEGORY         # category -> indicator
declare -A __GIT_COLOR_BY_CATEGORY             # category -> color code
declare -A __GIT_ICON_BY_CATEGORY              # category -> window title icon
declare -A __GIT_DEFAULT_BY_CATEGORY           # category -> default branch name
declare -A __GIT_DEFAULT_BRANCHES              # set of configured default branch names
declare -A __GIT_SYNC_EXCLUDED_CATEGORIES      # set of categories excluded from sync
declare -A __GIT_HIDDEN_CATEGORIES             # set of categories hidden from checkout

__GIT_CONFIG_LOADED=""


function __config::init() {
    [[ -n "${__GIT_CONFIG_LOADED}" ]] && return 0
    __GIT_REPO_NAME="$(git::repo_name)"
    __GIT_CONFIG_LOADED="true"

    [[ -f "${__GIT_CONFIG_FILE}" ]] || return 0

    local section key value category
    local selector=".\"${__GIT_REPO_NAME}\" // {}"
    selector+=' | to_entries | .[] | .key as $section'
    selector+=' | .value | to_entries | .[]'
    selector+=' | [$section, .key, (.value | tostring)] | @tsv'

    while IFS=$'\t' read -r section key value; do
        case "${section}" in
            indicator) __GIT_INDICATOR_BY_CATEGORY["${key}"]="${value}" ;;
            color)     __GIT_COLOR_BY_CATEGORY["${key}"]="${value}" ;;
            icon)      __GIT_ICON_BY_CATEGORY["${key}"]="${value}" ;;
            default)
                __GIT_DEFAULT_BY_CATEGORY["${key}"]="${value}"
                __GIT_DEFAULT_BRANCHES["${value}"]="true"
                ;;
        esac
    done < <(yq -p toml -r "${selector}" "${__GIT_CONFIG_FILE}" 2>/dev/null)

    local exclude_selector=".\"${__GIT_REPO_NAME}\".sync.exclude // [] | .[]"
    while IFS= read -r category; do
        [[ -z "${category}" ]] && continue
        __GIT_SYNC_EXCLUDED_CATEGORIES["${category}"]="true"
    done < <(yq -p toml -r "${exclude_selector}" "${__GIT_CONFIG_FILE}" 2>/dev/null)

    local hide_selector=".\"${__GIT_REPO_NAME}\".hide // [] | .[]"
    while IFS= read -r category; do
        [[ -z "${category}" ]] && continue
        __GIT_HIDDEN_CATEGORIES["${category}"]="true"
    done < <(yq -p toml -r "${hide_selector}" "${__GIT_CONFIG_FILE}" 2>/dev/null)
}

function config::file() {
    echo "${__GIT_CONFIG_FILE}"
}

function config::repo_name() {
    __config::init
    echo "${__GIT_REPO_NAME}"
}

function config::indicator_for() {
    __config::init
    echo "${__GIT_INDICATOR_BY_CATEGORY[${1}]:-}"
}

function config::has_indicator() {
    __config::init
    [[ -n "${__GIT_INDICATOR_BY_CATEGORY[${1}]+x}" ]]
}

function config::set_indicator() {
    __config::init
    __GIT_INDICATOR_BY_CATEGORY["${1}"]="${2}"
}

function config::is_indicator_used() {
    __config::init
    local target="${1}"
    local ind

    for ind in "${__GIT_INDICATOR_BY_CATEGORY[@]}"; do
        [[ "${ind}" = "${target}" ]] && return 0
    done

    return 1
}

function config::color_for() {
    __config::init
    echo "${__GIT_COLOR_BY_CATEGORY[${1}]:-}"
}

function config::icon_for() {
    __config::init
    echo "${__GIT_ICON_BY_CATEGORY[${1}]:-}"
}

# Unlike an indicator, an icon configured as "" counts as absent: a blank window
# title is never what's wanted, so an empty icon falls back to the category name.
function config::has_icon() {
    __config::init
    [[ -n "${__GIT_ICON_BY_CATEGORY[${1}]:-}" ]]
}

function config::default_for() {
    __config::init

    local value="${__GIT_DEFAULT_BY_CATEGORY[${1}]:-}"
    [[ -z "${value}" ]] && return 1

    echo "${value}"
}

function config::is_default_branch() {
    __config::init
    [[ -n "${__GIT_DEFAULT_BRANCHES[${1}]+x}" ]]
}

function config::is_sync_excluded_category() {
    __config::init
    [[ -n "${__GIT_SYNC_EXCLUDED_CATEGORIES[${1}]+x}" ]]
}

function config::is_hidden_category() {
    __config::init
    [[ -n "${__GIT_HIDDEN_CATEGORIES[${1}]+x}" ]]
}
