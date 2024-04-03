#!/usr/bin/env bash

source "${LOCAL_LIB}/bash/args/validate.sh"


#######################################
# Performs an aws dynamo db query via "aws dynamodb query". See "aws dynamodb query help" for more details.
# Arguments:
#   table: the table from which to query (--table-name)
#   query: the dynamo db query string (--key-condition-expression)
#   where: the query string values (--expression-attribute-values)
#   select: optional; the fields to select (--select)
#   selector: optional; a jq selector to transform query output
# Outputs:
#   Prints to stdout the results of the query
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if the provided args are valid, 1 otherwise, or if there's a query error
#######################################
function dynamodb::query() {
    validate_min_args 3 $# "dynamodb::query" || return 1
    validate_installed "dynamodb::query" aws

    local table="${1}"
    local query="${2}"
    local -r where="$(echo "${3}" | tr "'" '"')"
    local select="${4:-}"
    local selector="${5:-}"

    local cmd=("aws" "dynamodb" "query")
    cmd+=("--table-name" "${table}")
    cmd+=("--key-condition-expression" "${query}")
    cmd+=("--expression-attribute-values" "${where}")

    if [[ -n "${select}" ]]; then
        cmd+=("--select" "SPECIFIC_ATTRIBUTES")
        cmd+=("--projection-expression" "${select}")
    fi

    "${cmd[@]}" | jq -r ".Items${selector}"
}

#######################################
# Performs an aws dynamo db update via "aws dynamodb update-item". See "aws dynamodb update-item help" for more details.
# Arguments:
#   table: the table from which to update (--table-name)
#   key: the key of the item to update (--key)
#   values: the new values (i.e.: values after update) (--attribute-updates)
#   dry_run: optional, defaults to "false" (i.e.: empty); if  provided, echos the update statement instead of updated values
# Outputs:
#   Prints to stdout the updated values
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if the provided args are valid, 1 otherwise, or if there's a update error
#######################################
function dynamodb::update() {
    validate_min_args 3 $# "dynamodb::update" || return 1
    validate_installed "dynamodb::query" aws

    local table="${1}"
    local -r key="$(echo "${2}" | tr "'" '"')"
    local -r values="$(echo "${3}" | tr "'" '"')"
    local dry_run="${4:-""}"

    local cmd=("aws" "dynamodb" "update-item")
    cmd+=("--table-name" "${table}")
    cmd+=("--key" "${key}")
    cmd+=("--attribute-updates" "${values}")
    cmd+=("--return-values" "UPDATED_NEW")

    if [[ -z "${dry_run}" ]]; then
        "${cmd[@]}"
    else
        echo "${cmd[*]}"
    fi
}

