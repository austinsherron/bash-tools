#!/usr/bin/env bash
# shellcheck disable=SC1102

source /etc/profile.d/shared_paths.sh
source "${BASH_TOOLS}/lib/args/check.sh"


[[ -z "${VALIDATE_USE_ULOGGER+x}" ]] && VALIDATE_USE_ULOGGER="true"

__log_error() {
    local msg="${1}"

    if [[ -z "${VALIDATE_USE_ULOGGER}" ]] || ! check_installed ulogger; then
        echo "[ERROR] ${msg}"
    else
        ulogger error "${msg}"
    fi
}

#######################################
# Validates that variable w/ name is non-empty.
# Arguments:
#   name: the name of the variable to validate
#   val: the value to validate
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if val is non-empty, 1 otherwise
#######################################
function validate_required() {
    local name="${1}"
    local val="${2}"
    local msg="${3:-}"

    [[ -z "${msg}" ]] && msg="${name} is a required param"

    if [[ -z "${val}" ]]; then
        __log_error "${msg}"
        return 1
    fi
}

#######################################
# Validates that positional variable w/ name is non-empty.
# Arguments:
#   desc: the description of the variable to validate
#   val: the value to validate
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if val is non-empty, 1 otherwise
#######################################
function validate_required_positional() {
    local desc="${1}"
    local val="${2}"

    if [[ -z "${val}" ]]; then
        __log_error "${desc} is a required positional param"
        return 1
    fi
}

