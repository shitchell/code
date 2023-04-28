# returns the name of the current shell
function get-shell() {
    basename "$(ps -p "$$" -o args= | awk '{print $1}' | sed 's/^-//')" \
        | tr '[:upper:]' '[:lower:]'
}
# cross-shell function for returning the calling function name
function functionname() {
    # echo "${FUNCNAME[@]@Q}" >&2
    # echo "${BASH_SOURCE[@]@Q}" >&2
    local shell=$(get-shell)
    local index=${1:- -1}
    case $shell in
        bash)
            echo ${FUNCNAME[${index}]}
            ;;
        zsh)
            echo ${funcstack[${index}]}
            ;;
        *)
            echo "unknown shell: $shell" >&2
            return 1
            ;;
    esac
}

# @deprecated
# Checks if an item is in an array.
# usage: in-array <item> "${array[@]}"
# returns 0 if the item is in the array, 1 otherwise
function in-array() {
    local item=${1}
    shift

    local arg
    local subarg
    for arg in "${@}"; do
        for subarg in ${arg}; do
            if [ "${subarg}" == "${item}" ]; then
                return 0
            fi
        done
    done
    return 1
}

# Check if an item is in any of the given arguments or arrays
# usage: is-in <item> <arg1> <arg2> ... <argN>
# returns 0 if the item is in any of the arguments or arrays, 1 otherwise
function is-in() {
    local item=${1}
    shift
    local arg
    for arg in "${@}"; do
        if [ "${#arg[@]}" -gt 0 ]; then
            for subarg in "${arg[@]}"; do
                if [ "${subarg}" = "${item}" ]; then
                    return 0
                fi
            done
        else
            if [ "${arg}" = "${item}" ]; then
                return 0
            fi
        fi
    done
    return 1
}

# Get the index of an item in an array.
# usage: index-of <item> "${array[@]}"
# echoes the index of the item in the array. returns 0 if found, 1 otherwise
function index-of() {
    local item=${1}
    shift
    local array=("${@}")

    local e
    local index=0
    local found=false
    for e in "${!array[@]}"; do
        if [[ "${array[$e]}" == "${item}" ]]; then
            found=true
            break
        fi
        index=$((index + 1))
    done

    echo ${index}
    ${found} && return 0 || return 1
}

# runs a command and stores stderr and stdout in specified variables
# usage: catch stdout_var stderr_var command [args...]
function catch() {
    eval "$({
    __2="$(
        { __1="$("${@:3}")"; } 2>&1;
        ret=$?;
        printf '%q=%q\n' "$1" "$__1" >&2;
        exit $ret
    )";
    ret="$?";
    printf '%s=%q\n' "$2" "$__2" >&2;
    printf '( exit %q )' "$ret" >&2;
    } 2>&1 )";
}

# finds all functions in the given file(s). If "-" is passed as a filename, read
# from stdin.
function grep-functions() {
    # loop through all of the passed in arguments
    for filepath in "${@}"; do
        # get the contents of the file
        local contents
        if [ "${filepath}" = "-" ]; then
            contents=$(cat)
        else
            contents=$(cat "${filepath}")
        fi

        echo "${contents}" \
            | grep -Pazo '(?s)[a-zA-Z0-9_\-]+\s*(\(\s*\))?\s*{' \
            | tr '\0' '\n' \
            | grep --color=never -Eo '[a-zA-Z0-9_\-]+'
    done
}

# v1.0.0
# find all the functions in the given file(s) and echo their source to stdout.
# If "-" is passed as a filename, read from stdin.
# TODO: use regex to extract the function source without sourcing the file
function extract-functions() {
    # loop through all of the passed in arguments
    for filepath in "${@}"; do
        # get all of the functions in the file
        local functions=$(grep-functions "${filepath}")

        # source the file in a subshell and then use `type` to get the source
        # of each function
        ( source "${filepath}" >/dev/null 2>&1 && for function in ${functions}; do
            echo "function ${function}() {"
            type ${function} | sed '1,3d;$d'
            echo "}"
        done )
    done
}

