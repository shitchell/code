#!/usr/bin/env bash
#
# This program will run a bash script in a verbose sort of manner:
#   - read line by line
#   - print comments as dark gray
#   - if a non-comment line is found, store it in a variable
#   - continue reading lines and storing them until a blank line is found
#   - once a blank line is found, run the stored lines as a bash script
#   - repeat until the end of the file is reached

# Set some default values
SCRIPT_NAME=""
SCRIPT_PATH=""
BLANK_LINE_DELIMITERS=1 # how many blank lines to separate code blocks
__PAGER="less -RF"
DO_COLOR=true # whether to syntax highlight the output
DO_SHOW_INDEX=false # whether to show the code block index
DO_ENTER_PAUSE=false

# Parse command line arguments
while [[ ${#} -gt 0 ]]; do
    case "${1}" in
        -h | --help)
            echo "usage: $(basename "${0}") [-h] [-n <num>] [-p] <script>"
            echo
            echo "Run a bash script in a verbose sort of manner:"
            echo "  - read line by line"
            echo "  - print comments as dark gray"
            echo "  - if a non-comment line is found, store it in a buffer"
            echo "  - continue reading lines and storing them until a blank line is found"
            echo "  - once a blank line is found, run the buffer as a bash script"
            echo "  - repeat until the end of the file is reached"
            echo
            echo "Syntax highlighting is available if color is enabled and one of the"
            echo "following programs is installed:"
            echo "  - source-highlight"
            echo "  - highlight"
            echo "  - pygmentize"
            echo
            echo "positional arguments:"
            echo "  script                      the script to run"
            echo
            echo "optional arguments:"
            echo "  -h, --help                  show this help message and exit"
            echo "  -e, --empty-lines <num>     how many blank lines to separate code blocks"
            echo "  --paging <on|off|auto>      whether to page the output"
            echo "  -p, --page                  page the output, alias for --paging on"
            echo "  -P, --no-page               don't page the output, alias for --paging off"
            echo "  -A, --auto-page             page the output if the number of lines exceeds"
            echo "                              the terminal height, alias for --paging auto"
            echo "  -E, --enter-pause           pause after each code block (implies -P)"
            echo "  -c, --color                 colorize the output"
            echo "  -C, --no-color              don't colorize the output"
            echo "  -b, --show-block-index      show the code block index"
            exit 0
            ;;
        -e | --empty-lines)
            BLANK_LINE_DELIMITERS="${2}"
            shift
            ;;
        --paging)
            if [[ "${2}" == "on" || "${2}" == "true" ]]; then
                __PAGER="${PAGER:- less -FR}"
            elif [[ "${2}" == "off" || "${2}" == "false" ]]; then
                __PAGER="cat"
            elif [[ "${2}" == "auto" ]]; then
                __PAGER="autopage"
            else
                echo "error: invalid argument for --paging: ${2}"
                exit 1
            fi
            DO_PAGE=true
            ;;
        -p | --page)
            __PAGER="${PAGER:- less -R}"
            ;;
        -P | --no-page)
            __PAGER="cat"
            ;;
        -A | --auto-page)
            __PAGER="less -FR"
            DO_ENTER_PAUSE=false
            ;;
        -E | --enter-pause)
            DO_ENTER_PAUSE=true
            __PAGER="cat"
            ;;
        -c | --color)
            DO_COLOR=true
            ;;
        -C | --no-color)
            DO_COLOR=false
            ;;
        -b | --show-block-index)
            DO_SHOW_INDEX=true
            ;;
        -B | --no-show-block-index)
            DO_SHOW_INDEX=false
            ;;
        -*)
            echo "error: unrecognized option: ${1}"
            exit 1
            ;;
        *)
            SCRIPT_NAME="${1}"
            ;;
    esac
    shift
done

# If a script name was not provided, print an error and exit
if [[ -z "${SCRIPT_NAME}" ]]; then
    echo "usage: $(basename "${0}") <script>"
    exit 1
fi

SCRIPT_PATH="$(realpath "${SCRIPT_NAME}")"

# Set up colors if enabled
if ${DO_COLOR}; then
    C_RESET="\033[0m"
    C_DARK_GRAY="\033[1;30m"
    C_BOLD="\033[1m"
    C_GREEN="\033[0;32m"

    # Syntax highlighting
    if command -v source-highlight &> /dev/null; then
        COLORIZER=("source-highlight" "--failsafe" "-f" "esc" "-s" "bash")
    elif command -v highlight &> /dev/null; then
        COLORIZER=("highlight" "-O" "ansi" "-S" "bash")
    elif command -v pygmentize &> /dev/null; then
        COLORIZER=("pygmentize" "-f" "terminal256" "-O" "style=monokai")
    else
        COLORIZER=("printf" "${C_GREEN}%s${C_RESET}\n")
    fi
else
    COLORIZER=("cat")
fi

# @description Print a debug message if DEBUG or DEBUG_LOG is set
# @usage debug <msg> [<msg> ...]
function debug() {
    local prefix timestamp
    if [[ "${DEBUG}" == "1" || "${DEBUG}" == "true" || -n "${DEBUG_LOG}" ]]; then
        timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
        prefix="\033[36m[${timestamp}]\033[0m "
        prefix+="\033[35m$(basename "${BASH_SOURCE[-1]}")"
        [[ "${FUNCNAME[1]}" != "main" ]] && prefix+="\033[1m:${FUNCNAME[1]}()\033[0m"
        prefix+="\033[32m:${BASH_LINENO[0]}\033[0m -- "
        printf "%s\n" "${@}" \
            | awk -v prefix="${prefix}" '{print prefix $0}' >> "${DEBUG_LOG:- /dev/stderr}"
    fi
}

