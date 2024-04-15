include-source 'debug.sh'

# @description Silence all output
# @usage silence-output
function silence-output() {
    exec 3>&1 4>&2 1>/dev/null 2>&1
}

# @description Restore stdout and stderr
# @usage restore-output
function restore-output() {
    [[ -t 3 ]] && exec 1>&3 3>&-
    [[ -t 4 ]] && exec 2>&4 4>&-
}

# @description Exit trap
function trap-exit() {
    restore-output
}
trap trap-exit EXIT

# @description A general help message
function show-help() {
    declare -f help-usage &>/dev/null \
        && help-usage \
        || echo "usage: $(basename "${0}") [-hs] [-d dir] [--] [<args>]"
    echo
    echo "Some extra info."
    echo
    echo "Options:"
    cat <<EOF
    -h/--help                display this help message
    -s/--silent              suppress all output
    -d/--directory <dir>     a directory to use

EOF
    # If a custom-help function is defined, run it
    declare -f help-options &>/dev/null && help-options
}

# @description Determine if the parent process is a shell
function parent-is-shell() {
    local ps_args=$(ps -o args= "$$")
    debug-vars ps_args

    ! [[ "${ps_args}" == *" "* ]]
}

# @description A general argument parser
# @usage parse-args --foo=bar --option --no-other-option arg1 arg2 -- -andthis
function parse-args() {
    declare -gA OPTS=()
    declare -gA ARGS=()
    declare -ga POSARGS=()
    declare -ga FOO=()
    declare -g DO_SILENT=false

    while [[ ${#} -gt 0 ]]; do
        debug "parse-arg: ${1}"
        case ${1} in
            -h | --help)
                debug "  halp!"
                show-help
                parent-is-shell && return 0 || exit 0
                ;;
            -s | --silent)
                debug "  shhhh"
                DO_SILENT=true
                ;;
            -f=* | --foo=*)
                # For consistency's sake, require a "="
                local val="${1#*=}"
                debug "  foo == '${val}'"
                FOO+=("${val}")
                ;;
            --)
                shift 1
                break
                ;;
            --*)
                # If it has an equal sign, treat it as an ARG, else as an OPT
                local key val not
                if [[ "${1}" == *"="* ]]; then
                    debug "  arg"
                    key="${1%%=*}"
                    key="${key#--}"
                    val="${1#*=}"
                    ARGS["${key}"]="${val}"
                else
                    debug "  opt"
                    # Check to see if it starts with "--no-"
                    if [[ "${1}" =~ ^--(no-)?(.*)$ ]]; then
                        # debug-vars BASH_REMATCH
                        not="${BASH_REMATCH[1]}"
                        key="${BASH_REMATCH[2]}"
                        debug-vars not key
                        val=true
                        if [[ -n "${not}" ]]; then
                            val=false
                        fi
                        OPTS["${key}"]="${val}"
                    fi
                fi
                debug "  '${key}' == '${val}'"
                ;;
            *)
                debug "  posarg += '${1}'"
                POSARGS+=("${1}")
                ;;
        esac
        shift 1
    done

    # If -- was used, collect the remaining arguments
    while [[ ${#} -gt 0 ]]; do
        POSARGS+=("${1}")
        shift 1
    done

    ${DO_SILENT} && silence-output
}
