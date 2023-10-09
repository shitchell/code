# This module contains function for debugging bash scripts.

# Prints debug information if:
#   - DEBUG is set to "true", "all", or "*"
#   - OR DEBUG is set to an integer and <= the first argument
#
# If `debug` is called without a debug level as the first argument, 1 is assumed
# DEBUG_LOG can be used to print debug messages to a file instead of stderr
# A debug message can be labeled by passing one of the following as the first
# argument:
#   - "error" (prints in red)
#   - "success" (prints in green)
#   - "warn" (prints in yellow)
#   - "info" (prints in cyan)
#
# Examples:
#   DEBUG=1   debug "foo bar" // will print
#   DEBUG=1   debug 2 "foo bar" // will not print
#   DEBUG=2   debug 1 "foo bar" // will print
#   DEBUG=all debug "foo bar" // will print
#   DEBUG=all debug 2 "foo bar" // will print
#   DEBUG=1   debug error "foo bar" // will print in red
#   DEBUG=1   debug 2 error "foo bar" // will not print
#   DEBUG=2   debug 2 error "foo bar" // will print in red
function debug() {
    local debug_file  # the file to write messages to
    local debug_level  # the debug level of this message
    local timestamp  # the timestamp of this message
    local function_name  # the name of the calling function
    local script_name  # the name of the calling script
    local line_number  # the line number of the debug call in the calling script
    local line_loc  # the script, function, and line number of the debug call
    local text_color  # the color to use for the debug message

    # if DEBUG and DEBUG_LOG are not set, return
    if [[ -z "${DEBUG}" && -z "${DEBUG_LOG}" ]]; then
        return
    fi

    # if DEBUG_LOG is set, then use that as the log file, else use /dev/stderr
    if [[ -n "${DEBUG_LOG}" ]]; then
        if [[ -z "${DEBUG}" ]]; then
            # if DEBUG is not set, default to 1
            DEBUG=1
        fi
        debug_file="${DEBUG_LOG}"
    else
        # by default, print to /dev/stderr
        debug_file="/dev/stderr"
    fi

    # determine if the first arg is an integer
    if [[ "${1}" =~ ^[0-9]+$ ]]; then
        # if it is, then use it as this debug message's debug level
        debug_level=${1}
        shift
    else
        debug_level=1
    fi

    # print the debug message if:
    #   - DEBUG is set to "true", "all", or "*", or
    #   - DEBUG is set to an integer and >= the debug level, or
    #   - DEBUG_LOG is set (if DEBUG is not set, default to 1)
    if [[
        "${DEBUG}" =~ ^"true"|"all"|"*"$ \
        || ("${DEBUG}" =~ ^[0-9]+$ && "${DEBUG}" -ge ${debug_level})
    ]]; then
        # create a timestamp
        timestamp=$(date +"%Y-%m-%d %H:%M:%S")

        # get the calling function name
        if [[ -n "${DEBUG_FUNCTION_NAME}" ]]; then
            function_name="${DEBUG_FUNCTION_NAME}"
        else
            function_name=${FUNCNAME[$((DEBUG_SOURCE_LEVEL + 1))]}
        fi

        # get the calling script name
        if [[ -n "${DEBUG_SCRIPT_NAME}" ]]; then
            script_name="${DEBUG_SCRIPT_NAME}"
        else
            script_name=$(basename "${BASH_SOURCE[$((DEBUG_SOURCE_LEVEL - 1))]}")
        fi

        # get the calling line number
        if [[ -n "${DEBUG_LINE_NUMBER}" ]]; then
            line_number="${DEBUG_LINE_NUMBER}"
        else
            line_number=${BASH_LINENO[0]}
        fi

        # handle color and some formatting
        if [[ "${DEBUG_COLOR}" =~ ^"false"|"0"$ ]]; then
            # timestamp
            timestamp="[${timestamp}]"

            # line description
            [[ -n "${script_name}" ]] && line_loc+="${script_name}"
            [[ -n "${function_name}" ]] && line_loc+=":${function_name}()"
            [[ -n "${line_number}" ]] && line_loc+=":${line_number}"

            # handle specific categories of debug messages
            if [[ "${1}" =~ ^("error"|"warn"|"info"|"success")$ ]]; then
                text_color=""
                shift
            fi
            text_color_end=""
        else
            # timestamp
            timestamp=$'\033[36m['"${timestamp}"$']\033[0m'

            # line description
            [[ -n "${script_name}" ]] && line_loc+=$'\033[35m'"${script_name}"$'\033[0m'
            [[ -n "${function_name}" ]] && line_loc+=$'\033[35;1m:'"${function_name}"$'()\033[0m'
            [[ -n "${line_number}" ]] && line_loc+=$'\033[32m:'"${line_number}"$'\033[0m'

            # handle specific categories of debug messages
            if [[ "${1}" == "error" ]]; then
                text_color=$'\033[31;1m'
                # text_color=$'\033[41;30m'
                shift
            elif [[ "${1}" == "warn" ]]; then
                text_color=$'\033[33;1m'
                shift
            elif [[ "${1}" == "info" ]]; then
                text_color=$'\033[36;1m'
                shift
            elif [[ "${1}" == "success" ]]; then
                text_color=$'\033[32;1m'
                shift
            fi
            text_color_end=$'\033[0m'
        fi

        # print all the things
        printf "%s\n" "${@}" \
            | awk \
                -v timestamp="${timestamp}" \
                -v line_loc="${line_loc}" \
                -v text_color="${text_color}" \
                -v text_color_end="${text_color_end}" \
                '{
                    printf "%s %s -- %s%s%s\n", timestamp, line_loc, text_color, $0, text_color_end;
                }' \
            | dd of="${debug_file}" conv=notrunc oflag=append status=none
            # ^^^ this is a hack to avoid redirect errors where `debug` consumes
            # and obliterates the output of the command it is called from
    fi
}

