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
            | awk -v prefix="${prefix}" '{print prefix $0}' >> "${DEBUG_LOG:-/dev/stderr}"
    fi
}
