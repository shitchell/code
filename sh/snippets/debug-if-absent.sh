# Set up debug functions if they don't already exist
## _debug_enabled
declare -f _debug_enabled &>/dev/null \
    || function _debug_enabled() { [[ "${DEBUG}" =~ ^"1"|"true"$ ]]; }
## debug
declare -f debug &>/dev/null \
    || function debug() { _debug_enabled && printf 'debug: %s\n' "${@}" >&2; }
## debug-vars
declare -f debug-vars &>/dev/null \
    || function debug-vars() { _debug_enabled && debug "$(declare -p "${@}")"; }
