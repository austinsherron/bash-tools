#!/usr/bin/env bash

set -Eeuo pipefail

source /etc/profile.d/shared_paths.sh


USAGE="usage: nerd-font.sh -n name [-s style] -f file [-d dirpath]"

usage() {
    echo "${USAGE}"
}

help() {
cat <<help
DESCRIPTION

    Install a nerd font, by default, to the (linux) fonts directory.

USAGE

    ${USAGE}

OPTIONS

    -n, --name      the name of the font
    -f, --file      the font file name
    -s, --style     required for some fonts, not for others, as font dir structure is inconsistent; the font style/weight; subdir of font name for some fonts
    -d, --dir       optional, defaults to linux font directory; the directory to which to install the font
    -v, --verbose   optional; if present, the script will print to stdout the full font url
    -h, --help      display this message

help
}


FONT_DIR="${ADMIN_HOME}/.local/share/fonts"
URL="https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts"

FONT_NAME=""
STYLE=""
FILE_NAME=""
VERBOSE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--name)
      FONT_NAME="${2}"
      shift
      shift
      ;;
    -s|--style)
      STYLE="/${2}"
      shift
      shift
      ;;
    -f|--file)
      FILE_NAME="${2}"
      shift
      shift
      ;;
    -d|--dir)
      FONT_DIR="${2}"
      shift
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


required_param "-n|--name" "${FONT_NAME}" || exit 1
required_param "-f|--file" "${FILE_NAME}" || exit 1

FULL_URL="${URL}/${FONT_NAME}${STYLE}/${FILE_NAME}"

if [[ "${VERBOSE}" == "true" ]]; then
    echo "[INFO] url='${FULL_URL}'"
fi

if [[ ! -d "${FONT_DIR}" ]]; then
    echo "[ERROR] Font directory does not exist (${FONT_DIR})"
    exit 1
fi

if [[ ! ${FULL_URL} == *.ttf ]] && [[ ! ${FULL_URL} == *.otf ]]; then
    echo "[ERROR] URL must reference a font file (*.ttf|*.otf)"
    exit 1
fi

cd "${FONT_DIR}" && curl -fLO "${FULL_URL}"

