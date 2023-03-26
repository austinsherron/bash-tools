#!/bin/bash


# sourced from https://stackoverflow.com/questions/1527049/how-can-i-join-elements-of-a-bash-array-into-a-delimited-string
function join_by() {
    local d=${1-} f=${2-}

    if shift 2; then
        printf %s "$f" "${@/#/$d}"
    fi
}

 
function md5_checksum() {
    path="${1}"

    if [[ ! -f "${path}" || ! -s "${path}" ]]; then
        echo 2 
    else 
        md5sum -c --status "${path}"
        echo $?
    fi 
}