# @description Print the values of a list of variables given their names
# @usage debug-vars <var1> <var2> ...
# @example foo=bar bar=baz debug-vars "foo" "bar"
function debug-vars() {
    local var_name debug_message declare_str

    debug_message=$(
        for var_name in "${@}"; do
            declare_str=$(declare -p "${var_name}" 2>/dev/null)
            if [[ -z "${declare_str}" ]]; then
                echo -e "${var_name}\x1e== <not found>"
            elif ! [[ "${declare_str}" =~ "=" ]]; then
                echo -e "${var_name}\x1e== <unset>"
            else
                echo "${declare_str}" \
                    | sed -E '
                        s/^declare -[^ ]+ ([^=]+)=(.*)$/\1\x1e== \2/;s/ \)$/)/
                        2,$s/^/ \x1e.. /
                    '
            fi
        done | column -t -s $'\x1e'
    )
    DEBUG_FUNCTION_NAME="${FUNCNAME[1]}" \
    DEBUG_SCRIPT_NAME="${BASH_SOURCE[1]##*/}" \
    DEBUG_LINE_NUMBER="${BASH_LINENO[0]}" \
        debug "${debug_message}"
}

# print debug information, test version
function _debug() {
    local debug_file
    local debug_level
    local timestamp

    # if DEBUG and DEBUG_LOG are not set, return
    if [[ -z "${DEBUG}" && -z "${DEBUG_LOG}" ]]; then
        return
    fi

    # if DEBUG_LOG is set, then use that as the log file, else use /dev/stderr
    if [[ -n "${DEBUG_LOG}" ]]; then
        if [[ -z "${DEBUG}" ]]; then
            # if DEBUG is not set, default to 1
            DEBUG=1
        fi
        debug_file="${DEBUG_LOG}"
    else
        # duplicate stderr to fd 3
        debug_file="/dev/stderr"
    fi

    # determine if the first arg is an integer
    if [[ "${1}" =~ ^[0-9]+$ ]]; then
        # if it is, then use it as this debug message's debug level
        debug_level=${1}
        shift
    else
        debug_level=1
    fi

    # print the debug message if:
    #   - DEBUG is set to "true", "all", or "*", or
    #   - DEBUG is set to an integer and >= the debug level, or
    #   - DEBUG_LOG is set (if DEBUG is not set, default to 1)
    if [[
        "${DEBUG}" =~ ^"true"|"all"|"*"$ \
        || ("${DEBUG}" =~ ^[0-9]+$ && "${DEBUG}" -ge ${debug_level})
    ]]; then
        timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
        printf "%s\n" "${@}" \
            | awk \
                -v timestamp="${timestamp}" \
                -v funcname="${FUNCNAME[1]}" \
                -v lineno="${BASH_LINENO[0]}" \
                'BEGIN {
                    if (funcname) {
                        funcname = funcname "()";
                    }
                }
                {
                    print "\033[36m" "[" timestamp "]" "\033[0m " \
                        "\033[35;1m" funcname "\033[0m" \
                        "\033[32m:" lineno "\033[0m" \
                        " -- " $0;
                }' \
            | dd of="${debug_file}" conv=notrunc oflag=append status=none
        # for arg in "${@}"; do
        #     printf "\e[36m[%s]\e[0m \e[1;35m%s:%s\e[0m -- %s\n" \
        #         "${timestamp}" "${FUNCNAME[1]}" "${BASH_LINENO[0]}" "${arg}" \
        #         | dd of="${DEBUG_LOG:-/dev/stderr}" conv=notrunc oflag=append status=none
        # done
    fi
}

# @description Print debug information if $DEBUG or $DEBUG_LOG are set
# @usage _mini_debug <message>
function _mini_debug() {
    local prefix timestamp
    if [[ "${DEBUG}" == "1" || "${DEBUG}" == "true" || -n "${DEBUG_LOG}" ]]; then
        timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
        prefix="\033[36m[${timestamp}]\033[0m "
        prefix+="\033[35m$(basename "${BASH_SOURCE[-1]}")"
        [[ "${FUNCNAME[1]}" != "main" ]] && prefix+="\033[1m:${FUNCNAME[1]}()\033[0m"
        prefix+="\033[32m:${BASH_LINENO[0]}\033[0m -- "
        printf "%s\n" "${@}" \
            | awk -v prefix="${prefix}" '{print prefix $0}' \
            | dd of="${DEBUG_LOG:-/dev/stderr}" conv=notrunc oflag=append status=none
    fi
}

# Temporarily turn on xtrace and run the given command
function run-verbose() {
    set -x
    "${@}"
    set +x
}
