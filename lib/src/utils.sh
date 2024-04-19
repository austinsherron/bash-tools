#!/usr/bin/env bash

source /etc/profile.d/shared_paths.sh
source "${LOCAL_LIB}/bash/args/validate.sh"


export CONFIRM_RC_YES=0
export CONFIRM_RC_YES_ALL=1
export CONFIRM_RC_NO=2
export CONFIRM_RC_NO_ALL=3

#######################################
# Joins arguments 2-n by first argument.
# Source: https://stackoverflow.com/questions/1527049/how-can-i-join-elements-of-a-bash-array-into-a-delimited-string
# Arguments:
#   sep: optional; string to use to join elements
#   optional; n strings to join w/ sep
# Outputs:
#   Writes joined string to stdout
#######################################
function join_by() {
    local sep=${1-} f=${2-}

    if shift 2; then
        printf %s "$f" "${@/#/$sep}"
    fi
}

#######################################
# Creates a path from parts. Filters out empty parts to avoid extra separators.
# Arguments:
#   n path parts to join w// forward-slash ('/')
# Outputs:
#   Writes to stdout a single path comprised of provided non-empty path parts
#######################################
function make_path() {
    local path=""

    [[ $# -ge 1 ]] && path="${1}" && shift

    while [[ $# -gt 0 ]]; do
        [[ -n "${1}" ]] && path="${path}/${1}"
        shift
    done

    echo "${path}"
}

#######################################
# Checks an md5 checksum file.
# Arguments:
#   path: the path to the checksum file
# Returns:
#   0 if checksum is valid, 1 otherwise (i.e.: on validation failure or if md5sum isn't formatted properly)
#   2 if function arguments aren't valid
#######################################
function md5_checksum() {
    validate_num_args 1 $# "md5_checksum" || return 2

    local path="${1}"

    validate_file "${path}" || return 2
    md5sum -c --status "${path}"
}

#######################################
# Converts a string to lowercase.
# Arguments:
#   str: the string to convert
# Outputs:
#   Writes the lower-case string to stdout
# Returns:
#   0 if checksum is valid, 1 otherwise (i.e.: on validation failure or if md5sum isn't formatted properly)
#   2 if function arguments aren't valid
#######################################
function to_lower() {
    validate_num_args 1 $# "to_lower" || return 2

    local str="${1}"
    echo "${str}" |  tr '[:upper:]' '[:lower:]'
}

#######################################
# Converts a string to uppercase.
# Arguments:
#   str: the string to convert
# Outputs:
#   Writes the upper-case string to stdout
# Returns:
#   1 if function arguments aren't valid
#######################################
function to_upper() {
    validate_num_args 1 $# "to_upper" || return 1

    local str="${1}"
    echo "${str}" |  tr '[:lower:]' '[:upper:]'
}

#######################################
# Checks if a string ends w/ a suffix.
# Arguments:
#   str: the string to check
#   sfx: the suffix to check
# Returns:
#   0 if the string ends w/ sfx, 1 otherwise
#   2 if function arguments aren't valid
#######################################
function endswith() {
    validate_num_args 2 $# "endswith" || return 2

    local str="${1}"
    local sfx="${2}"

    [[ "${str}" == *"${sfx}" ]] && return 0 || return 1
}

#######################################
# A "yes or no" prompt for stdout.
# Arguments:
#   prompt: optional, defaults to "Are you sure?"; the prompt string
# Returns:
#   0 if the user selects "y" (yes)
#   1 if the user selects "Y" (yes to all)
#   2 if the user selects "n" (no)
#   3 if the user selects "N" (no to all)
#######################################
function yes_or_no() {
    local prompt="${1:-Are you sure?}"
    local full_prompt="${prompt} [y/n/Y/N] "

    read -p "${full_prompt}" -n 1 -r
    local rc=1

    [[ $REPLY =~ ^[y]$ ]] && rc=$CONFIRM_RC_YES
    [[ $REPLY =~ ^[Y]$ ]] && rc=$CONFIRM_RC_YES_ALL
    [[ $REPLY =~ ^[n]$ ]] && rc=$CONFIRM_RC_NO
    [[ $REPLY =~ ^[N]$ ]] && rc=$CONFIRM_RC_NO_ALL

    echo
    return $rc
}

#######################################
# Gets the current OS type, i.e.: (linux, darwin, etc.)
# Outputs:
#   Writes the current OS type to stdout
#######################################
function os-type() {
    uname | tr '[:upper:]' '[:lower:]'
}

#######################################
# Checks if the current system is linux based.
# Returns:
#   0 if the current system is linux based, 1 otherwise
#######################################
function is_linux() {
    [[ "$(os-type)" == "linux" ]] || return 1
}

#######################################
# Checks if the current system is darwin based.
# Returns:
#   0 if the current system is darwin based, 1 otherwise
#######################################
function is_darwin() {
    [[ "$(os-type)" == "darwin" ]] || return 1
}

