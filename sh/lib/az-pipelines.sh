function _az_logging() {
    command="${1}" && shift
    printf '%s\n' "${@}" \
        | awk -v cmd="${command}" '{print "##[" cmd "]" $0}' >&2
}
function az-error() { _az_logging error "${@}"; }
function az-errorlog() {
  echo "##vso[task.logissue type=error]${*}" >&2
}
function az-warning() { _az_logging warning "${@}"; }
function az-info() { _az_logging info "${@}"; }
function az-section() { _az_logging section "${@}"; }
function az-group() { _az_logging group "${*}"; }
function az-endgroup() { _az_logging endgroup "${*}"; }

function az-setvariable() {
    # Default values
    local name=""
    local value=""
    local is_output=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            --name)
                name="${2}"
                shift 2
                ;;
            --value)
                value="${2}"
                shift 2
                ;;
            --output)
                is_output=true
                shift 1
                ;;
            *)
                if [[ -z "${name}" ]]; then
                    name="${1}"
                elif [[ -z "${value}" ]]; then
                    value="${1}"
                else
                    az-error "error: unknown argument: ${1}"
                    return 1
                fi
                shift 1
        esac
    done

    echo "##vso[task.setvariable variable=${name};isOutput=${is_output}]${value}"
}
