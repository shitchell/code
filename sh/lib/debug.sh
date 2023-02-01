# This module contains function for debugging bash scripts.

# Prints debug information if:
#   - DEBUG is set to "true" or "1"
#   - OR DEBUG_LEVEL is set and <= the first argument
#   - OR DEBUG_LOG is set (prints to the file specified by DEBUG_LOG)
# If `debug` is called without a debug level as the first argument, 1 is assumed.
#
# e.g.
#   DEBUG=1 debug "foo bar" // will print
#   DEBUG=1 debug 2 "foo bar" // will not print
#   DEBUG=2 debug 1 "foo bar" // will print
#   DEBUG=true    debug "foo bar" // will print
#   DEBUG=true    debug 2 "foo bar" // will print
function debug() {
    local debug_file  # the file descriptor to write messages to
    local debug_level  # the debug level of this message
    local timestamp  # the timestamp of this message
    local function_name  # the name of the calling function
    local script_name  # the name of the calling script
    local line_number  # the line number of the debug call in the calling script

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
        # create a timestamp
        timestamp=$(date +"%Y-%m-%d %H:%M:%S")

        # get the calling function name
        function_name=${FUNCNAME[1]}
        if [[ -n "${function_name}" ]]; then
            if ! [[ "${DEBUG_COLOR}" =~ ^"false"|"0"$ ]]; then
                function_name=$'\033[38;1m:\033[32;1m'"${function_name}"'()'
            else
                function_name=":${function_name}()"
            fi
        fi

        # get the calling script name
        script_name=$(basename ${BASH_SOURCE[-1]})

        # get the calling line number
        # line_number=$(caller 0 | awk '{print $1}')
        line_number=${BASH_LINENO[0]}

        # loop over each argument
        for arg in "${@}"; do
            # loop over each line in the argument
            while IFS= read -r line; do
                # print the debug message
                if ! [[ "${DEBUG_COLOR}" =~ ^"false"|"0"$ ]]; then
                    printf "\033[36m[%s]\033[0m \033[35;1m%s\033[38;1m:\033[35m%s%s\033[0m -- %s\033[0m\n" \
                        "${timestamp}" "${script_name}" "${line_number}" "${function_name}" "${line}" \
                        | dd of="${debug_file}" conv=notrunc oflag=append status=none # this is a hack to avoid redirect errors where `debug` consumes and obliterates the output of the command it is called from
                        #>> "${debug_file}" #|
                else
                    printf "[%s] %s:%s%s -- %s\n" \
                        "${timestamp}" "${script_name}" "${line_number}" "${function_name}" "${line}" \
                        | dd of="${debug_file}" conv=notrunc oflag=append status=none # this is a hack to avoid redirect errors where `debug` consumes and obliterates the output of the command it is called from
                        # >> "${debug_file}"
                fi
            done <<< "${arg}"
        done
    fi
}

# Temporarily turn on xtrace and run the given command
function run-verbose() {
    set -x
    ${@}
    set +x
}