# Search for a function body in the specified file(s). If "-" is passed as a
# filename, read from stdin.
function find-function() {
    # get the function name
    local function_name="${1}"
    shift

    # loop through all of the passed in arguments
    for filepath in "${@}"; do
        # get the contents of the file
        local contents
        if [ "${filepath}" = "-" ]; then
            contents=$(cat)
        else
            contents=$(cat "${filepath}")
        fi

        # use awk to find the function body from the first to the closing brace.
        # keep track of how many braces we've seen. every time we see an opening
        # brace, increment the count. every time we see a closing brace, decrement
        # the count. if the count is 0, once the count is at 0, print the
        # function body.
        # TODO: handle case where there are extra closing braces on the last
        #       line
        function_pattern="^(function)?\s*${function_name}\s*(\(\s*\))?\s*{"
        echo "${contents}" | tr '\n' '\0' | awk \
            -v fname="${function_name}" \
            -v fbody="" \
            -v brace_count=0 \
            -v in_function=0 \
            '{
                if ($0 ~ fname) {
                    in_function = 1
                }
                if (brace_count == 0) {
                    fbody = ""
                }
                if ($0 ~ "{") {
                    brace_count += gsub("{", "");
                }
                if ($0 == "}") {
                    brace_count -= gsub("}", "");
                }
                if (brace_count == 0) {
                    fbody = fbody $0 "\n"
                }
                if (brace_count == 0 && $0 ~ /^function\s+'"${function_name}"'/) {
                    print fbody
                }
            }'
    done
}

# Search for a file in the PATH or optionally specified PATH style variable
# and return the full path to the file.
function search-path() {
    local filepath="${1}"
    local path="${2:-${PATH}}"
    local found_path

    # loop through all of the paths in the PATH variable
    while IFS=':' read -d: -r pathdir || [ -n "${pathdir}" ]; do
        # if the file exists in the path, set the found_path variable and break
        # out of the loop
        if [ -f "${pathdir}/${filepath}" ]; then
            found_path="${pathdir}/${filepath}"
            break
        fi
    done <<< "${path}"

    # if we found the file, echo the full path to the file
    if [ -n "${found_path}" ]; then
        echo "${found_path}"
        return 0
    fi

    # if we didn't find the file, return 1
    return 1
}

