#!/usr/bin/env bash

export VALIDATE_USE_ULOGGER=""
source "${BASH_TOOLS}/lib/args/validate.sh"


VERSION_PATTERN="^(v?)(([0-9]+)\.([0-9]+)\.([0-9]+))([-_][^[:space:]]+)?$"

declare -A VERSION_PARTS=(
    [prefix]=1
    [version]=2
    [major]=3
    [minor]=4
    [patch]=5
    [train]=5
    [suffix]=6
)

declare -A OPTIONAL_PARTS=(
    [prefix]=1
    [suffix]=1
)

declare -A CAN_INCREMENT=(
    [major]=major
    [minor]=minor
    [patch]=train
    [train]=train
)

#######################################
# Sort "filter" for semantic versions.
#######################################
function version::sort() {
    sort -V
}

#######################################
# Checks if the provided string is a valid semantic version.
# Arguments:
#   version: the string to check
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if the provided version is valid, 1 otherwise
#   2 if the provided args are invalid
#######################################
function version::is_valid() {
    validate_num_args 1 $# "version::is_valid" || return 2

    local version="${1}"

    if [[ ! "${version}" =~ $VERSION_PATTERN ]]; then
        return 1
    fi
}

#######################################
# Validates a semantic version. A semantic version is considered valid if it has the following format:
#   * [v]{0-9}.{0-9}.{0-9}[-non-whitespace-suffix]
# More concretely, the following are valid semantic versions:
#   * 0.0.0
#   * 0.28.100
#   * 1.28.100
#   * v100.0.0
#   * 100.0.0-product
#   * v1.28.4-product
# Arguments:
#   version: the semantic version to validate
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if the provided version is valid, 1 otherwise
#   2 if the provided args are invalid
#######################################
function version::validate() {
    validate_num_args 1 $# "version::validate" || return 2

    local version="${1}"

    if ! version::is_valid "${version}"; then
        echo "[ERROR] '${version}' is not a valid version"
        return 1
    fi
}

#######################################
# Extract parts of a semantic version. For example:
#   * "$(version::extract v1.28.45-product)" == "1.28.45"
#   * "$(version::extract v1.28.45-product version)" == "1.28.45"
#   * "$(version::extract v1.28.45-product major)" == "1"
#   * "$(version::extract v1.28.45-product minor)" == "28"
#   * "$(version::extract v1.28.45-product patch)" == "45"
#   * "$(version::extract v1.28.45-product train)" == "45"
#   * "$(version::extract v1.28.45-product prefix)" == "v"
#   * "$(version::extract v1.28.45-product suffix)" == "-product"
# More concretely, the following are valid semantic versions:
#   * 0.0.0
#   * 0.28.100
#   * 1.28.100
#   * v100.0.0
#   * 100.0.0-product
#   * v1.28.4-product
# Arguments:
#   version: the semantic version from which to extract parts
#   extract: optional, defaults to "version"; the part to extract; valid values include:
#       * prefix
#       * version
#       * major
#       * minor
#       * patch
#       * train
#       * suffix
# Outputs:
#   Prints to stdout the extracted value
#   If the provided args are invalid, prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if the provided args are valid, 1 otherwise
#######################################
function version::extract() {
    validate_min_args 1 $# "version::extract" || return 1

    local version="${1}"
    local extract="${2:-version}"

    validate_one_of "extract" "${extract}" "${!VERSION_PARTS[@]}" || return 1

    local match_idx="${VERSION_PARTS[${extract}]}"

    if [[ "${version}" =~ $VERSION_PATTERN ]]; then
        echo "${BASH_REMATCH[$match_idx]}"
    else
        return 1
    fi
}

#######################################
# Checks if a semantic version has the specific version part. For example:
#   * "$(version::has v1.28.45-product suffix)" -> rc=0
#   * "$(version::has v1.28.45-product prefix)" -> rc=0
#   * "$(version::has v1.28.45 prefix)" -> rc=0
#   * "$(version::has v1.28.45 suffix)" -> rc=1
#   * "$(version::has 1.28.45 prefix)" -> rc=1
# Arguments:
#   version: the version to check
#   n parts for which to check; can be either "prefix" or "suffix"
# Outputs:
#   If the provided args are invalid, prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 the provided version has all provided parts, 1 otherwise
#   2 if the provided args are invalid
#######################################
function version::has() {
    validate_min_args 2 $# "version::has" || return 2

    local version="${1}" ; shift
    local parts=("$@")

    for part in "${parts[@]}"; do
        validate_one_of "part" "${part}" "${!OPTIONAL_PARTS[@]}" || return 1

        if [[ -z "$(version::extract "${version}" "${part}")" ]]; then
            return 1
        fi
    done

    return 0
}

#######################################
# Increments the provided semantic version according to the provided version component. For example:
#   * "$(version::increment v1.28.45-product major)" == "v2.0.0-product"
#   * "$(version::increment v1.28.45-product minor)" == "v1.29.0-product"
#   * "$(version::increment v1.28.45-product patch)" == "v1.28.46-product"
#   * "$(version::increment v1.28.45-product train)" == "v1.28.46-product"
# Arguments:
#   version: the version to increment
#   to_increment: optional, defaults to "patch"; the version component to increment
# Outputs:
#   Prints to stdout the incremented value
#   If the provided args are invalid, prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if the provided args are valid, 1 otherwise
#######################################
function version::increment() {
    local version="${1}"
    local to_increment="${2:-patch}"

    validate_min_args 1 $# "version::inc" || return 1
    validate_one_of "to_increment" "${to_increment}" "${!CAN_INCREMENT[@]}" || return 1
    version::validate "${version}" || return 1

    local new_version=""
    to_increment="${CAN_INCREMENT[${to_increment}]}"

    local -r prefix="$(version::extract "${version}" prefix)"
    local -r major="$(version::extract "${version}" major)"
    local -r minor="$(version::extract "${version}" minor)"
    local -r train="$(version::extract "${version}" train)"
    local -r suffix="$(version::extract "${version}" suffix)"

    if [[ "${to_increment}" == "major" ]]; then
        new_version="$((major + 1)).0.0"
    elif [[ "${to_increment}" == "minor" ]]; then
        new_version="${major}.$((minor + 1)).0"
    elif [[ "${to_increment}" == "train" ]]; then
        new_version="${major}.${minor}.$((train + 1))"
    fi

    echo "${prefix}${new_version}${suffix}"
}

