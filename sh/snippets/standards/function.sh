function my-function() {
    :  'This is a brief help summary

        This is a more extensive help message with some
        extra details

        @usage
            [-h/--help] [-d/--delimeter <delimiter>] <some_arg> [<args> ...]

        @option -h/--help
            Show this help message and exit

        @option -d/--delimeter
            Use this string as a delimiter when concatenating arguments

        @arg some_arg
            An argument to pass

        @arg* args
            Other args to pass

        @stdout
            All args concatenated using the specified delimiter

        @return 1
            No arguments were passed or required argument missing
    '

    # Initialize local variables with the required syntax.
    ## standards: all local variables are declared at the top of the function
    ##            and prefixed with a double underscore ("__")
    local __args=()
    local __delimiter=""
    local __some_arg=""
    local __result=""
    local __element  # standards: note even the for loop iterator is declared

    # Check if no arguments were provided.
    ## standards: all variables use the `${varname}` syntax
    if [[ "${#}" -eq 0 ]]; then
        echo "fatal: no arguments given" >&2
        return 1
    fi

    # Process each argument.
    while [[ "${#}" -gt 0 ]]; do
        case "${1}" in
            -h | --help)
                echo "$0 - usage: [-h/--help] [-d/--delimeter <delimiter>] <some_arg> [<args> ...]"
                return 0
                ;;
            -d | --delimeter)
                if [[ -z "${2}" ]]; then
                    ## standards: any error message preceding an exit should be
                    ##            prefixed with `fatal: `
                    echo "fatal: -d/--delimeter requires a value" >&2
                    return 1
                fi
                __delimiter="${2}"
                shift 1
                ;;
            *)
                if [[ -z "${__some_arg}" ]]; then
                    __some_arg="${1}"
                else
                    __args+=("${1}")
                fi
                ;;
        esac
        shift 1
    done

    # Check that the required <some_arg> was provided.
    if [[ -z "${__some_arg}" ]]; then
        echo "fatal: <some_arg> required" >&2
        return 1
    fi

    # If additional args exist and no delimiter was specified, use a default space.
    if [[ -z "${__delimiter}" && ${#__args[@]} -gt 0 ]]; then
        __delimiter=" "
    fi

    # Concatenate the first argument and any additional arguments using the delimiter.
    __result="${__some_arg}"
    for __element in "${__args[@]}"; do
        __result+="${__delimiter}${__element}"
    done

    echo "${__result}"
}
