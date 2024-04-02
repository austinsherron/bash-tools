#!/usr/bin/env bash

source "${BASH_TOOLS}/lib/args/validate.sh"


#######################################
# Checks if the provided selector exists in in "file".
# Arguments:
#   file: a path to the yaml/toml file from which to read
#   selector: the yaml/toml selector to check
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if a value exists in "file" at the provided selector, 1 otherwise
#   2 if the provided args are invalid
#######################################
function yaml::exists() {
    validate_num_args 2 $# "yaml::get" || return 2
    validate_file "${1}"

    local file="${1}"
    local selector="${2:-.}"

    local -r value="$(yq "${selector}" "${file}")" || return 1

    if [[ "${value}" != "null" ]]; then
        return 0
    else
        return 1
    fi
}

#######################################
# Reads the value at "selector" from the yaml/toml file at the provided path.
# Arguments:
#   file: a path to the yaml/toml file from which to read
#   selector: optional, defaults to "." (i.e.: root selector); the yaml/toml selector to use
# Outputs:
#   Prints to stdout the value from "file" at "selector", if any
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if the provided args are valid, 1 otherwise, or an error is encountered reading from the file
#######################################
function yaml::get() {
    validate_num_args 2 $# "yaml::get" || return 1
    validate_file "${1}"

    local file="${1}"
    local selector="${2:-.}"

    local -r value="$(yq "${selector}" "${file}")" || return 1

    if [[ "${value}" != "null" ]]; then
        echo "${value}" | xargs
    else
        echo ""
    fi
}

