# Print a debug message if DEBUG=1 or write it to a log file if
# DEBUG_LOG=<filepath> is set
function debug() {
    if [[ ${DEBUG} -eq 1 || -n "${DEBUG_LOG}" ]]; then
        timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
        printf "\e[36m[%s]\e[0m \e[1;35m%s:%s\e[0m -- %s\n" \
            "${timestamp}" "${FUNCNAME[1]}" "${BASH_LINENO[0]}" "${@}" \
            | dd of="${DEBUG_LOG:-/dev/stderr}" conv=notrunc oflag=append status=none
    fi
}

