# This module contains function for debugging bash scripts.

# Prints debug information if:
#   - DEBUG is set to "true" or "1"
#   - OR DEBUG_LEVEL is set and <= the first argument
# If `debug` is called without a debug level as the first argument, 1 is assumed.
# If `debug` is called without any arguments, it prints the current debug level.
# If `debug` is called with only a debug level, it sets the debug level.
#
# e.g.
#   DEBUG_LEVEL=2 debug 1 "foo bar" // will print
#   DEBUG_LEVEL=1 debug 2 "foo bar" // will not print
#   DEBUG_LEVEL=1 debug "foo bar" // will print
#   DEBUG=true    debug 1 "foo bar" // will print
#   DEBUG=true    debug "foo bar" // will print
#   debug 1 // sets the debug level to 1
function debug() {
    # if no arguments are given, print the current debug level
    if [ $# -eq 0 ]; then
        echo $DEBUG_LEVEL
        return
    fi
    # if only one integer argument is given, set the debug level
    if [ $# -eq 1 ] && [ ${1} -eq ${1} ] 2>/dev/null; then
        export DEBUG_LEVEL=$1
        return
    fi
    # determine if the first arg is an integer
    if [ "$1" -eq "$1" ] 2>/dev/null; then
        # if it is, then use it as this debug message's debug level
        local debug_level=${1}
        shift
    else
        local debug_level=1
    fi
    if [ "${DEBUG}" = 1 ] || [ "${DEBUG}" = "true" ] || [ "${DEBUG_LEVEL}" -ge ${debug_level} ] 2>/dev/null; then
        # create a timestamp
        timestamp=$(date +%Y-%m-%d-%H:%M:%S)
        # loop over each argument
        for arg in "${@}"; do
            # echo the argument with a timestamp
            echo "[${timestamp}] ${arg}" >&2
        done
    fi
}

# Temporarily turn on xtrace and run the given command
function debug-verbose() {
    set -x
    ${@}
    set +x
}
