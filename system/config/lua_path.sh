#!/bin/bash

set -Eeuo pipefail

source "${CODE_ROOT}/lib/bash/utils.sh"


USAGE="usage: lua-path -d {-d} [-e] [-p] [-a] [-s] [-v]"

usage() {
    echo "${USAGE}"
}

help() {
cat <<help
DESCRIPTION

    Discover, display, and write to stdout in format expected for "LUA_PATH" lua code 
    sources found in search directories provided via -d. By default, this script considers
    any directory named "lua" as containing lua source.

USAGE

    ${USAGE}

OPTIONS

    -d, --dir       multi-valued; directories in which to search for lua sources
    -p, --pattern   optional, defaults to "lua"; the name pattern that identifies lua 
                    sources
    -a, --args      optional; args passed to the find command that searches for lua 
                    sources; overrides built-in find filter args
    -s, --strict    optional; if present, the script will fail if any single provided 
                    search dir is invalid (i.e.: doesn't exist)
    -v, --verbose   optional; if present, the script will print to stdout the paths of 
                    discovered lua sources
    -h, --help      display this message

help
}


DIRS=()
VALID_DIRS=()
PATTERN="lua"
ARGS="-maxdepth 4 -type d"
STRICT=""
VERBOSE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--dir)
      DIRS+=("${2}")
      shift
      shift
      ;;
    -p|--pattern)
      PATTERN="${2}"
      shift
      shift
      ;;
    -a|--args)
      ARGS="${2}"
      shift
      shift
      ;;
    -s|--strict)
      STRICT="true"
      shift
      ;;
    -v|--verbose)
      VERBOSE="true"
      shift
      ;;
    -h|--help)
      help
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

for dir in "${DIRS[@]}"; do
    if [[ -d "${dir}" ]]; then
        VALID_DIRS+=("${dir}")
    else 
        echo "Warning: ${dir} is not a valid directory"
        [[ "${STRICT}" = "true" ]] && exit 1
    fi
done

if [[ "${#VALID_DIRS[@]}" -eq "0" ]]; then
    echo "At least one (1) valid search directory (-d|--dir) is required"
    exit 1
fi

# "${CODE_ROOT}" "${NVIM_ROOT}" "${CONFIG_ROOT}"

# SEARCH_DIRS="$(join_by "\" \"" "${VALID_DIRS[@]}")"
readarray -d '' LUA_DIRS < <(find "${VALID_DIRS[@]}" ${ARGS} -name "${PATTERN}" -print0)

LUA_PATHS=()

for path in "${LUA_DIRS[@]}"; do
    LUA_FILE_PATH="${path}/?.lua"
    LUA_INIT_PATH="${path}/?/init.lua"

    if [[ "${VERBOSE}" = "true" ]]; then
        echo "${LUA_FILE_PATH}"
        echo "${LUA_INIT_PATH}"
    fi

    LUA_PATHS+=("${LUA_FILE_PATH}")
    LUA_PATHS+=("${LUA_INIT_PATH}")
done

LUA_PATH="$(join_by ";" "${LUA_PATHS[@]}")"
echo "${LUA_PATH}"

