#!/usr/bin/env bash

source "${LOCAL_LIB}/bash/args/validate.sh"


### useful constants

## regions

export AWS_UW1="us-west-1"
export AWS_UW2="us-west-2"
export AWS_UE1="us-east-1"
export AWS_UE2="us-east-2"

export AWS_US=("${AWS_UW1}" "${AWS_UW2}" "${AWS_UE1}" "${AWS_UE2}")

## aws quota "services" (i.e.: types)

export AWS_SVC_EC2="ec2"

## aws quota codes

export AWS_QUOTA_EC2_GPU="L-DB2E81BA"

# maps quotas to their services
declare -A SVC_BY_QUOTA=(
    ["${AWS_QUOTA_EC2_GPU}"]="${AWS_SVC_EC2}"
)

### config related utils

# shellcheck disable=SC2120
function aws::region() {
    local region="${1:-}"

    if [[ -z "${region}" ]]; then
        aws configure get region || return 1
    else
        aws configure set region "${region}" || return 1
    fi
}

### quota related utils

#######################################
# List aws quota services.
# Arguments:
#   region: optional; defaults to region set in configuration
# Outputs:
#   Outputs of "aws service-quotas list-services"
#######################################
function aws::services() {
    local region="${1:-$(aws::region)}"

    aws service-quotas list-services --region "${region}"
}

#######################################
# Displays information about/values from service quotas via "aws service-quotas list-service-quotas".
# Arguments:
#   svc_code: optional if an entry for quota_code exists in "SVC_BY_QUOTA", above; excluded via "-"; the aws service code of the quota to query
#   quota_code: the code of the quota to query
#   field: optional, excluded via "-"; the quota field to query; if excluded, displays the entire quota info block
#   region: optional, defaults to region set in configuration
# Outputs:
#   Args validation error messages
#   Outputs of "aws service-quotas list-service-quotas"
# Returns:
#   1 if arguments aren't valid
#######################################
function aws::quota() {
    local svc_code="${1}"
    local quota_code="${2}"
    local field="${3}"
    local region="${4:-}"
    local selector

    [[ "${svc_code}" == "-" ]] && [[ -n "${SVC_BY_QUOTA[${quota_code}]+x}" ]] && svc_code="${SVC_BY_QUOTA[${quota_code}]}"
    [[ "${field}" != "-" ]] && selector=".Quotas[].${field}"
    [[ -z "${region}" ]] && region="$(aws::region)"

    validate_required svc_code "${svc_code}" || return 1
    validate_required quota_code "${quota_code}" || return 1
    validate_required region "${region}" || return 1

    if [[ -n "${selector}" ]]; then
        aws service-quotas list-service-quotas --service-code "${svc_code}" --quota-code "${quota_code}" --region "${region}" | jq -r "${selector}"
    else
        aws service-quotas list-service-quotas --service-code "${svc_code}" --quota-code "${quota_code}" --region "${region}"
    fi
}

#######################################
# Has two functions:
#   1) if quota_code is, provided, calls aws::quota on one or more regions
#   2) if quota_code is omitted, lists quotas for svc_code via "aws service-quotas list-service-quotas --service-code "${svc_code}""
# Arguments:
#   svc_code: optional if an entry for quota_code exists in "SVC_BY_QUOTA", above; excluded via "-"; the aws service code of the quota to query
#   quota_code: optional if svc_code is provided; the code of the quota to query
#   field: optional, excluded via "-"; the quota field to query; if excluded, displays the entire quota info block
#   remaining arguments, if any, are treated as regions
# Outputs:
#   Args validation error messages
#   Outputs of "aws::quota"
#   Outputs of "aws service-quotas list-service-quotas --service-code"
# Returns:
#   1 if arguments aren't valid
#######################################
function aws::quotas() {
    local svc_code="${1}" ; shift
    local quota_code="${1}" ; shift
    local field="${1}" ; shift
    local regions=("$@")

    [[ "${#regions[@]}" -eq 0 ]] && regions=("$(aws::region)")

    validate_at_least_one svc_code "${svc_code}" quota_code "${quota_code}" || return 1
    validate_required_array "regions" "${regions[@]}" || return 1

    if [[ -z "${quota_code}" ]]; then
        aws service-quotas list-service-quotas --service-code "${svc_code}" --region "${regions[0]}" && return 0 || return 1
    fi

    for region in "${regions[@]}" ; do
        echo "${region}=$(aws::quota "${svc_code}" "${quota_code}" "${field}" "${region}")" || return 1
    done
}

