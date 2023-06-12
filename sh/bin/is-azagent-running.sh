#!/usr/bin/env bash
#
# Returns whether or not the Azure DevOps agent is running

## imports #####################################################################
################################################################################

include-source 'echo.sh'
include-source 'debug.sh'


## usage functions #############################################################
################################################################################

function help-full() {
    help-usage
    help-epilogue
    echo
    cat << EOF
    -h/--help               display this help message
    -r/--root <path>        the root directory of the agent
    -s/--service <name>     the name of the agent service
EOF
}

function help-usage() {
    echo "usage: $(basename "${0}") [-h] [-r <path>] [-s <name>]"
}

function help-epilogue() {
    echo "returns whether or not the Azure DevOps agent is running"
}

function parse-args() {
    # Default values
    ROOT_DIR="/opt/azagent"
    SERVICE_NAME=$(
        [[ -f "${ROOT_DIR}/.service" ]] \
            && cat "${ROOT_DIR}/.service" \
            || echo "azagent"
    )

    # Loop over the arguments
    while [[ ${#} -gt 0 ]]; do
        case ${1} in
            -h)
                help-usage
                help-epilogue
                exit 0
                ;;
            --help)
                help-full
                exit 0
                ;;
            -r | --root)
                ROOT_DIR="${2}"
                shift 2
                ;;
            -s | --service)
                SERVICE_NAME="${2}"
                shift 2
                ;;
            *)
                echo-stderr "error: unknown argument '${1}'"
                help-usage
                exit 1
                ;;
        esac
    done
}


## helpful functions ###########################################################
################################################################################

# @description Returns whether the user has root powers
# @usage has-root [user]
function has-root() {
    local user="${1:-$(whoami)}"
    [[ "${user}" == "root" ]] && return 0
    [[ "$(id -u "${user}")" == "0" ]] && return 0
    [[ "$(id -g "${user}")" == "0" ]] && return 0
    return 1
}

## main ########################################################################
################################################################################

function main() {
    parse-args "${@}"
    local is_running=true

    # Check if the service is running (requires root)
    if ! systemctl is-active --quiet "${SERVICE_NAME}"; then
        is_running=false
    else
        # Check if a job is actively being processed
        local job_file="${ROOT_DIR}/_diag/Agent_$(hostname).job"
    fi
}


## run #########################################################################
################################################################################

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "${@}"