# Search for and attempt to return the original path to a command in the PATH
# rather than an alias, function, or wrapper script.
function which-original() {
    local command="${1}"
    local executables=()
    local mimetype
    local mimetypes=()

    # use `which` to get the paths to all executables matching the command name
    executables=($(which -a "${command}"))

    # if no executables were found, return 1
    if [ ${#executables[@]} -eq 0 ]; then
        return 1
    fi

    # loop through all of the executables and collect their mime types
    for executable in "${executables[@]}"; do
        mimetype=$(file --mime-type -b "${executable}" 2>/dev/null)
        mimetypes+=("${mimetype}")
    done

    # determine if any of the executables is an application
    local i=0
    for mimetype in "${mimetypes[@]}"; do
        if [ "${mimetype}" = "application/x-executable" ]; then
            echo "${executables[${i}]}"
            return 0
        fi
        let i++
    done

    # if none of the executables is an application, check to see if any of the
    # executables is installed in a system directory
    for executable in "${executables[@]}"; do
        local directory=$(dirname "${executable}")
        # use a case statement to check if the directory is a system directory
        case "${directory}" in
            /bin|/sbin|/usr/bin|/usr/sbin|/usr/local/bin|/usr/local/sbin)
                echo "${executable}"
                return 0
                ;;
        esac
    done

    return 1
}

# Return the first non-empty string from the given arguments.
function first-value() {
    for arg in "${@}"; do
        if [ -n "${arg}" ]; then
            echo "${arg}"
            return 0
        fi
    done
    return 1
}

# Returns 0 if the given argument is in the specified path, 1 otherwise.
function dir-in-path() {
    local dir="${1}"
    local path="${2:-${PATH}}"

    [[ ":${PATH}:" == *":${dir}:"* ]]
}

# Add the given arguments to the PATH environment variable if they are not
# already in the PATH
function add-paths() {
    local usage="usage: $(functionname) [-h|--help] [-P|--path-var PATH_VARIABLE] [-a|--append] [-p|--prepend]"

    # default values
    local path_name="PATH"
    local do_append=0
    local paths=()

    while [[ ${#} -gt 0 ]]; do
        local arg="$1"
        case "$arg" in
            -h|--help)
                echo ${usage}
                return 0
                ;;
            -P|--path-var)
                path_name="$2"
                shift
                ;;
            -a|--append)
                do_append=1
                shift
                ;;
            -p|--prepend)
                do_append=0
                shift
                ;;
            -*)
                echo "include-source: invalid option '$arg'" >&2
                exit 1
                ;;
            *)
                paths+=("$arg")
                shift
                ;;
        esac
    done

    # if no paths were specified, return 1
    if [ ${#paths[@]} -eq 0 ]; then
        echo "${usage}" >&2
        return 1
    fi

    # Get the current value of the specified PATH variable.
    local path_value=${!path_name}

    # loop through all of the paths and add them to the PATH if they are not
    # already in the PATH
    for path in "${paths[@]}"; do
        if ! dir-in-path "${path}" "${path_value}"; then
            if [ ${do_append} -eq 1 ]; then
                path_value="${path_value}:${path}"
            else
                path_value="${path}:${path_value}"
            fi
        fi
    done

    # Store the updated path_value in the specified PATH variable.
    export "${path_name}"="${path_value}"
}

# @description: Sorts the given array or list of arguments
# @positional+: an unsorted list of strings
# @returns: the input array, sorted
function sort-array() {
    local array=("${@}")
    local sorted_array=()

    if [ -z "${array[*]}" ]; then
        return 1
    fi

    # sort the array
    sorted_array=($(printf '%s\0' "${array[@]}" | sort -z | xargs -0))

    # print the sorted array
    printf '%s' "${sorted_array[@]}"
}

# @description: Determines if the current shell is interactive
# @usage: is-interactive
# @example: is-interactive && echo "interactive" || echo "not interactive"
# @returns: 0 if the shell is interactive
# @returns: 1 if the shell is attached to a pipe
# @returns: 2 if the shell is attached to a redirection
function is-interactive() {
    # STDOUT is attached to a tty
    [[ -t 1 ]] && return 0

    # STDOUT is attached to a pipe
    [[ -p /dev/stdout ]] && return 1

    # STDOUT is attached to a redirection
    [[ ! -t 1 && ! -p /dev/stdout ]] && return 2
}

# @description: Loop over each argument or multiline string with a given command
# @usage: for-each <command> [--log <filepath>] [--quiet] -- <args...>
# @example: for-each echo -- a b c $'hello\nworld'
# @example: for-each echo --log /tmp/log.txt -- a b c $'hello\nworld'
# @returns: 0 if the command succeeds for all arguments
# @returns: 1 if the command fails for any argument
# @returns: 2 if the command fails for all arguments
# @returns: 3 if the command is not found
function for-each() {
    local any_success=0
    local any_failure=0
    local quiet=0
    local cmd=()
    local args=()
    local log_filepath=""

    # parse the command and arguments
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            --log)
                log_filepath="${2}"
                shift 1
                ;;
            --quiet)
                quiet=1
                ;;
            --)
                shift
                args=("${@}")
                break
                ;;
            *)
                cmd+=("${1}")
                ;;
        esac
        shift
    done

    # check if command is found
    if ! type "${cmd[0]}" 2>&1 1>/dev/null; then
        echo "for-each: command not found: ${cmd[0]}" >&2
        return 3
    fi

    # determine whether to print the arguments or read them from STDIN
    if [[ ${#args[@]} -gt 0 ]]; then
        print_args=("printf" "%s\n" "${args[@]}")
    else
        print_args=("cat" "-")
    fi

    # loop over each argument
    local exit_code
    local output
    "${print_args[@]}" | while read -r arg; do
        # run the command
        output=$("${cmd[@]}" "${arg}" 2>&1)
        exit_code=${?}

        # log the output
        if [ -n "${log_filepath}" ]; then
            echo "${output}" >> "${log_filepath}"
        fi

        # print the output
        if [ ${quiet} -eq 0 ]; then
            echo "${output}"
        fi

        # check the exit code
        if [ ${exit_code} -eq 0 ]; then
            any_success=1
        else
            any_failure=1
        fi
    done

    # return the appropriate exit code
    if [ ${any_success} -eq 1 ] && [ ${any_failure} -eq 0 ]; then
        return 0
    elif [ ${any_success} -eq 0 ] && [ ${any_failure} -eq 1 ]; then
        return 1
    else
        return 2
    fi
}