# This module contains function for debugging bash scripts.

include-source 'echo.sh'
include-source 'shell.sh'

# Prints debug information if:
#   - DEBUG is set to "true" or "1"
#   - OR DEBUG_LEVEL is set and <= the first argument
#   - OR DEBUG_LOG is set (prints to the file specified by DEBUG_LOG)
# If `debug` is called without a debug level as the first argument, 1 is assumed.
#
# e.g.
#   DEBUG_LEVEL=2 debug 1 "foo bar" // will print
#   DEBUG_LEVEL=1 debug 2 "foo bar" // will not print
#   DEBUG_LEVEL=1 debug "foo bar" // will print
#   DEBUG=true    debug 1 "foo bar" // will print
#   DEBUG=true    debug "foo bar" // will print
#   debug 1 // sets the debug level to 1
function debug() {
    # if DEBUG and DEBUG_LOG are not set, return
    if [ -z "${DEBUG}" ] && [ -z "${DEBUG_LOG}" ]; then
        return
    fi

    # If DEBUG_LOG is set, then create fd 3 and point it at the file
    # Otherwise, create fd 3 and point it at stderr
    if [ -n "${DEBUG_LOG}" ]; then
        exec 3>${DEBUG_LOG}
    else
        exec 3>&1
    fi

    # determine if the first arg is an integer
    if [ "${1}" -eq "${1}" ] 2>/dev/null; then
        # if it is, then use it as this debug message's debug level
        local debug_level=${1}
        shift
    else
        local debug_level=1
    fi

    # print the debug message if:
    #   - DEBUG is set to 1 or "true", or
    #   - DEBUG_LEVEL is set and >= the debug level
    if [ "${DEBUG}" = 1 ] \
    || [ "${DEBUG}" = "true" ] \
    || [ "${DEBUG_LEVEL}" -ge ${debug_level} ] 2>/dev/null\
    || [ -n "${DEBUG_LOG}" ]; then
        # create a timestamp
        local timestamp=$(date +%Y-%m-%d-%H:%M:%S)

        # get the calling function name
        local function_name=$(functionname 2)
        if [ "${function_name}" = "" ] || [ "${function_name}" = "main" ]; then
            local function_name=""
        else
            local function_name=":${function_name}()"
        fi

        # get the calling script name
        local script_name=$(basename ${BASH_SOURCE[-1]})

        # get the calling line number
        local line_number=$(caller 0 | awk '{print $1}')

        # loop over each argument
        for arg in "${@}"; do
            # check $DEBUG and $DEBUG_LEVEL to determine if we should print to stderr
            if [ "${DEBUG}" = 1 ] \
            || [ "${DEBUG}" = "true" ] \
            || [ "${DEBUG_LEVEL}" -ge ${debug_level} ] 2>/dev/null \
            || [ -n "${DEBUG_LOG}" ]; then
                # echo the argument with a timestamp
                # use a duplicated stderr on fd 3 to avoid mixing debug messages with other output
                if [ -n "${DEBUG_LOG}" ]; then
                    echo-formatted -g "[${timestamp}]" -c "${script_name}:${line_number}${function_name}" -- "\-- ${arg}" >> "${DEBUG_LOG}"
                else
                    echo-formatted -g "[${timestamp}]" -c "${script_name}:${line_number}${function_name}" -- "\-- ${arg}" >&3
                fi
            fi
        done
    fi
}

# Temporarily turn on xtrace and run the given command
function run-verbose() {
    set -x
    ${@}
    set +x
}
