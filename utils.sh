#!/usr/bin/env bash


source /etc/profile.d/shared_paths.sh
source "${CODE_ROOT}"/lib/bash/args.sh


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
#   0 if the user selects "y" (yes), 1 otherwise
#######################################
function yes_or_no() {
    local prompt="${1:-Are you sure?}"
    local full_prompt="${prompt} [y/N] "

    read -p "${full_prompt}" -n 1 -r

    [[ $REPLY =~ ^[y]$ ]] && return 0 || return 1
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
# Checks if the provided function exists.
# Arguments:
#   fn_name: name of the function to check
# Returns:
#   0 if the function exists, 1 otherwise
#   2 if function arguments aren't valid
#######################################
function fn_exists() {
    validate_num_args 1 $# "fn_exists" || return 2

    local fn_name="${1}"
    [[ $(type -t "${fn_name}") == function ]] && return 0 || return 1
}

