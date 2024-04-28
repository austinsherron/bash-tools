#!/usr/bin/env bash


#######################################
# Bounds a number by an inclusive range. For example:
#   "$(num::bounded 0 -1 1)" == 0
#   "$(num::bounded -2 -1 1)" == -1
#   "$(num::bounded 2 -1 1)" == 1
# Arguments:
#   num: the number to bound
#   min: the lower bound of the range
#   max: the upper bound of the range
# Outputs:
#   num if min <= num <= max
#   min if num < min
#   max if num > max
#######################################
function num::bounded() {
    local num="${1}" ; local min="${2}" ; local max="${3}"

    if [[ $num -ge $min ]] && [[ $num -le $max ]]; then
        echo "${num}"
    elif [[ $num -lt $min ]]; then
        echo "${min}"
    elif [[ $num -gt $max ]]; then
        echo "${max}"
    fi
}

