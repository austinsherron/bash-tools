#!/usr/bin/env bash

source /etc/profile.d/shared_paths.sh
source "${BASH_LIB}/args/validate.sh"


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
# Deprecated: use str::upper
# TODO: replace uses of this function w/ str::upper
#######################################
function to_upper() {
    validate_num_args 1 $# "to_upper" || return 1

    local str="${1}"
    echo "${str}" |  tr '[:lower:]' '[:upper:]'
}

#######################################
# Deprecated: use sys::os_type
# TODO: replace uses of this function w/ sys::os_type
#######################################
function os-type() {
    uname | tr '[:upper:]' '[:lower:]'
}

