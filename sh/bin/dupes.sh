#!/usr/bin/env bash
#
# Find duplicate files


## imports #####################################################################
################################################################################

include-source 'debug.sh'


## exit codes ##################################################################
################################################################################

declare -ri E_SUCCESS=0
declare -ri E_ERROR=1


## traps #######################################################################
################################################################################

function trap-exit() {
    echo -e "\nexiting"
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
    echo "usage: $(basename "${0}") [-h]"
}

function help-epilogue() {
    echo "do stuff"
}

function help-full() {
    help-usage
    help-epilogue
    echo
    echo "When deleting duplicates, one of each set of duplicates is kept. The"
    echo "duplicate to keep is determined by the retention mode. The default"
    echo "retention mode is \`first\`, which keeps the first duplicate found."
    echo "The available retention modes are:"
    echo "  - first: keep the first duplicate found"
    echo "  - last: keep the last duplicate found"
    echo "  - largest: keep the duplicate with the largest file size"
    echo "  - newest: keep the most recently modified duplicate"
    echo "  - oldest: keep the least recently modified duplicate"
    echo
    echo "Options:"
    cat << EOF
    -h                     display usage
    --help                 display this help message
    -c/--color <mode>      the color mode to use (yes, no, auto)
    -s/--stat              print file stats
    -x/--exclude <regex>   exclude filepaths matching <regex>
    -d/--max-depth <int>   the maximum depth to search
    -b/--bytes <int>       only read the first <int> bytes of each file
    -a/--all               do not ignore hidden files
    -A/--almost-all        ignore hidden files
    -d/--delete            delete all but one of each set of duplicates
    -r/--retention <mode>  the retention mode to use when deciding which
                           duplicate to keep (see above)
EOF
}

function parse-args() {
    # Default values
    FILEPATHS=()
    DO_STAT=false
    DO_COLOR=false
    EXCLUDE_PATTERNS=()
    MAX_DEPTH="" # empty means no max depth
    MAX_BYTES="" # empty means read the whole file
    DO_IGNORE_HIDDEN=true
    DO_DELETE=false
    RETENTION_MODE="first"

    local color_mode="auto" # a temporary variable to hold the color mode
    
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
                color_mode="${2}"
                shift 2
                ;;
            -s | --stat)
                DO_STAT=true
                shift 1
                ;;
            -x | --exclude)
                EXCLUDE_PATTERNS+=("${2}")
                shift 2
                ;;
            -d | --max-depth)
                MAX_DEPTH="${2}"
                shift 2
                ;;
            -b | --bytes)
                MAX_BYTES="${2}"
                shift 2
                ;;
            -a | --all)
                DO_IGNORE_HIDDEN=false
                shift 1
                ;;
            -A | --almost-all)
                DO_IGNORE_HIDDEN=true
                shift 1
                ;;
            -d | --delete)
                DO_DELETE=true
                shift 1
                ;;
            -r | --retention)
                RETENTION_MODE="${2}"
                shift 2
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
                shift 1
                ;;
        esac
    done

    # If -- was used, collect the remaining arguments
    while [[ ${#} -gt 0 ]]; do
        FILEPATHS+=("${1}")
        shift 1
    done

    # Validate the color mode and set up colors
    case "${color_mode}" in
        yes | true | on | always)
            DO_COLOR=true
            ;;
        no | false | off | never)
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
            echo "error: invalid color mode: ${color_mode}" >&2
            return ${E_ERROR}
            ;;
    esac
    ${DO_COLOR} && setup-colors

    # Validate the max depth
    if [[ -n "${MAX_DEPTH}" ]]; then
        if [[ ! "${MAX_DEPTH}" =~ ^[0-9]+$ || ${MAX_DEPTH} -lt 0 ]]; then
            echo "error: invalid max depth: ${MAX_DEPTH}" >&2
            return ${E_ERROR}
        fi
    fi

    # Validate the max bytes
    if [[ -n "${MAX_BYTES}" ]]; then
        if [[ ! "${MAX_BYTES}" =~ ^[0-9]+$ || ${MAX_BYTES} -lt 0 ]]; then
            echo "error: invalid max bytes: ${MAX_BYTES}" >&2
            return ${E_ERROR}
        fi
    fi

    # Validate the retention mode
    if [[ -n "${RETENTION_MODE}" ]]; then
        case "${RETENTION_MODE}" in
            first | last | largest | newest | oldest)
                ;;
            *)
                echo "error: invalid retention mode: ${RETENTION_MODE}" >&2
                return ${E_ERROR}
                ;;
        esac
    fi

    debug-vars FILEPATHS DO_STAT DO_COLOR EXCLUDE_PATTERNS MAX_DEPTH MAX_BYTES \
        DO_IGNORE_HIDDEN DO_DELETE RETENTION_MODE
    
    return ${E_SUCCESS}
}


## helpful functions ###########################################################
################################################################################

set -o allexport

# @description Generate an md5 hash of a file
# @usage md5 <file> [<max bytes>]
function md5() {
    local filepath="${1}"
    local max_bytes="${2}"

    # Generate the hash
    local hash
    if [[ -n "${max_bytes}" ]]; then
        hash=$(head -c "${max_bytes}" "${filepath}" | md5sum | cut -d ' ' -f 1)
    else
        hash=$(md5sum "${filepath}" | cut -d ' ' -f 1)
    fi

    # Print the hash and the filepath
    echo "${hash}  ${filepath}"
}

set +o allexport


## main ########################################################################
################################################################################

function main() {
    parse-args "${@}" || return ${?}

    # Craft the find command
    local find_cmd=(find "${FILEPATHS[@]}")
    [[ -n "${MAX_DEPTH}" ]] && find_cmd+=(-maxdepth "${MAX_DEPTH}")
    [[ ${DO_IGNORE_HIDDEN} == true ]] && find_cmd+=(-not -path '*/\.*')
    find_cmd+=(-type f -print0)

    # Find the files and generate hashes
    declare -A hashes=()
    local count=0
    while read -d $'\0' filepath; do
        echo -en "\rScanning files (${count})" >&2

        # Check if the file should be excluded
        for pattern in "${EXCLUDE_PATTERNS[@]}"; do
            if [[ "${filepath}" =~ ${pattern} ]]; then
                debug "excluding '${filepath}'"
                continue 2
            fi
        done

        # Generate the hash
        local md5_info=$(md5 "${filepath}" "${MAX_BYTES}")
        local md5_hash="${md5_info:0:32}"

        # Add the file to the hashes array
        if [[ -n "${hashes[${md5_hash}]}" ]]; then
            hashes[${md5_hash}]="${hashes[${md5_hash}]}${filepath}"$'\0'
        else
            hashes[${md5_hash}]="${filepath}"$'\0'
        fi

        let count++
    done < <("${find_cmd[@]}")
    echo

    debug-vars hashes count

    # Process the hashes
    for hash in "${!hashes[@]}"; do
        # Split the filepaths into an array
        IFS=$'\0' read -r -d '' -a filepaths <<< "${hashes[${hash}]}"

        # If there is only one file, skip it
        if [[ ${#filepaths[@]} -eq 1 ]]; then
            debug "skipping '${filepaths[0]}' -- no duplicates found"
            continue
        fi

        # Print the hash and duplicate count
        echo "${hash}  (${#filepaths[@]})"

        # Print the filepaths
        for filepath in "${filepaths[@]}"; do
            echo "  ${filepath}"
        done
    done
}


## run #########################################################################
################################################################################

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "${@}"
