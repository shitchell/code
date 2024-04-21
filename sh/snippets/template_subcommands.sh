#!/usr/bin/env bash
#
# This script does some stuff with subcommands


## imports #####################################################################
################################################################################

include-source 'debug.sh'


## exit codes ##################################################################
################################################################################

declare -ri E_SUCCESS=0
declare -ri E_ERROR=1
declare -ri E_INVALID_OPTION=2
declare -ri E_INVALID_ACTION=3


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
    C_RED=$'\e[31m'
    C_GREEN=$'\e[32m'
    C_YELLOW=$'\e[33m'
    C_BLUE=$'\e[34m'
    C_MAGENTA=$'\e[35m'
    C_CYAN=$'\e[36m'
    C_WHITE=$'\e[37m'
    S_RESET=$'\e[0m'
    S_BOLD=$'\e[1m'
    S_DIM=$'\e[2m'
    S_UNDERLINE=$'\e[4m'
    S_BLINK=$'\e[5m'
    S_INVERT=$'\e[7m'
    S_HIDDEN=$'\e[8m'
}

# @description Unset color variables
# @usage unset-colors
function unset-colors() {
    unset C_RED C_GREEN C_YELLOW C_BLUE C_MAGENTA C_CYAN C_WHITE \
          S_RESET S_BOLD S_DIM S_UNDERLINE S_BLINK S_INVERT S_HIDDEN
}


## usage functions #############################################################
################################################################################

function help-usage() {
    # {{TODO: UPDATE USAGE}}
    echo "usage: $(basename "${0}") [-h] <action> [<action args>]"
}

function help-epilogue() {
    # {{TODO: UPDATE EPILOGUE}}
    echo "run subcommands with individual options"
}

function help-full() {
    help-usage
    help-epilogue
    echo
    echo "Actions:"
    cat << EOF
    {{TODO: INSERT ACTIONS HERE}}
    help                      display this help message
EOF
    echo
    echo "Base Options:"
    cat << EOF
    -h                        display usage
    --help                    display this help message
    --config-file <file>      use the specified configuration file
    -c/--color <on|auto|off>  whether to use color output
    -s/--silent               suppress all output
    {{TODO: INSERT BASE OPTIONS HERE}}
EOF
    echo
    echo "For action specific options, run:"
    echo "    $(basename "${0}") help <action>"
}

function parse-args() {
    # Parse the arguments first for a config file to load default values from
    CONFIG_FILE="${HOME}/.$(basename "${0}").conf"
    for ((i=0; i<${#}; i++)); do
        case "${!i}" in
            -c | --config-file)
                let i++
                CONFIG_FILE="${!i}"
                ;;
        esac
    done
    [[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}"

    # Default values
    # {{TODO: INSERT DEFAULT VALUES HERE}}
    DO_COLOR=false
    DO_SILENT=false
    ACTION=""
    ACTION_ARGS=()
    local color_when="${COLOR:-auto}" # auto, on, yes, always, off, no, never

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
            --config-file)
                shift 1
                ;;
            -c | --color)
                color_when="${2}"
                shift 1
                ;;
            -s | --silent)
                DO_SILENT=true
                ;;
            # {{TODO: INSERT OPTIONS HERE}}
            -*)
                echo "error: unknown option: ${1}" >&2
                return ${E_INVALID_OPTION}
                ;;
            *)
                ACTION="${1}"
                shift 1
                break
                ;;
        esac
        shift 1
    done

    # Any remaining arguments will be passed to the action function
    while [[ ${#} -gt 0 ]]; do
        case ${1} in
            -h | --help)
                __action-help "${ACTION}"
                exit ${E_SUCCESS}
                ;;
            *)
                ACTION_ARGS+=("${1}")
                ;;
        esac
        shift 1
    done

    # Ensure an action was specified
    if [[ -z "${ACTION}" ]]; then
        echo "error: no action specified" >&2
        help-full >&2
        return ${E_INVALID_ACTION}
    fi
    
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
        ${DO_COLOR} && setup-colors || unset-colors
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
    [[ -n "${1}" ]] && echo " to ${1}" || echo
}


## action functions ############################################################
################################################################################

# {{TODO: INSERT __action-* AND __help-* FUNCTIONS HERE}}

# Just show the help
function __help-help() {
    echo "usage: $(basename "${0}") help [<action>]"
    echo
    echo "Display help for the specified action or for $(basename "${0}") if no"
    echo "action is specified."
}

function __action-help() {
    local action="${1}"

    # If an action was specified, show the help for that action
    if [[ -n "${action}" ]]; then
        local help_function="__help-${action}"
        # Verify the help function exists
        if type -t "${help_function}" &>/dev/null; then
            # Call the help function and exit
            "${help_function}"
        else
            echo "error: no help found for action: ${action}" >&2
            return ${E_INVALID_ACTION}
        fi
    else
        # Otherwise, show the full help
        help-full
    fi
}

function __help-_test() {
    echo "usage: $(basename "${0}") _test [-h]"
    echo
    echo "Do stuff."
    echo
    echo "Options:"
    cat << EOF
    -h                       display usage
    --help                   display this help message
    -m/--message <msg>       the message to print
EOF
}

function __action-_test() {
    # Default values
    local message="hello world"

    # Loop over the arguments
    while [[ ${#} -gt 0 ]]; do
        case ${1} in
            -m | --message)
                message="${2}"
                shift 1
                ;;
            -*)
                echo "error: unknown option: ${1}" >&2
                return ${E_INVALID_OPTION}
                ;;
            *)
                echo "error: unexpected argument: ${1}" >&2
                return ${E_INVALID_OPTION}
                ;;
        esac
        shift 1
    done

    echo "${message}"
}


## main ########################################################################
################################################################################

function main() {
    parse-args "${@}" || return ${?}

    debug-vars ACTION ACTION_ARGS DO_COLORS DO_SILENT

    local exit_code=${E_SUCCESS}

    # Find the action function
    local action_func="__action-${ACTION}"

    # Verify the action function exists
    if type -t "${action_func}" &>/dev/null; then
        # Call the action function
        "${action_func}" "${ACTION_ARGS[@]}"
        exit_code=${?}
    else
        echo "error: no such action function found: ${ACTION}" >&2
        exit_code=${E_INVALID_ACTION}
    fi

    return ${exit_code}
}


## run #########################################################################
################################################################################

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "${@}"
