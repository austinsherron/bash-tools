#!/usr/bin/env bash

source "${LOCAL_LIB}/bash/args/validate.sh"


# Checks if the provided file exists.
# Arguments:
#   file: the path to check
# Returns:
#   0 if the provided path refers to a valid file
#   1 otherwise
function file::exists() {
    file="${1}"
    [[ -f "${file}" ]]
}

#######################################
# Reads from stdin and writes to the file at the provided path, or a temporary file if none is provided.
# Arguments:
#   path: optional, defaults to a temporarily file; the path to the file to which to write content from stdin
# Outputs:
#   The path of the file to which stdin was written
#   Validation error messages to stdout, depending on log config/the VALIDATE_USE_ULOGGER env var
# Returns:
#   1 if function arguments aren't valid
#######################################
function file::read() {
    local path="${1:-$(mktemp)}"

    while read -r line; do
      echo "${line}" >> "${path}"
    done < /dev/stdin

    echo "${path}"
}

#######################################
# Writes to stdout the number of lines in the provided file.
# Arguments:
#   path: the file for which to get the number of lines
# Outputs:
#   The number of lines in the provided file
#   Validation error messages to stdout, depending on log config/the VALIDATE_USE_ULOGGER env var
# Returns:
#   1 if function arguments aren't valid
#######################################
function file::num_lines() {
    local path="${1}"
    validate_file "${path}" "path" || return 1

    wc -l < "${path}" | xargs
}

#######################################
# Checks if the provided directory exists.
# Arguments:
#   dir: the path to check
# Returns:
#   0 if the provided path refers to a valid directory
#   1 otherwise
#######################################
function dir::exists() {
    dir="${1}"
    [[ -d "${dir}" ]]
}
