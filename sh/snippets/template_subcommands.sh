#!/usr/bin/env bash
#
# This script does some stuff with subcommands
#
# A couple of solid guiding principles:
# * **"One contiguous block"**: implementation should be designed such that
#   adding any feasible, remotely possible future updates should only require
#   updating a single contiguous block of code. If a future change would require
#   updating multiple places, consider better design strategies.
# * **Helpful functions are helpful**: create helper functions where it reduces
#   the complexity of parent code, improves clarity (e.g.:
#   `calculate-derivative ...` is easier to read and understand vs parsing and
#   understanding several lines of code to do the same), removes duplicated
#   logic, or even just the future potential of duplicated logic. Ideally, all
#   functions (except help functions) are <50 lines. Also, favor long and
#   explicit and self-documenting function names.


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

function silence-output() {
    :  'Silence all script output'
    exec 3>&1 4>&2 1>/dev/null 2>&1
}

function restore-output() {
    :  'Restore script output after a call to `silence-output`'
    [[ -t 3 ]] && exec 1>&3 3>&-
    [[ -t 4 ]] && exec 2>&4 4>&-
}

function trap-exit() {
    :  'An exit trap to restore output on script end'
    restore-output
}
trap trap-exit EXIT


## colors ######################################################################
################################################################################

# Determine if we're in a terminal
[[ -t 1 ]] && __IN_TERMINAL=true || __IN_TERMINAL=false

function setup-colors() {
    :  'Set up color variables'
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
    
    # {{TODO: ADD LABEL/CATEGORY COLORS HERE, e.g.: C_HEADER}}
}

function unset-colors() {
    :  'Unset color variables'
    C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_MAGENTA='' C_CYAN='' C_WHITE=''
    S_RESET='' S_BOLD='' S_DIM='' S_UNDERLINE='' S_BLINK='' S_INVERT='' S_HIDDEN=''
}


## usage functions #############################################################
################################################################################

function help-usage() {
    :  'Print brief usage'
    # {{TODO: UPDATE USAGE}}
    echo "usage: $(basename "${0}") [-h] [--help] [-c <when>] [-s] <action> [<args>]"
}

function help-epilogue() {
    :  'Print a brief description of the script'
    # {{TODO: UPDATE EPILOGUE}}
    echo "run subcommands with individual options"
}

function help-full() {
    :  'Print full help'
    help-usage
    help-epilogue
    echo
    echo "Actions:"
    cat << '    EOF'
    {{TODO: INSERT ACTIONS HERE}}
    help                      display help for a specific action
    EOF
    echo
    echo "Base Options:"
    cat << '    EOF'
    -h                        display usage
    --help                    display this help message
    --config-file <file>      use the specified configuration file
    -c/--color <when>         when to use color ("auto", "always", "never")
    -s/--silent               suppress all output
    {{TODO: INSERT BASE OPTIONS HERE}}
    EOF
    echo
    echo "For action-specific help, run:"
    echo "    $(basename "${0}") <action> --help"
}

function parse-args() {
    :  'Parse command-line arguments for the base command'
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
    DO_COLOR=false
    DO_SILENT=false
    ACTION=""
    ACTION_ARGS=()
    local -- __color_when="${COLOR:-auto}" # auto, on, yes, always, off, no, never

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
                __color_when="${2}"
                shift 1
                ;;
            -s | --silent)
                DO_SILENT=true
                ;;
            # {{TODO: INSERT BASE OPTIONS HERE}}
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

    # Collect remaining arguments for the action
    ACTION_ARGS=("${@}")

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
        case "${__color_when}" in
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
                echo "error: invalid color mode: ${__color_when}" >&2
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

# {{TODO: REMOVE THIS AND ADD HELPER FUNCTIONS HERE}}
function do-stuff() {
    :  'Do stuff, optionally to an argument'
    local -- __target="${1}"

    echo -n "i'm doin the stuff"
    if [[ -n "${__target}" ]]; then
        echo " to ${C_CYAN}${__target}${S_RESET}"
    else
        echo
    fi
}


## action functions ############################################################
################################################################################

### help action ################################################################

function __action-help-help() {
    :  'Print help for the help action'
    echo "usage: $(basename "${0}") help [<action>]"
    echo
    echo "Display help for the specified action or for $(basename "${0}") if no"
    echo "action is specified."
}

function __action-help-parse-args() {
    :  'Parse arguments for the help action'
    HELP_ACTION=""

    while [[ ${#} -gt 0 ]]; do
        case ${1} in
            -h | --help)
                __action-help-help
                exit ${E_SUCCESS}
                ;;
            -*)
                echo "error: unknown option: ${1}" >&2
                return ${E_INVALID_OPTION}
                ;;
            *)
                HELP_ACTION="${1}"
                ;;
        esac
        shift 1
    done

    return ${E_SUCCESS}
}

function __action-help() {
    :  'Display help for the specified action'
    local -- __help_func

    if [[ -n "${HELP_ACTION}" ]]; then
        __help_func="__action-${HELP_ACTION}-help"
        if type -t "${__help_func}" &>/dev/null; then
            "${__help_func}"
        else
            echo "error: no help found for action: ${HELP_ACTION}" >&2
            return ${E_INVALID_ACTION}
        fi
    else
        help-full
    fi
}


### {{TODO: INSERT ACTIONS HERE}} #############################################

### example action #############################################################

function __action-example-help() {
    :  'Print help for the example action'
    echo "usage: $(basename "${0}") example [-m/--message <msg>] [<target>]"
    echo
    echo "Do the example thing."
    echo
    echo "Options:"
    cat << '    EOF'
    -h/--help            display this help message
    -m/--message <msg>   the message to print (default: "hello world")
    EOF
    echo
    echo "Arguments:"
    cat << '    EOF'
    <target>             optional target to do stuff to
    EOF
}

function __action-example-parse-args() {
    :  'Parse arguments for the example action'
    # Default values
    EXAMPLE_MESSAGE="hello world"
    EXAMPLE_TARGET=""

    while [[ ${#} -gt 0 ]]; do
        case ${1} in
            -h | --help)
                __action-example-help
                exit ${E_SUCCESS}
                ;;
            -m | --message)
                EXAMPLE_MESSAGE="${2}"
                shift 1
                ;;
            -*)
                echo "error: unknown option: ${1}" >&2
                return ${E_INVALID_OPTION}
                ;;
            *)
                EXAMPLE_TARGET="${1}"
                ;;
        esac
        shift 1
    done

    return ${E_SUCCESS}
}

function __action-example() {
    :  'Run the example action'
    echo "${EXAMPLE_MESSAGE}"
    if [[ -n "${EXAMPLE_TARGET}" ]]; then
        do-stuff "${EXAMPLE_TARGET}"
    fi
}


## main ########################################################################
################################################################################

function main() {
    parse-args "${@}" || return ${?}

    debug-vars ACTION ACTION_ARGS DO_COLOR DO_SILENT

    local -- __exit_code=${E_SUCCESS}
    local -- __action_func="__action-${ACTION}"
    local -- __parse_func="__action-${ACTION}-parse-args"

    # Verify the action function exists
    if ! type -t "${__action_func}" &>/dev/null; then
        echo "error: unknown action: ${ACTION}" >&2
        return ${E_INVALID_ACTION}
    fi

    # Parse action-specific arguments if a parser exists
    if type -t "${__parse_func}" &>/dev/null; then
        "${__parse_func}" "${ACTION_ARGS[@]}" || return ${?}
    fi

    # Call the action function
    "${__action_func}"
    __exit_code=${?}

    return ${__exit_code}
}


## run #########################################################################
################################################################################

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "${@}"
