#!/usr/bin/env bash


## constants ###################################################################

export NO_COLOR="\e[0m"

## styles

function style::normal() { echo "0;${1}"; }
function style::bold() { echo "1;${1}"; }
function style::italic() { echo "3;${1}"; }
function style::underline() { echo "4;${1}"; }
function style::strikethrough() { echo "9;${1}"; }
function style::background() { echo $((10 + $1)); }

alias style::it="style::italic"
alias style::ul="style::underline"
alias style::st="style::strikethrough"
alias style::bg="style::background"

## colors

export COLORS=(
    RED
    ORANGE
    GREEN
    LIGHT_GREEN
    YELLOW
    LIGHT_YELLOW
    BLUE
    LIGHT_BLUE
    PURPLE
    LIGHT_PURPLE
    CYAN
    LIGHT_CYAN
    BLACK
    GREY
    WHITE
)

export RED="31"
export ORANGE="91"
export GREEN="32"
export LIGHT_GREEN="92"
export YELLOW="33"
export LIGHT_YELLOW="93"
export BLUE="34"
export LIGHT_BLUE="94"
export PURPLE="35"
export LIGHT_PURPLE="95"
export CYAN="36"
export LIGHT_CYAN="96"
export BLACK="30"
export GREY="90"
export WHITE="37"

## functions ###################################################################

function make_color() {
    local code="${1}"
    local style="style::${2:-normal}"

    # shellcheck disable=SC2086
    local -r color="$("${style}" $code)"

    # shellcheck disable=SC2028
    echo "\e[${color}m"
}

#######################################
# Writes to stdout in the provided color and style.
# Arguments:
#   code: the code of the color to use
#   style: the style to use
#   all remaining function arguments are written to stdout in the provided color and style
# Outputs:
#   arguments 2-n, in the provided color and style
#######################################
function style::ize() {
    local code="${1}" ; shift
    local style="${1}" ; shift

    local -r color="$(make_color "${code}" "${style}")"
    echo -e "${color}$*$(color::stop)"
}

#######################################
# Writes to stdout in the provided color.
# Arguments:
#   code: the code of the color to use
#   all remaining function arguments are written to stdout in the provided color
# Outputs:
#   arguments 2-n, in the provided color
#######################################
function color::ize() {
    local code="${1}" ; shift
    style::ize "${code}" normal "$@"
}

#######################################
# Writes to stdout an indicator that all subsequent content written to stdout (w/ "echo -e") should display as the provided color.
# Arguments:
#   code: the code of the color to display
# Outputs:
#   Prints to stdout an indicator that all subsequent content written to stdout (w/ "echo -e") should display as the provided color
#######################################
function color::start() {
    local code="${1}"
    make_color "${code}"
}

#######################################
# For use after color::start. Writes to stdout an indicator that color should stop.
# Globals:
#   NO_COLOR: a constant who's value is the aforementioned indicator
# Outputs:
#   Prints to stdout an indicator that color should stop
#######################################
function color::stop() {
    echo "${NO_COLOR}"
}

#######################################
# Writes to stdout colors of the provided style.
# Arguments:
#   style: optional, defaults to "normal"; the style of colors to display
# Outputs:
# Prints to stdout colors of the provided style
#######################################
function color::list() {
    local style="${1:-normal}"

    for color_name in "${COLORS[@]}"; do
        style::ize "${!color_name}" "${style}" "${color_name}"
    done
}

