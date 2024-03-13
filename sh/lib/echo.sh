include-source 'shell.sh'
include-source 'text.sh'

# Colors!
C_BLACK="\033[30m"
C_RED="\033[31m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_BLUE="\033[34m"
C_MAGENTA="\033[35m"
C_CYAN="\033[36m"
C_WHITE="\033[37m"
C_RGB="\033[38;2;%d;%d;%dm"
C_DEFAULT_FG="\033[39m"
C_BLACK_BG="\033[40m"
C_RED_BG="\033[41m"
C_GREEN_BG="\033[42m"
C_YELLOW_BG="\033[43m"
C_BLUE_BG="\033[44m"
C_MAGENTA_BG="\033[45m"
C_CYAN_BG="\033[46m"
C_WHITE_BG="\033[47m"
C_RGB_BG="\033[48;2;%d;%d;%dm"
C_DEFAULT_BG="\033[49m"
S_RESET="\033[0m"
S_BOLD="\033[1m"
S_DIM="\033[2m"
S_ITALIC="\033[3m"  # not widely supported, sometimes treated as inverse
S_UNDERLINE="\033[4m"
S_BLINK="\033[5m"  # slow blink
S_BLINK_FAST="\033[6m"  # fast blink
S_REVERSE="\033[7m"
S_HIDDEN="\033[8m"  # not widely supported
S_STRIKETHROUGH="\033[9m"  # not widely supported
S_DEFAULT="\033[10m"


# echos each argument based on the preceding argument:
#   -g: green
#   -r: red
#   -b: blue
#   -p: purple
#   -c: cyan
#   -B: bold
#   -R: reverse
#   -U: underline
#   -K: blinking
#   --: reset to default color
# other options:
#   -n: do not echo a newline
#   -V <level>: only echo if the global VERBOSITY is >= <level>
function echo-formatted() {
    local code_r="${C_RED}"
    local code_g="${C_GREEN}"
    local code_y="${C_YELLOW}"
    local code_b="${C_BLUE}"
    local code_p="${C_MAGENTA}"
    local code_m="${C_MAGENTA}"
    local code_c="${C_CYAN}"
    local code_w="${C_WHITE}"
    local code_B="${S_BOLD}"
    local code_D="${S_DIM}"
    local code_R="${S_REVERSE}"
    local code_U="${S_UNDERLINE}"
    local code_K="${S_BLINK}"
    local code_reset="${S_RESET}"

    # determine if we should print a newline at the end
    local print_newline=1

    # check ECHO_FORMATTED to determine if we should colorize output in a tty
    # TODO: make this configurable via command line arguments
    local format_when="${ECHO_FORMATTED:-auto}"

    # if ECHO_FORMATTED is set to "auto", then colorize if we are in a tty
    local do_format
    if [ "${format_when}" = "auto" ]; then
        if [ -t 1 ]; then
            do_format=1
        else
            do_format=0
        fi
    elif [ "${format_when}" = "always" ]; then
        do_format=1
    else
        do_format=0
    fi

    # loop over each argument
    local verbosity_level=1
    local is_first_argument=1
    local last_printable_argument=""
    local has_printed_anything=0
    while [[ ${#} -gt 0 ]]; do
        local arg="${1}"

        shift 1
        # if the argument starts with a dash, use it as the color code
        if [ "${arg:0:1}" = "-" ]; then
            if [ ${do_format} -eq 1 ]; then
                # if it's a reset code, reset the color code
                if [ "${arg}" = "--" ]; then
                    if (is-int ${VERBOSITY} && [ ${verbosity_level} -le ${VERBOSITY} ]) \
                    || ! is-int ${VERBOSITY}; then
                        printf "%b" "${code_reset}"
                    fi
                elif [ "${arg}" = "-n" ]; then
                    print_newline=0
                elif [ "${arg}" = "-V" ]; then
                    # use the second arg as the verbosity level at which to print
                    if is-int "${1}"; then
                        local verbosity_level="${1}"
                    else
                        echo-stderr "echo-formatted: invalid verbosity level '${1}'"
                        return 1
                    fi
                    shift 1
                    continue
                else
                    # otherwise, loop over each character in the argument
                    local arg_chars
                    [[ "${arg}" =~ ${arg//?/(.)} ]]
                    arg_chars=("${BASH_REMATCH[@]:2}")
                    for char in "${arg_chars[@]}"; do
                        # set the color code based on the character
                        local color_code="code_${char}"
                        # echo the color code
                        if (is-int ${VERBOSITY} && [ ${verbosity_level} -le ${VERBOSITY} ]) \
                        || ! is-int ${VERBOSITY}; then
                            # ensure the color code is defined
                            if [ -n "${!color_code}" ] >/dev/null 2>&1; then
                                printf "%b" "${!color_code}"
                            fi
                        fi
                    done
                fi
            fi
        else
            # if this is not the first argument, and the last argument wasn't
            # whitespace, and the current argument isn't whitespace, echo a
            # space
            if [ ${is_first_argument} -eq 0 ] \
            && ! [[ "${last_printable_argument}" =~ ^[[:space:]]$ ]] \
            && ! [[ "${arg}" =~ ^[[:space:]]$ ]]; then
                if (is-int ${VERBOSITY} && [ ${verbosity_level} -le ${VERBOSITY} ]) \
                || ! is-int ${VERBOSITY}; then
                    printf " "
                fi
            else
                is_first_argument=0
            fi

            # if the argument starts with an escaped dash, remove the backslash
            if [ "${arg:0:2}" = "\\-" ]; then
                arg="${arg:1}"
            fi

            # print the arg
            if (is-int ${VERBOSITY} && [ ${verbosity_level} -le ${VERBOSITY} ]) \
            || ! is-int ${VERBOSITY}; then
                printf "%s" "${arg}"
                has_printed_anything=1
            fi
            # store the last printable argument
            last_printable_argument="${arg}"
        fi
    done

    # # if piped data is available, echo it
    # if test -t 0; then
        # if (is-int ${VERBOSITY} && [ ${verbosity_level} -le ${VERBOSITY} ]) \
        # || ! is-int ${VERBOSITY}; then
            # local piped_data=$(cat -)
            # printf "%s" "${piped_data}"
            # has_printed_anything=1
        # fi
    # fi

    # echo the reset code
    if [ ${do_format} -eq 1 ]; then
        printf "%b" "${code_reset}"
    fi

    # echo a newline
    if [ ${print_newline} -eq 1 ]; then
        if (is-int ${VERBOSITY} && [ ${verbosity_level} -le ${VERBOSITY} ]) \
        || ! is-int ${VERBOSITY} \
        || [ ${has_printed_anything} -eq 1 ]; then
            echo
        fi
    fi
}

# echo a command before running it, printing an error message if it exited with
# a non-zero status
# echo a command before running it
function echo-run() {
    local cmd=("${@}")
    local exit_code

    # echo the command...
    printf "\033[32m\u25b6 \033[1m%s\033[0m" "${cmd[0]}"
    # ...if there is more than one argument, print them
    if [[ ${#cmd[@]} -gt 1 ]]; then
        printf "\033[32m%s\033[0m" "$(printf " %q" "${cmd[@]:1}")"
    fi
    echo

    # if we only have one argument and it contains a space, run it with eval
    if [[ ${#cmd[@]} -eq 1 && "${cmd[0]}" =~ " " ]]; then
        cmd=(eval "${cmd[0]}")
    fi
    # run the command, prepending each line of output with a vertical bar
    "${cmd[@]}" 2>&1 | sed -e '$ ! s/^/\x1b[32m\xe2\x94\x82\x1b[0m / ; $ s/^/\x1b[32m\xe2\x95\xb0\x1b[0m /'
    exit_code=${PIPESTATUS[0]}

    # oh no errors
    if [[ ${exit_code} -ne 0 ]]; then
        echo -e "\033[31mcommand exited with status ${exit_code}\033[0m"
    fi

    # return its exit code
    return ${exit_code}
}

# echo something to stdout in cyan
function echo-comment() {
    echo-formatted -cB "${@}"
}

# echo something to stdout in green
function echo-command() {
    echo-formatted "\$" -g "$(echo ${@})"
}

# echo something to stdout in yellow
function echo-warning() {
    echo-formatted -y "${@}"
}

# echo something to stdout in red
function echo-error() {
    echo-formatted -r "${@}"
}

# echo something to stderr in red
function echo-stderr() {
    echo-formatted -r "${@}" >&2
}

# echo something to stdout in blue
function echo-success() {
    echo-formatted -b "${@}"
}

# usage: check-command command [message]
# usage: check-command command message output_var
# usage: check-command message command stdout_var stderr_var
# Prints "${message} ... ", runs ${command}, prints "Done" or "Error" based on
# the exit code of the command. Stores the output ${command} in ${output_var}
function check-command() {
    local command="${1}"
    local message="${2}"
    local stdout_var="${3}"
    local stderr_var="${4}"
    local combine_output=0

    # If the message is empty, use the command as the message
    if [ -z "${message}" ]; then
        message="Running \`${command}\`"
    fi

    local out_dir="$(mktemp -dt ccomm.${$}.XXXX)"
    local stdout_file="${out_dir}/stdout"
    if [ -n "${stderr_var}" ]; then
        local stderr_file="${out_dir}/stderr"
    else
        # if only stdout is provided, combine stdout and stderr
        local stderr_file="${stdout_file}"
    fi

    echo -n "${message} ... "

    # run the command
    eval "(${command})" 1>>${stdout_file} 2>>${stderr_file}
    exit_code="$?"

    # print a status message based on the exit code
    if [ ${exit_code} -eq 0 ]; then
        echo-success "Done"
    else
        echo-error "Error"
    fi

    # store the output in the specified variables
    # TODO: this isn't exporting the variable for external use for some reason
    read -r -d '' ${stdout_var} < ${stdout_file}
    if [ -n "${stderr_var}" ]; then
        read -r -d '' ${stderr_var} < ${stderr_file}
    fi

    # clean up temporary files
    rm -rf ${out_dir}

    return ${exit_code}
}

# Print the given message depending on the VERBOSITY environment variable.
# Any arguments passed first are passed to echo.
# usage:
#   echo-managed <output-level> <message>
#   echo-managed <message>
#   echo-managed -n 2 "this will be displayed only if the verbosity is 2 or higher"
#   echo-managed -n "this will be displayed only if the verbosity is 1 or higher"
function echo-managed() {
    local echo_args=()
    local verbosity_level=1
    local message

    # loop over each argument and, if it starts with a dash, add it to the list
    # of options to pass to echo.
    for arg in "${@}"; do
        if [ "${arg:0:1}" = "-" ]; then
            echo_args+=("${arg}")
            shift
        else
            break
        fi
    done

    # determine if the first argument after any echo args is an int
    if [[ "${1}" =~ ^[0-9]+$ ]]; then
        # if the first argument is an int, set the verbosity level
        verbosity_level="${1}"
        shift
    fi

    # get the rest of the arguments as the message
    message="${@}"

    # if the specified verbosity level is less than or equal to the current
    # verbosity level, print the message
    if [[ ${verbosity_level} -le ${VERBOSITY} ]]; then
        echo ${echo_args} "${message}"
    fi
}