# Function for paging output if the number of lines exceeds the terminal height
function autopage() {
    local filepath="${1:- /dev/stdin}"
    local term_height=$(tput lines)
    local buffer="" line=""
    local line_count=0

    # Fille the buffer until all input has been read or the number of lines in
    # the buffer exceeds the terminal height
    while IFS= read -r line || [[ -n "${line}" ]]; do
        buffer="${buffer}${line}"$'\n'
        let line_count++
        if [[ ${line_count} -gt ${term_height} ]]; then
            break
        fi
    done < "${filepath}"

    # If the number of lines in the buffer exceeds the terminal height, use the
    # default pager to display the buffer, otherwise just print the buffer to
    # stdout
    if [[ ${line_count} -gt ${term_height} ]]; then
        (
            printf '%s' "${buffer}"
            cat <"${filepath}"
        ) | ${PAGER:- less -RF}
    else
        printf '%s' "${buffer}"
    fi
}

# code buffer
CODE_BUFFER=()

# Define a function to print a line of text in dark gray
function print_comment() {
    printf "${C_DARK_GRAY}%s${C_RESET}\n" "${@}"
}

# Define a function to print code in green
function print_code() {
    local block=""
    local code_lines=()
    local prefix=""
    local colorizer=("cat")
    local start_color="${C_GREEN}" end_color="${C_RESET}"

    # Parse arguments
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            --block)
                block="${2}"
                shift 1
                ;;
            --colorizer)
                colorizer=("${2}")
                shift 1
                ;;
            --start-color)
                start_color="${2}"
                shift 1
                ;;
            --end-color)
                end_color="${2}"
                shift 1
                ;;
            *)
                code_lines+=("${1}")
                ;;
        esac
        shift 1
    done

    # Check if bash highlighting is available
    if command -v source-highlight &> /dev/null; then
        colorizer=("source-highlight" "--failsafe" "-f" "esc" "-s" "bash")
        start_color="" end_color=""
    elif command -v highlight &> /dev/null; then
        colorizer=("highlight" "-O" "ansi" "-S" "bash")
        start_color="" end_color=""
    elif command -v pygmentize &> /dev/null; then
        colorizer=("pygmentize" "-f" "terminal256" "-O" "style=monokai")
        start_color="" end_color=""
    fi

    # If a block is provided, use it in the prefix
    if [[ -n "${block}" ]]; then
        prefix="[${block}] > "
    else
        prefix="> "
    fi
    printf "${start_color}%s${end_color}\n" "${code_lines[@]}" \
        | "${colorizer[@]}" \
        | awk -v prefix="${prefix}" '{print prefix $0}'
}

# Create a temporary directory to run in, move into it, and setup a trap to
# delete it when we're done.
tmp_dir=$(mktemp -d)
cd "${tmp_dir}"
trap "rm -rf '${tmp_dir}'" EXIT

{
    # Print the script name in bold
    echo -e "${C_BOLD}${SCRIPT_NAME}${C_RESET}"

    # Read the file line by line
    let code_block_count=0
    let line_num=0
    let blank_line_count=0
    tmp_file=$(mktemp)
    trap "rm -f '${tmp_file}'" EXIT
    print_code_args=()
    readarray -t lines < "${SCRIPT_PATH}"
    for line in "${lines[@]}"; do
        let line_num++

        # Check if the line is blank
        is_blank=false
        if echo "${line}" | grep -qE '^[[:space:]]*$'; then
            # If the line is blank, increment the blank line count
            let blank_line_count++
            is_blank=true
        else
            # If the line is not blank, reset the blank line count
            blank_line_count=0
        fi

        if [[ "${line}" =~ ^[[:space:]]*"#" && ${#CODE_BUFFER[@]} -eq 0 ]]; then
            # If the line is a comment, and we're not in a code block, print it
            print_comment "${line}"
        elif ! ${is_blank}; then
            # If the line is not a blank line, store it in the code buffer
            CODE_BUFFER+=("${line}")
        elif [[ -z "${line}" ]]; then
            if [[
                ${#CODE_BUFFER[@]} -gt 0
                && ${blank_line_count} -ge ${BLANK_LINE_DELIMITERS}
            ]]; then
                # Print the code
                ${DO_SHOW_INDEX} && print_code_args+=("--block" "${code_block_count}")
                print_code "${print_code_args[@]}" "${CODE_BUFFER[@]}"

                # Run the buffer as a bash script
                debug "running code block ${code_block_count} -- ${CODE_BUFFER[@]}}"
                printf "%s\n" "${CODE_BUFFER[@]}" > "${tmp_file}"
                source "${tmp_file}"
                # eval "$(printf "%s\n" "${CODE_BUFFER[@]}")" 2>&1
                debug "finished running code block ${code_block_count}"

                # Clear the buffer
                CODE_BUFFER=()

                # Increment the code block count
                let code_block_count++
            fi

            # Echo the blank line
            echo
        fi
    done

    # If we have code left in the buffer, print and run it
    if [[ ${#CODE_BUFFER[@]} -gt 0 ]]; then
        # Print the code
        ${DO_SHOW_INDEX} && print_code_args+=("--block" "${code_block_count}")
        print_code "${print_code_args[@]}" "${CODE_BUFFER[@]}"

        # Run the buffer as a bash script
        eval "$(printf "%s\n" "${CODE_BUFFER[@]}")"

        # Clear the buffer
        CODE_BUFFER=()

        # Increment the code block count
        let code_block_count++
    fi
} |& ${__PAGER}
