#!/usr/bin/env bash

export VALIDATE_USE_ULOGGER=""
source "${LOCAL_LIB}/bash/args/check.sh"
source "${LOCAL_LIB}/bash/args/validate.sh"
source "${LOCAL_LIB}/bash/utils.sh"


declare -A SEVERITIES=(
    [0]=TRACE
    [1]=DEBUG
    [2]=INFO
    [3]=WARN
    [4]=ERROR
    [5]=OFF
)
declare -A LOG_LEVELS=(
    [TRACE]=0
    [DEBUG]=1
    [INFO]=2
    [WARN]=3
    [ERROR]=4
    [OFF]=5
)
declare -A PUBLIC_LOG_LEVELS=(
    [TRACE]=0
    [DEBUG]=1
    [INFO]=2
    [WARN]=3
    [ERROR]=4
)

LOG_LEVEL_DEFAULT="WARN"

export SEVERITIES
export LOG_LEVELS
export PUBLIC_LOG_LEVELS
export LOG_LEVEL_DEFAULT

#######################################
# Check if the provided value is a log level.
# Arguments:
#   level: the value to check
# Returns:
#   0 if the provided value is a log level
#   1 otherwise
#######################################
function LogLevel::is() {
    local -r level="$(to_upper "${1}")"
    is_one_of "${level}" "${!LOG_LEVELS[@]}" || return 1
}

#######################################
# Validates that the provided value is a log level.
# Arguments:
#   level: the value to check
# Outputs:
#   Validation error messages to stdout, depending on log config/the VALIDATE_USE_ULOGGER env var
# Returns:
#   0 if the provided value is a log level
#   1 otherwise
#######################################
function LogLevel::validate() {
    local -r level="$(to_upper "${1}")"
    validate_one_of "level" "${level}" "${!LOG_LEVELS[@]}" || return 1
}

#######################################
# Checks if the provided value is a public log level.
# Arguments:
#   level: the value to check
# Returns:
#   0 if the provided value is a public log level
#   1 otherwise
#   2 if the provided value isn't any log level
#######################################
function LogLevel::is_public() {
    local -r level="$(to_upper "${1}")"

    LogLevel::is "${level}" || return 2
    is_one_of "${level}" "${!PUBLIC_LOG_LEVELS[@]}" || return 1
}

#######################################
# Validates that the provided value is a public log level.
# Arguments:
#   level: the value to check
# Outputs:
#   Validation error messages to stdout, depending on log config/the VALIDATE_USE_ULOGGER env var
# Returns:
#   0 if the provided value is a public log level
#   1 otherwise
#   2 if the provided value isn't any log level
#######################################
function LogLevel::validate_public() {
    local -r level="$(to_upper "${1}")"

    LogLevel::validate "${level}" || return 2
    validate_one_of "level" "${level}" "${!PUBLIC_LOG_LEVELS[@]}" || return 1
}

#######################################
# Check if the provided value is a severity.
# Arguments:
#   severity: the value to check
# Returns:
#   0 if the provided value is a severity
#   1 otherwise
#######################################
function LogLevel::is_severity() {
    local -r severity=$1
    is_one_of "${severity}" "${!SEVERITIES[@]}" || return 1
}

#######################################
# Validates that the provided value is a severity.
# Arguments:
#   severity: the value to check
# Outputs:
#   Validation error messages to stdout, depending on log config/the VALIDATE_USE_ULOGGER env var
# Returns:
#   0 if the provided value is a severity
#   1 otherwise
#######################################
function LogLevel::validate_severity() {
    local -r severity=$1
    validate_one_of "level" "${severity}" "${!SEVERITIES[@]}" || return 1
}

#######################################
# Converts the provided log level to the corresponding severity.
# Arguments:
#   level: the log level to convert
# Outputs:
#   Prints to stdout the severity that corresponds to the provided log level
#   Validation error messages to stdout, depending on log config/the VALIDATE_USE_ULOGGER env var
# Returns:
#   1 if the provided value isn't a public log level
#######################################
function LogLevel::to_severity() {
    local -r level="$(to_upper "${1}")"

    LogLevel::validate "${level}" || return 1

    local severity="${LOG_LEVELS[${level}]}"

    [[ -z "${severity}" ]] && return 1
    echo "${severity}"
}

#######################################
# Converts the provided severity to the corresponding log level.
# Arguments:
#   level: the severity to convert
# Outputs:
#   Prints to stdout the log level that corresponds to the provided severity
#   Validation error messages to stdout, depending on log config/the VALIDATE_USE_ULOGGER env var
# Returns:
#   1 if the provided value isn't a severity
#######################################
function LogLevel::to_level() {
    local severity="${1}"

    LogLevel::validate_severity "${severity}" || return 1

    local level="${SEVERITIES[${severity}]}"

    [[ -z "${level}" ]] && return 1
    echo "${level}"
}

#######################################
# Wraps LogLevel::to_severity and LogLevel::to_level: if the provided value is a level, converts it to the corresponding severity and vice-versa.
# Arguments:
#   value: the log level/severity to convert
# Outputs:
#   Prints to stdout the converted log level/severity
#   Validation error messages to stdout, depending on log config/the VALIDATE_USE_ULOGGER env var
# Returns:
#   1 if the provided value isn't a value log level/severity
#######################################
function LogLevel::convert() {
    local value="${1}"

    if LogLevel::is_public "${value}"; then
        LogLevel::to_severity "${value}" || return 1
    elif LogLevel::is_severity "${value}"; then
        LogLevel::to_level "${value}" || return 1
    else
        echo "[ERROR] unrecognized log level/severity: ${value}"
        return 1
    fi
}

#######################################
# Checks if a log level is of a severity sufficient to warrant logging to stdout.
# A log level warrants stdout logging if its severity is >= the severity of the "current" log level, this function's second argument.
# Arguments:
#   log_level: the log level to check
#   current_level: the log level against which to check
# Outputs:
#   Validation error messages to stdout, depending on log config/the VALIDATE_USE_ULOGGER env var
# Returns:
#   0 if log_level is of a severity sufficient to warrant logging to stdout
#   1 otherwise
#   2 if either of the provided log levels are invalid or log_level isn't public
#######################################
function LogLevel::should_log() {
   local log_level="${1}"
   local current_level="${2}"

   LogLevel::validate_public "${log_level}"

   local -r severity="$(LogLevel::to_severity "${log_level}")" || return 2
   local -r current_severity="$(LogLevel::to_severity "${current_level}")" || return 2

    [[ ${severity} -ge ${current_severity} ]] && return 0 || return 1
}

