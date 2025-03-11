# @description Print a debug message if DEBUG or DEBUG_LOG is set
# @usage debug <msg> [<msg> ...]
function debug() (
    # use a subshell to avoid altering &3 in the calling shell
    local prefix timestamp fn_index="${DEBUG_INDEX:- 1}"
    if [[ "${DEBUG}" == "1" || "${DEBUG}" == "true" || -n "${DEBUG_LOG}" ]]; then
        if [[ ${#} -gt 0 ]]; then
            [[ -n "${DEBUG_LOG}" ]] && exec 3>>"${DEBUG_LOG}" || exec 3>&2
            timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
            prefix="\033[36m[${timestamp}]\033[0m "
            prefix+="\033[35m$(basename "${BASH_SOURCE[-1]}")"
            [[ "${FUNCNAME[${fn_index}]}" != "main" ]] \
                && prefix+="\033[1m:${FUNCNAME[${fn_index}]}()\033[0m"
            prefix+="\033[32m:${BASH_LINENO[$((fn_index - 1))]}\033[0m --"
            printf "%s\n" "${@}" | while IFS= read -r line; do
                printf -- "${prefix} %s\n" "${line}"
            done >&3
        fi
        return 0  # in debug mode
    fi
    return 1  # not in debug mode
)

function debug-vars() {
    debug && [[ ${#} -gt 0 ]] && DEBUG_INDEX=2 debug "$(declare -p "${@}")"
}

## A version that shows `<shell>` when used at an interactive prompt? Seems
## unnecessary if the purpose is a minimal copy/paste version for scripts...
# # @description Print a debug message if DEBUG or DEBUG_LOG is set
# # @usage debug <msg> [<msg> ...]
# function debug() (
#     # use a subshell to avoid altering &3 in the calling shell
#     local prefix timestamp source fn_index="${DEBUG_INDEX:- 1}"
#     if [[ "${DEBUG}" == "1" || "${DEBUG}" == "true" || -n "${DEBUG_LOG}" ]]; then
#         if [[ ${#} -gt 0 ]]; then
#             [[ -n "${DEBUG_LOG}" ]] && exec 3>>"${DEBUG_LOG}" || exec 3>&2
#             timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
#             prefix="\033[36m[${timestamp}]\033[0m "
#             if [[ "${-}" == *i* ]]; then
#                 prefix+="\033[35m<shell>"
#             else
#                 prefix+="\033[35m$(basename "${BASH_SOURCE[-1]}")"
#                 [[ "${FUNCNAME[${fn_index}]}" != "main" ]] \
#                     && prefix+="\033[1m:${FUNCNAME[${fn_index}]}()\033[0m"
#             fi
#             prefix+="\033[32m:${BASH_LINENO[$((fn_index - 1))]}\033[0m --"
#             printf "%s\n" "${@}" | while IFS= read -r line; do
#                 printf -- "${prefix} %s\n" "${line}"
#             done >&3
#         fi
#         return 0  # in debug mode
#     fi
#     return 1  # not in debug mode
# )

## Left for posterity's sake, I previously used an `awk` call to prepend each
## debug line with the prefix. I've since switched to using the above while
## loop because it is ever so slightly more efficient. The difference is
## trivial:
##
##     $ time for i in {1..50}; do
##     >   DEBUG=true _debug_while "hello world" "foo bar" lol wat &>/dev/null
#      > done
##
##     real    0m1.609s
##     user    0m0.156s
##     sys     0m1.438s
##     $ time for i in {1..50}; do
##     >   DEBUG=true _debug_awk "hello world" "foo bar" lol wat &>/dev/null
##     > done
##
##     real    0m2.124s
##     user    0m0.188s
##     sys     0m1.844s
##
## Only (2.124 - 1.609) / 50 = 0.0103s per line. Still, those lines add up, and
## I like conceptually pristine code.

# function _debug_awk() (
#     # use a subshell to avoid altering &3 in the calling shell
#     local prefix timestamp
#     if [[ "${DEBUG}" == "1" || "${DEBUG}" == "true" || -n "${DEBUG_LOG}" ]]; then
#         if [[ ${#} -gt 0 ]]; then
#             [[ -n "${DEBUG_LOG}" ]] && exec 3>>"${DEBUG_LOG}" || exec 3>&2
#             timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
#             prefix="\033[36m[${timestamp}]\033[0m "
#             prefix+="\033[35m$(basename "${BASH_SOURCE[-1]}")"
#             [[ "${FUNCNAME[1]}" != "main" ]] && prefix+="\033[1m:${FUNCNAME[1]}()\033[0m"
#             prefix+="\033[32m:${BASH_LINENO[0]}\033[0m -- "
#             printf "%s\n" "${@}" \
#                 | awk -v prefix="${prefix}" '{print prefix $0}' \
#                 >&3
#         fi
#         return 0  # in debug mode
#     fi
#     return 1  # not in debug mode
# )
