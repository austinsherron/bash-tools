#!/usr/bin/env bash

source "${BASH_LIB}/args/validate.sh"


#######################################
# Checks if the provided file exists.
# Arguments:
#   file: the path to check
# Returns:
#   0 if the provided path refers to a valid file
#   1 otherwise
#######################################
function file::exists() {
    file="${1}"
    [[ -f "${file}" ]]
}

alias file::is="file::exists"

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
    validate_optional_file "${path}" "path" || return 1

    [[ -z "${path}" ]] && echo "0" && return 0
    wc -l < "${path}" | xargs
}

#######################################
# Displays the provided file's mime type.
# Arguments:
#   path: the path to the file
# Outputs:
#   Writes to stdout the provided file's mime type
# Returns:
#   1 if function arguments aren't valid
#######################################
function file::mime_type() {
    local path="${1}"
    validate_file "${path}" "path" || return 1

    file --mime-type -b "${path}"
}

#######################################
# Displays the provided file's type, i.e.: first part of its mime type:
#   file::mime_type "path" == "text/plain"
#   file::type "path" == "text"
# Arguments:
#   path: the path to the file
# Outputs:
#   Writes to stdout the provided file's type
# Returns:
#   1 if function arguments aren't valid
#######################################
function file::type() {
    local path="${1}"
    validate_file "${path}" "path" || return 1

    file::mime_type "${path}" | cut -d '/' -f1
}

#######################################
# Checks if the file at the provided path is a text file.
# Arguments:
#   path: the path to the file to check
# Returns:
#   0 if the provided file is a text file
#   1 otherwise
#   2 if function arguments aren't valid
#######################################
function file::is_text() {
    local path="${1}"
    validate_file "${path}" "path" || return 2

    [[ "$(file::type "${path}")" == "text" ]]
}

#######################################
# Creates a path from parts. Filters out empty parts to avoid extra separators.
# Arguments:
#   n path parts to join w/ forward-slash ('/')
# Outputs:
#   Writes to stdout a single path comprised of provided non-empty path parts
#######################################
function file::make_path() {
    local path=""

    [[ $# -ge 1 ]] && path="${1}" ; shift

    while [[ $# -gt 0 ]]; do
        [[ -n "${1}" ]] && path="${path}/${1}" ; shift
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
function file::md5_checksum() {
    validate_num_args 1 $# "file::md5_checksum" || return 2

    local path="${1}"

    validate_file "${path}" || return 2
    md5sum -c --status "${path}"
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

alias dir::is="dir::exists"
