#!/bin/bash


# sourced from https://stackoverflow.com/questions/1527049/how-can-i-join-elements-of-a-bash-array-into-a-delimited-string
function join_by() {
    local d=${1-} f=${2-}

    if shift 2; then
        printf %s "$f" "${@/#/$d}"
    fi
}


function md5_checksum() {
    local path="${1}"

    if [[ ! -f "${path}" || ! -s "${path}" ]]; then
        echo 2
    else
        md5sum -c --status "${path}"
        echo $?
    fi
}


function yes_or_no() {
    local prompt="${1:-Are you sure?}"
    local full_prompt="${prompt} [y/N] "

    read -p "${full_prompt}" -n 1 -r

    [[ $REPLY =~ ^[y]$ ]] && echo "true" || echo "false"
}

