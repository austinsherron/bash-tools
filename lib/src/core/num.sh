#!/usr/bin/env bash


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

