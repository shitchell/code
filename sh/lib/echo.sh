#!/usr/bin/env bash
: '
A collection of commands for printing to the console
'

include-source 'colors.sh'
include-source 'shell.sh'
include-source 'text.sh'

function echo-formatted() {
    :  'Echo with option based ANSI formatting

        Colors are specified using options. The text following that option will
        be styled accordingly. Use "--" to reset the color to the default. If
        any color options are specified, a reset ANSI sequence will be appended
        to the end of the output.

        @usage
            [-n] [-V <level] [-grbpcBRUK] [--] <text>

        @option -n
            Do not echo a newline
        
        @option -V <level>
            Only echo if the global VERBOSITY is >= <level>
        
        @option -g
            Green foreground
        
        @option -r
            Red foreground

        @option -b
            Blue foreground

        @option -p
            Purple foreground

        @option -c
            Cyan foreground

        @option -m
            Magenta foreground

        @option -B
            Bold text

        @option -D
            Dim text

        @option -R
            Reverse text

        @option -U
            Underline text (not widely supported)

        @option -K
            Blinking text

        @option --
            Reset to default color
        
        @arg <text>
            The text to echo
        
        @stdout
            The formatted text
    '
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

function echo-run() {
    :  'Echo a command before running it

        This function will echo the command to stdout before running it. The
        command stdout and stderr are both printed to stdout prefixed with a
        vertical bar. If the command exits with a non-zero status, it will print
        an error message.

        @usage
            <command>

        @arg <command>
            The command to run

        @stdout
            The command and its output, prefixed with a vertical bar
    '
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

function echo-comment() {
    :  'Echo a comment to stdout

        This function will echo a comment to stdout.

        @usage
            <comment>

        @arg <comment>
            The comment to echo

        @stdout
            The comment
    '
    echo-formatted -cB "${@}"
}

function echo-command() {
    :  'Echo a command to stdout

        This function will echo a command to stdout. The command is prefixed
        with a "$".

        @usage
            <command>

        @arg <command>
            The command to echo

        @stdout
            The command
    '
    echo-formatted "\$" -g "${@}"
}

function echo-warning() {
    :  'Echo a warning to stdout

        This function will echo a warning to stdout.

        @usage
            <warning>

        @arg <warning>
            The warning to echo

        @stdout
            The warning
    '
    echo-formatted -y "${@}"
}

function echo-error() {
    :  'Echo an error to stdout

        This function will echo an error to stdout.

        @usage
            <error>

        @arg <error>
            The error to echo

        @stdout
            The error
    '
    echo-formatted -r "${@}"
}

function echo-stderr() {
    :  'Echo to stderr

        This function will echo to stderr in red.

        @usage
            <message>

        @arg <message>
            The message to echo

        @stdout
            The message
    '
    echo-formatted -r "${@}" >&2
}

function echo-success() {
    :  'Echo a success message to stdout

        This function will echo a success message to stdout.

        @usage
            <message>

        @arg <message>
            The message to echo

        @stdout
            The message
    '
    echo-formatted -b "${@}"
}

# usage: check-command command [message]
# usage: check-command command message output_var
# usage: check-command message command stdout_var stderr_var
# Prints "${message} ... ", runs ${command}, prints "Done" or "Error" based on
# the exit code of the command. Stores the output ${command} in ${output_var}
function check-command() {
    :  'Check a command for success

        This function will run a command and print a message based on the exit
        code of the command. If the command exits with a non-zero status, it
        will print an error message. Useful for scripts using the output style:
           * doing this ... done
           * doing that ... done
           * checking this ... error

        @usage
            <command> [<message>]
            <command> <message> <output_var>
            <command> <message> <stdout_var> <stderr_var>

        @arg <command>
            The command to run

        @arg <message>
            The message to print

        @arg <output_var>
            The variable to store the output (stdout & stderr) of the command

        @arg <stdout_var>
            The variable to store the stdout of the command

        @arg <stderr_var>
            The variable to store the stderr of the command

        @stdout
            The message and the output of the command
    '
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
    :  '(deprecated) Print a message based on the VERBOSITY level

        This function will print a message based on the environment VERBOSITY
        level. If the verbosity level is less than the specified level, the
        message will not be printed.

        @usage
            [-n] [<verbosity-level>] <message>

        @option -n
            Do not echo a newline

        @arg <verbosity-level>
            The verbosity level at which to print the message

        @arg <message>
            The message to print

        @stdout
            The message
    '

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

function repeat-char() {
    :  'Repeat a character a given number of times

        This function will print a character a given number of times.

        @usage
            <char> [<count>]

        @arg <char>
            The character to print

        @arg <count>
            The number of times to print the character. Default: 1

        @stdout
            The character repeated the given number of times
    '
    local char="${1}"
    local count="${2:-1}"

    [[ -z "${char}" ]] && return

    for ((i=0; i<count; i++)); do
        printf '%s' "${char}"
    done
}

function print-header() {
    :  'Print a header to the console

        This function will print a header to the console. The header can be
        styled as a bordered header, an underlined header, or a markdown header.

        @usage
            [-B/--before <n>] [-A/--after <n>] [-M/--margin <n>] [--markdown]
            [--level <level>] [--underline] [--border] [--border-width <width>]
            [--border-character <char>] <text>

        @option -B/--before <n>
            Print <n> empty lines before the header

        @option -A/--after <n>
            Print <n> empty lines after the header

        @option -M/--margin <n>
            Print <n> empty lines before and after the header

        @option --markdown
            Style the header as a markdown header

        @option --level
            The level of the markdown header

        @option --underline
            Style the header as an underlined header

        @option --border/--bordered
            Style the header as a bordered header

        @option --border-width <width>
            The width of the border. Default: 80

        @option --border-character <char>
            The character to use for the border. Default: "="

        @arg <text>
            The text to print in the header

        @stdout
            The header
    '

    local args=()
    local header_text=""
    local style="bordered" # "bordered", "markdown", "underlined"
    local markdown_level=1
    local border_character="="
    local _border_width=80 # int, "fit-text" or "fit-terminal"
    local lines_before=0
    local lines_after=1

    # set after parsing args
    local border_width=80 # to be set after parsing args

    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -B | --before)
                lines_before="${2}"
                shift 2
                ;;
            -A | --after)
                lines_after="${2}"
                shift 2
                ;;
            -M | --margin)
                lines_before="${2}"
                lines_after="${2}"
                shift 2
                ;;
            --markdown)
                style="markdown"
                shift 1
                ;;
            --level)
                markdown_level="${2}"
                shift 2
                ;;
            --underline | --underlined)
                style="underlined"
                shift 1
                ;;
            --border | --bordered)
                style="bordered"
                shift 1
                ;;
            --border-width)
                _border_width="${2}"
                shift 2
                ;;
            --border-character)
                border_character="${2}"
                shift 2
                ;;
            --)
                shift 1
                break
                ;;
            *)
                args+=("${1}")
                shift 1
                ;;
        esac
    done

    # Collect any remaining arguments
    while [[ ${#} -gt 0 ]]; do
        args+=("${1}")
        shift 1
    done

    # Set the header text
    header_text="${args[*]}"

    # Set the border width as an int
    case "${_border_width}" in
        fit-text)
            border_width="${#header_text}"
            ;;
        fit-terminal)
            border_width=$(tput cols 2>/dev/null)
            # If the terminal width could not be determined, default to 80
            if [[
                -z "${border_width}"
                || "${border_width}" =~ [^0-9]
                || ${border_width} -le 1
            ]]; then
                echo "warning: could not determine terminal width" >&2
                border_width=80
            fi
            ;;
        *)
            border_width="${_border_width}"
            ;;
    esac

    # Print the header
    ## Margin before the header
    for ((i=0; i<lines_before; i++)); do echo; done

    ## Print the initial border or markdown header
    if [[ "${style}" == "bordered" ]]; then
        # Print the first border
        for ((i=0; i<border_width; i++)); do printf '%s' "${border_character}"; done
        echo
    elif [[ "${style}" == "markdown" ]]; then
        for ((i=0; i<markdown_level; i++)); do echo -n "#"; done
        echo -n " "
    fi

    ## Print the header text
    echo "${S_BOLD}${header_text}${S_RESET}"

    ## Print the final border or underline
    if [[ "${style}" == "bordered" || "${style}" == "underlined" ]]; then
        # Print the final border
        for ((i=0; i<border_width; i++)); do printf '%s' "${border_character}"; done
        echo
    fi

    ## Margin after the header
    for ((i=0; i<lines_after; i++)); do echo; done
}
