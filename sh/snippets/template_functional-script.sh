#!/usr/bin/env bash
#
# This script does some stuff


## imports #####################################################################
################################################################################

include-source 'debug.sh'


## exit codes ##################################################################
################################################################################

declare -ri E_SUCCESS=0
declare -ri E_ERROR=1


## traps #######################################################################
################################################################################

# @description Silence all output
# @usage silence-output
function silence-output() {
    exec 3>&1 4>&2 1>/dev/null 2>&1
}

# @description Restore stdout and stderr
# @usage restore-output
function restore-output() {
    [[ -t 3 ]] && exec 1>&3 3>&-
    [[ -t 4 ]] && exec 2>&4 4>&-
}

# @description Exit trap
function trap-exit() {
    restore-output
}
trap trap-exit EXIT


## colors ######################################################################
################################################################################

# Determine if we're in a terminal
[[ -t 1 ]] && __IN_TERMINAL=true || __IN_TERMINAL=false

# @description Set up color variables
# @usage setup-colors
function setup-colors() {
    C_RED='\e[31m'
    C_GREEN='\e[32m'
    C_YELLOW='\e[33m'
    C_BLUE='\e[34m'
    C_MAGENTA='\e[35m'
    C_CYAN='\e[36m'
    C_WHITE='\e[37m'
    S_RESET='\e[0m'
    S_BOLD='\e[1m'
    S_DIM='\e[2m'
    S_UNDERLINE='\e[4m'
    S_BLINK='\e[5m'
    S_INVERT='\e[7m'
    S_HIDDEN='\e[8m'
}


## usage functions #############################################################
################################################################################

function help-usage() {
    # {{TODO: UPDATE USAGE}}
    echo "usage: $(basename "${0}") [-h]"
}

function help-epilogue() {
    # {{TODO: UPDATE EPILOGUE}}
    echo "do stuff"
}

function help-full() {
    help-usage
    help-epilogue
    echo
    echo "Some extra info."
    echo
    echo "Options:"
    cat << EOF
    -h                    display usage
    --help                display this help message
    -c/--color <when>     when to use color ("auto", "always", "never")
    -s/--silent           suppress all output
    {{TODO: INSERT OPTIONS HERE}}
EOF
}

function parse-args() {
    # Default values
    # {{TODO: INSERT DEFAULT VALUES HERE}}
    FILEPATHS=()
    DO_COLOR=false
    DO_SILENT=false
    DO_THE_THING=true
    local color_when='auto' # auto, on, yes, always, off, no, never

    # Loop over the arguments
    while [[ ${#} -gt 0 ]]; do
        case ${1} in
            -h)
                help-usage
                help-epilogue
                exit ${E_SUCCESS}
                ;;
            --help)
                help-full
                exit ${E_SUCCESS}
                ;;
            -c | --color)
                color_when="${2}"
                shift 1
                ;;
            -f | --foo)
                echo "oh my foo"
                ;;
            -s | --silent)
                DO_SILENT=true
                ;;
            --)
                shift 1
                break
                ;;
            -*)
                echo "error: unknown option: ${1}" >&2
                return ${E_ERROR}
                ;;
            *)
                FILEPATHS+=("${1}")
                ;;
        esac
        shift 1
    done

    # If -- was used, collect the remaining arguments
    while [[ ${#} -gt 0 ]]; do
        FILEPATHS+=("${1}")
        shift 1
    done

    # If in silent mode, silence the output
    ${DO_SILENT} && silence-output

    # Set up colors
    if ! ${DO_SILENT}; then
        case "${color_when}" in
            on | yes | always)
                DO_COLOR=true
                ;;
            off | no | never)
                DO_COLOR=false
                ;;
            auto)
                if ${__IN_TERMINAL}; then
                    DO_COLOR=true
                else
                    DO_COLOR=false
                fi
                ;;
            *)
                echo "error: invalid color mode: ${color_when}" >&2
                return ${E_ERROR}
                ;;
        esac
        ${DO_COLOR} && setup-colors
    fi

    # {{TODO: INSERT OPTION VALIDATIONS HERE}}

    return ${E_SUCCESS}
}


## helpful functions ###########################################################
################################################################################

# @description Do stuff
# @usage do-stuff
function do-stuff() {
    echo -n "i'm doin the stuff"
    [[ -n "${1}" ]] && echo -e " to ${C_CYAN}${1}${S_RESET}" || echo
}


## main ########################################################################
################################################################################

function main() {
    parse-args "${@}" || return ${?}

    for filepath in "${FILEPATHS[@]}"; do
        do-stuff "${filepath}"
    done
}


## run #########################################################################
################################################################################

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "${@}"