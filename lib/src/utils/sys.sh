#!/usr/bin/env bash

source "${LOCAL_LIB}/bash/log/stub.sh"


#######################################
# Gets the current "os-type", i.e.: linux, darwin, etc.
# Outputs:
#   Writes the current "os-type" to stdout
#######################################
function sys::os_type() {
    uname | tr '[:upper:]' '[:lower:]'
}

#######################################
# Checks if the current system is linux based.
# Returns:
#   0 if the current system is linux based, 1 otherwise
#######################################
function sys::is_linux() {
    [[ "$(sys::os_type)" == "linux" ]] || return 1
}

#######################################
# Checks if the current system is darwin based.
# Returns:
#   0 if the current system is darwin based, 1 otherwise
#######################################
function sys::is_darwin() {
    [[ "$(sys::os_type)" == "darwin" ]] || return 1
}

#######################################
# Gets the current architecture, i.e.: arm64, amd64, etc.
# Outputs:
#   Writes the current architecture to stdout
#######################################
function sys::arch() {
    uname -m
}

#######################################
# Gets the current host's name.
# Outputs:
#   Write the current host's name to stdout
#######################################
function sys::hostname() {
    hostname -s
}

#######################################
# Gets the current user's username.
# Globals:
#   USERNAME
# Outputs:
#   Write the current user's username to stdout
# Returns:
#   1 if an unexpected error is encountered
#   2 if the current os-type is unrecognized
#######################################
function sys::username() {
    if sys::is_linux; then
        echo "${USERNAME}" && return 0
    elif sys::is_darwin; then
        whoami && return 0 || return 1
    else
        StubLogger::log error "unrecognized os-type: "
        return 2
    fi
}

