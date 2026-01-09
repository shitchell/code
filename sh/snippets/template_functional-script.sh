#!/usr/bin/env bash
#
# This script does some stuff


## imports #####################################################################
################################################################################

include-source 'debug.sh'


## exit codes ##################################################################
################################################################################

function _setup-exit-codes() {
    :  'Set up exit code constants'
    declare -gr E_SUCCESS=0
    declare -gr E_ERROR=1
    # When working on multiple related scripts, consider a shared exit code file
    #source path/to/common-exit-codes.sh
}


## traps #######################################################################
################################################################################

function _trap-exit() {
    :  'Exit trap that calls all __exit-* functions

        To add an exit handler, define a function named __exit-<name>.
        To remove it later, use: unset -f __exit-<name>
    '
    local -- __func
    for __func in $(compgen -A function __exit-); do
        "${__func}"
    done
}
trap _trap-exit EXIT

function _silence-output() {
    :  'Silence all script output'
    exec 3>&1 4>&2 1>/dev/null 2>&1

    function __exit-restore-output() {
        [[ -t 3 ]] && exec 1>&3 3>&-
        [[ -t 4 ]] && exec 2>&4 4>&-
    }
}


## colors ######################################################################
################################################################################

function _setup-colors() {
    :  'Set up color variables'
    # Base ANSI codes
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_MAGENTA=$'\033[35m'
    C_CYAN=$'\033[36m'
    C_WHITE=$'\033[37m'
    S_RESET=$'\033[0m'
    S_BOLD=$'\033[1m'
    S_DIM=$'\033[2m'
    S_UNDERLINE=$'\033[4m'
    S_BLINK=$'\033[5m'
    S_INVERT=$'\033[7m'
    S_HIDDEN=$'\033[8m'

    # {{TODO: ADD CATEGORICAL COLORS HERE}}
    C_TITLE="${S_BOLD}${C_BLUE}"
    C_FILENAME="${C_CYAN}"
    C_COMMENT="${S_BOLD}${S_DIM}"
}

function _unset-colors() {
    :  'Unset color variables'
    C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_MAGENTA='' C_CYAN='' C_WHITE=''
    S_RESET='' S_BOLD='' S_DIM='' S_UNDERLINE='' S_BLINK='' S_INVERT='' S_HIDDEN=''
    # {{TODO: UNSET CATEGORICAL COLORS HERE}}
    C_TITLE='' C_FILENAME='' C_COMMENT=''
}


## initialization ##############################################################
################################################################################

function __help-usage() {
    :  'Print brief usage'
    # {{TODO: UPDATE USAGE}}
    echo "usage: $(basename "${0}") [-h]"
}

function __help-epilogue() {
    :  'Print brief description'
    # {{TODO: UPDATE EPILOGUE}}
    echo "do stuff"
}

function __help-full() {
    :  'Print full help'
    __help-usage
    __help-epilogue
    echo
    echo "Some extra info."
    echo
    echo "Options:"
    cat << '    EOF'
    -h                    display usage
    --config-file <file>  use the specified configuration file
    --help                display this help message
    -c/--color <when>     when to use color ("auto", "always", "never")
    -s/--silent           suppress all output
    {{TODO: INSERT OPTIONS HERE}}
    EOF
}

function _parse-args() {
    :  'Parse command-line arguments'
    # Parse the arguments first for a config file to load default values from
    CONFIG_FILE="${HOME}/.$(basename "${0}").conf"
    for ((i=0; i<${#}; i++)); do
        case "${!i}" in
            --config-file)
                let i++
                CONFIG_FILE="${!i}"
                ;;
        esac
    done
    [[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}"

    # Default values
    # {{TODO: INSERT DEFAULT VALUES HERE}}
    FILEPATHS=()
    DO_COLOR=false
    DO_SILENT=false
    COLOR_WHEN="${COLOR:-auto}"  # auto, on, yes, always, off, no, never

    # Loop over the arguments
    while [[ ${#} -gt 0 ]]; do
        case ${1} in
            -h)
                __help-usage
                __help-epilogue
                exit ${E_SUCCESS}
                ;;
            --help)
                __help-full
                exit ${E_SUCCESS}
                ;;
            --config-file)
                shift 1
                ;;
            -c | --color)
                COLOR_WHEN="${2}"
                shift 1
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

    # {{TODO: INSERT OPTION VALIDATIONS HERE}}

    return ${E_SUCCESS}
}

function _setup() {
    :  'Set up the environment based on parsed arguments'
    # If in silent mode, silence the output
    ${DO_SILENT} && _silence-output

    # Set up colors
    if ! ${DO_SILENT}; then
        case "${COLOR_WHEN}" in
            on | yes | always)
                DO_COLOR=true
                ;;
            off | no | never)
                DO_COLOR=false
                ;;
            auto)
                ${__IN_TERMINAL} && DO_COLOR=true || DO_COLOR=false
                ;;
            *)
                echo "error: invalid color mode: ${COLOR_WHEN}" >&2
                return ${E_ERROR}
                ;;
        esac
        ${DO_COLOR} && _setup-colors || _unset-colors
    fi

    # {{TODO: ADD ADDITIONAL SETUP HERE (temp dirs, extra traps, etc.)}}

    return ${E_SUCCESS}
}


## helpful functions ###########################################################
################################################################################

function do-stuff() {
    :  'This function does the stuff

        @usage
            [<arg>]

        @arg <arg>
            This arg is very arg-like

        @stdout
            A message, optionally about <arg>
    '
    local -- __myvar="${1}"
    echo -n "i'm doin the stuff"
    [[ -n "${__myvar}" ]] && echo -e " to ${C_CYAN}${__myvar}${S_RESET}" || echo
}


## main ########################################################################
################################################################################

function main() {
    _setup-exit-codes
    _parse-args "${@}" || return ${?}
    _setup || return ${?}

    for filepath in "${FILEPATHS[@]}"; do
        do-stuff "${filepath}"
    done
}


## run #########################################################################
################################################################################

(
    [[ -t 1 ]] && __IN_TERMINAL=true || __IN_TERMINAL=false
    [[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "${@}"
)