#######################################
# Validates that an array is non-empty.
# Arguments:
#   name: the name of the variable to validate
#   the contents of the array to validate
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if is array is non-empty, 1 otherwise
#######################################
function validate_required_array() {
    local name="${1}" ; shift

    if [[ $# -lt 1 ]]; then
        __log_error "${name} is a required"
        return 1
    fi
}

#######################################
# Validates that at least one of provided variables is empty.
# Arguments:
#   l: one of the variables to validate
#   lname: the name of the previous variable
#   r: the other variable to validate
#   rname: the name of the previous variable
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if at least one of provided variables is empty, 1 otherwise
#######################################
function validate_mutually_exclusive() {
    local l="${1}"
    local lname="${2}"

    local r="${3}"
    local rname="${4}"

    if [[ -n "${l}" ]] && [[ -n "${r}" ]]; then
        __log_error "${lname} and ${rname} are mutually exclusive"
        return 1
    fi
}

#######################################
# Validates that at least one provided variable is non-empty.
# Arguments:
#   n "name" "value" pairs, i.e.:
#       validate_at_least_one "-1|--one" "${ONE}" "-2|--two" "${TWO}"
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if at least one value is non-empty, 1 otherwise
#######################################
function validate_at_least_one() {
    if [[ $(($# % 2)) -ne 0 ]]; then
        __log_error "validate_one_required takes N pairs: the args to validate and their names/flags"
        return 2
    fi

    local names=()

    while [[ $# -gt 0 ]]; do
        [[ -n "${1}" ]] && return 0
        names+=("${2}")

        shift
        shift
    done

    local names_str
    names_str="$(echo "${names[@]}" | tr ' ' ', ')"

    __log_error "one of ${names_str} is required"
}

#######################################
# Validates that a value is one of a constrained set of values.
# Arguments:
#   name: the name of the variable to validate
#   val: the value to validate
#   the set of values of which val must be a member to be considered valid
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if the provided value is a member of the set of valid values, 1 otherwise
#######################################
function validate_one_of() {
    local name="${1}" ; shift
    local val="${1}";  shift

    is_one_of "${val}" "$@" && return 0

    local -r valid_vals_str="$(echo "$@" | tr " " "|")"
    __log_error "${name} must be one of '${valid_vals_str}', not '${val}'"
    return 1
}

#######################################
# If a value is non-empty, validates that it is one of a constrained set of values.
# Arguments:
#   name: the name of the variable to validate
#   val: the value to validate
#   the set of values of which val must be a member to be considered valid
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if the provided value is empty or is a member of the set of valid values, 1 otherwise
#######################################
function validate_one_of_optional() {
    local name="${1}" ; shift
    local val="${1}";  shift

    if [[ -n "${val}" ]]; then
        validate_one_of "${name}" "${val}" "$@" || return 1
    fi
}

#######################################
# Validates the (line) length of the provided string. Useful when a sub-command is expected to return "n" lines.
# Arguments:
#   lines: the string to validate
#   len: the required line length of lines
#   desc: optional, defaults to lines; a description of the variable being validated (for use in error messages)
#   msg: optional; the error message to use
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if the number of lines in the provided value == len, 1 otherwise
#######################################
function validate_output_len() {
    local lines="${1}"
    local len="${2}"
    local desc="${3:-${lines}}"
    local msg="${4:-${lines} must be len == ${len}}"

    readarray -t split < <(echo "${lines}")

    if [[ "${#split[@]}" -ne $len ]]; then
        __log_error "${msg}"
        return 1
    fi
}

#######################################
# Validates that nreq == nactual.
# Arguments:
#   nreq: the number against which to validate
#   nactual: the number to validate
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if nreq == nactual, 1 otherwise
#######################################
function validate_num_args() {
    local nreq=$1
    local nactual=$2
    local caller="${3:-function}"
    local arg="argument"

    [[ $nactual -eq $nreq ]] && return 0
    [[ $nreq -gt 1 ]] && arg="arguments"

    __log_error "${caller} requires exactly $nreq ${arg} but got $nactual"
    return 1
}

#######################################
# Validates that nactual is >/>= min.
# Arguments:
#   min: the valid minimum number of arguments
#   nactual: the actual number of arguments
#   caller: the name of the caller
#   exclusive: optional; if true, nactual must be strictly > min to be valid
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if nactual > min (if exclusive == true) or >= min, 1 otherwise
#######################################
function validate_min_args() {
    local min=$1
    local nactual=$2
    local caller="${3}"
    local exclusive="${4:-}"
    local -r sign="$([[ -z "${exclusive}" ]] && echo ">=" || echo ">")"

    if [[ -z "${exclusive}" ]] && [[ $nactual -ge $min ]]; then
        return 0
    elif [[ "${exclusive}" == "true" ]] && [[ $nactual -gt $min ]]; then
        return 0
    fi

    local -r arg="$([[ $min -gt 1 ]] && echo "arguments" || echo "argument")"
    __log_error "${caller} requires ${sign} $min ${arg} but got $nactual"
    return 1
}

#######################################
# Validates that the provided value conforms to the provided cond.
# Arguments:
#   name: the name of the value to validate
#   num: the value to validate
#   cond: a condition, in the format "operator value", i.e. "> 4", "<= -1", to which num must conform
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if num conforms to the provided cond, 1 otherwise
#######################################
function validate_num() {
    local name="${1}" ; local num=$2 ; local cond="${3}"

    if [[ "$(($num "${cond}"))" -eq 0 ]]; then
        __log_error "${name} (${num}) must be ${cond}"
        return 1
    fi
}

#######################################
# Validates that the provided value conforms to the provided range conditions.
# Arguments:
#   name: the name of the value to validate
#   num: the value to validate
#   lrange: lower bound range condition, in the format "operator value", i.e. "> 4", "<= -1", to which num must conform
#   hrange: a condition, in the format "operator value", i.e. "> 4", "<= -1", to which num must conform
#   urange: upper bound range condition, in the format "operator value", i.e. "> 4", "<= -1", to which num must conform
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if num conforms to the provided cond, 1 otherwise
#######################################
function validate_range() {
    local name="${1}" ; local num=$2 ; local lrange="${3}" ; local urange="${4}"

    if [[ "$(($num "${lrange}"))" -eq 0 ]]; then
        __log_error "${name} (${num}) must be ${lrange}"
        return 1
    fi

    if [[ "$(($num "${urange}"))" -eq 0 ]]; then
        __log_error "${name} (${num}) must be ${lrange} and ${urange}"
        return 1
    fi
}

#######################################
# Validates that nactual is </<= max.
# Arguments:
#   max: the valid maximum number of arguments
#   nactual: the actual number of arguments
#   caller: the name of the caller
#   exclusive: optional; if true, nactual must be strictly < max to be valid
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if nactual < min (if exclusive == true) or <= min, 1 otherwise
#######################################
function validate_max_args() {
    local max=$1
    local nactual=$2
    local caller="${3}"
    local exclusive="${4:-}"
    local sign="" && [[ -z "${exclusive}" ]] && sign="<="
    local -r sign="$([[ -z "${exclusive}" ]] && echo "<=" || echo "<")"

    if [[ -z "${exclusive}" ]] && [[ $nactual -le $max ]];
        then return 0
    elif [[ "${exclusive}" == "true" ]] && [[ $nactual -lt $max ]];
        then return 0
    fi

    local -r arg="$([[ $max -gt 1 ]] && echo "arguments" || echo "argument")"
    __log_error "${caller} requires ${sign} $max ${arg} but got $nactual"
    return 1
}

#######################################
# Validates that a path references a valid, non-empty file.
# Arguments:
#   path: the path to validate
#   name: the name of the variable to validate
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if the provided path references a valid, non-empty file, 1 otherwise
#######################################
function validate_file() {
    local path="${1}"
    local name="${2:-${path}}"

    if [[ ! -s "${path}" ]]; then
        __log_error "${name} must refer to a valid file"
        return 1
    fi
}

#######################################
# Validates that a path references a valid, non-empty file if it's reference is non-empty.
# Arguments:
#   path: the path to validate
#   name: the name of the variable to validate
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if the provided path is empty or it references a valid, non-empty file, 1 otherwise
#######################################
function validate_optional_file() {
    local path="${1}"
    local name="${2:-${name}}"

    [[ -n "${path}" ]] && ! validate_file "${path}" "${name}" && return 1
    return 0
}

#######################################
# Validates that a path references a valid directory.
# Arguments:
#   path: the path to validate
#   name: the name of the variable to validate
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if the provided path references a valid directory, 1 otherwise
#######################################
function validate_dir() {
    local path="${1}"
    local name="${2:-${path}}"

    if [[ ! -d "${path}" ]]; then
        __log_error "${name} must refer to a valid directory"
        return 1
    fi
}

#######################################
# Validates that key is a valid references in the provided json file.
# Arguments:
#   path: a path to a json file
#   key: the key to validate (can be compound key)
#   desc: a description of the reference being validated
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if key is a valid reference in path, 1 otherwise
#######################################
function validate_json_key() {
    local path="${1}"
    local key="${2}"
    local desc="${3:-${key}}"

    if [[ "$(jq "${key}" "${path}")" == "null" ]]; then
        __log_error "unable to find ${desc} in json file=${path}"
        return 1
    fi
}

#######################################
# Validates that key is a valid references in the provided yaml file.
# Arguments:
#   path: a path to a yaml file
#   key: the key to validate (can be compound key)
#   desc: a description of the reference being validated
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if key is a valid reference in path, 1 otherwise
#######################################
function validate_yaml_key() {
    local path="${1}"
    local key="${2}"
    local name="${3:-${key}}"

    if [[ "$(yq "${key}" "${path}")" == "null" ]]; then
        __log_error "unable to find ${name} in yaml file=${path}"
        return 1
    fi
}

#######################################
# Validates that key is a valid references in the provided toml file.
# Arguments:
#   path: a path to a toml file
#   key: the key to validate (can be compound key)
#   desc: a description of the reference being validated
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if key is a valid reference in path, 1 otherwise
#######################################
function validate_toml_key() {
    local path="${1}"
    local key="${2}"
    local name="${3:-${key}}"

    if [[ "$(tq "${path}" "${key}")" == "null" ]]; then
        __log_error "unable to find ${name} in toml file=${path}"
        return 1
    fi
}

#######################################
# Validates that the provided references are executables (accessible via which).
# Arguments:
#   caller: the name of the dependent caller
#   n references to executables to validate
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if all executables are installed, 1 otherwise
#######################################
function validate_installed() {
    local caller="${1}" && shift

    check_installed "$@" && return 0

    local -r pkgs="$(join_by ", " "$@")"
    __log_error "${caller} requires that these packages be installed: ${pkgs}"
}

#######################################
# Validates that the provided variables are set in the environment.
# Arguments:
#   n variable names to check
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if all variables are present in the environment are installed, 1 otherwise
#######################################
function validate_required_env() {
    while [[ $# -ge 0 ]]; do
        local var_name="${1}"

        if [[ -z "${!var_name+x}" ]]; then
            __log_error "env var=${var_name} is not set"
            return 1
        fi
    done
}

