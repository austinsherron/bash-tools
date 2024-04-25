#!/usr/bin/env bash

source "${BASH_LIB}/args/validate.sh"
source "${BASH_LIB}/utils/exec.sh"


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

### auth/config related utils

#######################################
# Gets/sets the active aws profile.
# Globals:
#   AWS_PROFILE: reads this to display active profile, updates it to set it
# Arguments:
#   profile: optional; the profile to set; omitting profile results in a read operation
# Outputs:
#   Writes to stdout the value of AWS_PROFILE, if profile is omitted
#######################################
function aws::profile() {
    local profile="${1:-}"

    if [[ -z "${profile}" ]]; then
        echo "${AWS_PROFILE}"
    else
        export AWS_PROFILE="${profile}"
    fi
}

#######################################
# Displays available aws profiles via "aws configure list-profiles".
# Outputs:
#   Outputs of "aws configure list-profiles"
#######################################
function aws::profiles() {
    aws configure list-profiles
}

#######################################
# Pipes the output of aws::profiles to fzf.
# Outputs:
#   Outputs of "aws::profiles" via fzf
#   Writes to stdout the selected profile
#######################################
function aws::profile::choose() {
    aws::profiles | fzf
}

#######################################
# Initiates sso login via "aws sso login".
# Arguments:
#   profile: optional; if omitted, caller is prompted to select a profile via "aws::profile::choose".
# Outputs:
#   Outputs of "aws sso login"
#######################################
function aws::sso() {
    local profile="${1:-$(aws::profile::choose)}"
    aws sso login --profile "${profile}"
}

#######################################
# Gets the callers aws auth identity via "aws sts get-caller-identity".
# Arguments:
#   profile: optional; if omitted, caller is prompted to select a profile via "aws::profile::choose".
# Outputs:
#   Outputs of "aws sts get-caller-identity"
#######################################
# shellcheck disable=SC2120
function aws::whoami() {
    local profile="${1:-$(aws::profile::choose)}"
    aws sts get-caller-identity --profile "${profile}"
}

#######################################
# Logs the caller in as the provided--or selected--profile and sets it as the active aws profile.
# Arguments:
#   profile: optional; if omitted, caller is prompted to select a profile via "aws::profile::choose".
# Outputs:
#   Outputs of "aws::profiles" via fzf
#   Outputs of "aws::sso"
#######################################
function aws::profile::assume() {
    local -r profile="${1:-$(aws::profile::choose)}"

    test -z "$(aws::whoami "${profile}" 2> /dev/null)" && aws::sso "${profile}"

    aws::profile "${profile}"
}

#######################################
# Gets/sets the active aws region.
# Arguments:
#   region: optional; the region to set; omitting region results in a read operation
# Outputs:
#   Writes to stdout the active aws region, if region is omitted
#######################################
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
    local region="${4:-$(aws::region)}"
    local selector="."

    [[ "${svc_code}" == "-" ]] && [[ -n "${SVC_BY_QUOTA[${quota_code}]+x}" ]] && svc_code="${SVC_BY_QUOTA[${quota_code}]}"
    [[ "${field}" != "-" ]] && selector=".Quotas[].${field}"

    validate_required svc_code "${svc_code}" || return 1
    validate_required quota_code "${quota_code}" || return 1
    validate_required region "${region}" || return 1

    aws service-quotas list-service-quotas --service-code "${svc_code}" --quota-code "${quota_code}" --region "${region}" | jq -r "${selector}"
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

### ecr related utils

#######################################
# Displays information about/values from ecr repos via "aws ecr describe-repositories".
# Arguments:
#   repo: optional; if omitted, queries all ecr repos in the provided/configured region
#   field: optional, excluded via "-"; the repo field to query; if omitted, displays the entire repo info block
#   region: optional, defaults to region set in configuration
# Outputs:
#   Args validation error messages
#   Outputs of "aws ecr describe-repositories"
# Returns:
#   1 if arguments aren't valid
#######################################
function ecr::repos() {
    local repo="${1}"
    local field="${2}"
    local region="${3:-$(aws::region)}"

    local cmd=("aws" "ecr" "describe-repositories")
    local selector="."

    [[ "${repo}" != "-" ]] && cmd+=("--repository-name" "${repo}")
    [[ "${field}" != "-" ]] && selector=".repositories[].${field}"

    validate_required region "${region}" || return 1
    cmd+=("--region" "${region}")

    "${cmd[@]}" | jq -r "${selector}"
}

#######################################
# Pipes to fzf the names of all ecr repos of in the provided/configured region.
# Outputs:
#   Outputs all ecr repos of in the provided/configured region via fzf
#   Writes to stdout the selected repo name
#######################################
function ecr::choose_repo() {
    local region="${1:-$(aws::region)}"
    ecr::repos - repositoryName "${region}" | fzf
}

