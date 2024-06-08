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
    local item="${1}"
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

# @description
#   Check for dependencies and exit if any are not met.
#
#   Output:
#   --quiet: if this option is specified, all output will be suppressed.
#
#   --success-message <message>: if this option is specified, the specified
#   message will be printed if all dependencies are met.
#
#   --failure-message <message>: if this option is specified, the specified
#   message will be printed if any dependencies are not met. if the requirements
#   generated any other output, this option will suppress those messages unless
#   the `--verbose` option is specified
#
#   --verbose: if this option is specified, the `--failure-message` will not
#   suppress any output generated by the requirements.
#
#
#   Commands:
#   --optional: if the specified command is not found, a warning will be
#   printed, but the script will continue.
#
#   --one-of: this option allows you to specify a set of commands where only
#   one of them is required. The first command in the set that is found will be
#   set to the variable name specified in the --one-of option. e.g.:
#       require --one-of downloader="curl wget"
#       echo "${downloader}"
#   If curl is found, `downloader` will be set to curl. If curl is not found,
#   but wget is, downloader will be set to wget. If neither curl nor wget is
#   found, the script will exit.
#
#
#   Exit code:
#   --exit-success <eval>: run `<eval>` and exit if its exit code is not 0.
#
#   --exit-failure <eval>: run `<eval>` and exit if its exit code is 0.
#
#
#   Variables/values:
#   --value <value1>="<value2>": if `value1` is not equal to `value2`, the
#   script will exit.
#
#   --variable-value <varname>="<value>": if the variable `varname` is not equal
#   to `value`, the script will exit.
#
#   --is-set <varname>: if the variable `varname` is not set, the script will
#   exit.
#
#   --is-empty <varname>: if the variable `varname` is not empty, the script
#   will exit.
#
#
#  Access:
#  --root: if this option is specified, the script will exit if it is not run as
#  root.
#
#  --uid <uid>: if this option is specified, the script will exit if it is not
#  run as the specified user.
#
#  --user <username>: if this option is specified, the script will exit if it is
#  not run as the specified user.
#
#  --gid <gid>: if this option is specified, the script will exit if it is not
#  run as the specified group.
#
#  --group <groupname>: if this option is specified, the script will exit if it
#  is not run as the specified group.
#
#  --read <filepath>: if this option is specified, the script will exit if it
#  does not have read permissions for the specified file or directory.
#
#  --write <filepath>: if this option is specified, the script will exit if it
#  does not have write permissions for the specified file or directory.
#
#
#  Misc:
#  --os <os>: if this option is specified, the script will exit if it is not
#  run on the specified OS. The value of this option should be the value of the
#  ID field in /etc/os-release.
#
# @usage: require [-r|--root] [-o|--optional <dep>] [-O|--one-of <name>="<dep1> <dep2> <dep3>"] <dep1> <dep2> <dep3>
# @example:
#   require --root --one-of downloader="curl wget" tar
#   case "${downloader}" in
#       curl)
#           curl -sSL https://example.com | tar -xzf -
#           ;;
#       wget)
#           wget -qO- https://example.com | tar -xzf -
#           ;;
#   esac
function require() {
    # Default values
    local success_message=""
    local failure_message=""
    local exit_success_eval=""
    local exit_failure_eval=""
    local required_user=""
    local required_uid=""
    local required_group=""
    local required_gid=""
    local required_os=""
    local optional_dependencies=()
    local required_dependencies=()
    local should_exit=false
    local error_messages=()
    local warning_messages=()
    local exit_code=0
    local set_variables=()
    local empty_variables=()
    local read_filepaths=()
    local write_filepaths=()
    local do_quiet=false
    local do_exit_on_failure=true
    local do_verbose=false
    declare -A values # format: ['value1'="val1" 'value2'="val2"...]
    declare -A variable_values # format: ['varname'="value'...]
    declare -A one_of # format: ['download'="curl wget" 'extract'="unzip tar"...]

    # Loop over the arguments
    while [[ ${#} -gt 0 ]]; do
        case ${1} in
            --success-message)
                success_message="${2}"
                shift 2
                ;;
            --failure-message)
                failure_message="${2}"
                shift 2
                ;;
            --verbose)
                do_verbose=true
                do_quiet=false
                shift 1
                ;;
            --exit-success)
                exit_success_eval="${2}"
                shift 2
                ;;
            --exit-failure)
                exit_failure_eval="${2}"
                shift 2
                ;;
            -o | --optional)
                optional_dependencies+=("${2}")
                shift 2
                ;;
            -O | --one-of)
                # syntax: --one-of name="dep1 dep2 dep3"
                if ! [[ "${2}" =~ = ]]; then
                    echo "error: --one-of requires an argument in the format: name=\"dep1 dep2 dep3\"" >&2
                    exit 1
                fi
                local name="${2%%=*}"
                local deps="${2#*=}"
                one_of["${name}"]="${deps}"
                shift 2
                ;;
            -R | --os)
                required_os="${2}"
                shift 2
                ;;
            --root)
                required_user="root"
                shift 1
                ;;
            -u | --user)
                required_user="${2}"
                shift 2
                ;;
            -U | --uid)
                required_uid="${2}"
                shift 2
                ;;
            -g | --group)
                required_group="${2}"
                shift 2
                ;;
            -G | --gid)
                required_gid="${2}"
                shift 2
                ;;
            -r | --read)
                read_filepaths+=("${2}")
                shift 2
                ;;
            -w | --write)
                write_filepaths+=("${2}")
                shift 2
                ;;
            -n | --is-set)
                set_variables+=("${2}")
                shift 2
                ;;
            -z | --is-empty)
                empty_variables+=("${2}")
                shift 2
                ;;
            -v | --value)
                # syntax: --value name="value"
                if ! [[ "${2}" =~ = ]]; then
                    echo "error: --value requires an argument in the format: name=\"value\"" >&2
                    exit 1
                fi
                local value1="${2%%=*}"
                local value2="${2#*=}"
                values["${value1}"]="${value2}"
                shift 2
                ;;
            -V | --variable-value)
                # syntax: --variable-value varname="value"
                if ! [[ "${2}" =~ = ]]; then
                    echo "error: --variable-value requires an argument in the format: varname=\"value\"" >&2
                    exit 1
                fi
                local varname="${2%%=*}"
                local value="${2#*=}"
                variable_values["${varname}"]="${value}"
                shift 2
                ;;
            -q | --quiet)
                do_quiet=true
                shift 1
                ;;
            --no-exit)
                do_exit_on_failure=false
                shift 1
                ;;
            *)
                required_dependencies+=("${1}")
                shift 1
                ;;
        esac
    done

    ## Setup

    # If quiet mode is enabled, then redirect all output to /dev/null and setup
    # a trap to restore the output when the function exits
    if ${do_quiet}; then
        function __restore_output() {
            exec 1>&9 2>&8 9>&- 8>&-
        }
        exec 9>&1 8>&2 1>/dev/null 2>&1
        trap __restore_output RETURN
    fi


    ## Run dependency checks

    # Evaluate any supplied commands
    if [[ -n "${exit_success_eval}" ]]; then
        eval "${exit_success_eval}"
        if [[ ${?} -ne 0 ]]; then
            error_messages+=("eval did not exit with a success code")
            exit_code=1
        fi
    fi

    if [[ -n "${exit_failure_eval}" ]]; then
        eval "${exit_failure_eval}"
        if [[ ${?} -eq 0 ]]; then
            error_messages+=("eval did not exit with a failure code")
            exit_code=1
        fi
    fi

    # Check the OS
    if [[ -n "${required_os}" ]]; then
        local current_os=$(grep -Po '(?<=^ID=).+' /etc/os-release)
        if [[ "${current_os}" != "${required_os}" ]]; then
            error_messages+=("must be run on ${required_os}")
            exit_code=1
        fi
    fi

    # Check for uid/user
    if [[ -n "${required_uid}" ]]; then
        # set the required user to the user name
        required_user="$(id -u "${required_uid}" -n 2>&1)"
        if [[ ${?} != 0 ]]; then
            error_messages+=("user with uid ${required_uid} does not exist")
            required_user=""
            exit_code=1
        fi
    fi
    if [[ -n "${required_user}" ]]; then
        if [[ "${required_user}" != "$(id -un)" ]]; then
            error_messages+=("must be run as ${required_user}")
            exit_code=1
        fi
    fi

    # Check for gid/group
    if [[ -n "${required_gid}" ]]; then
        # set the required group to the group name
        required_group="$(getent group "${required_gid}" | cut -d: -f1)"
    fi
    if [[ -n "${required_group}" ]]; then
        if ! getent group "${required_group}" | grep -qE ":${USER}$"; then
            error_messages+=("user must be in group '${required_group}'")
            exit_code=1
        fi
    fi

    # Check for read permissions
    for filepath in "${read_filepaths[@]}"; do
        if [[ ! -r "${filepath}" ]]; then
            error_messages+=("must have read permissions for '${filepath}'")
            exit_code=1
        fi
    done

    # Check for write permissions
    for filepath in "${write_filepaths[@]}"; do
        local check_filepath=true
        # If the filepath does not exist, then check if its parent directory is
        # writable
        if [[ ! -e "${filepath}" ]]; then
            local parent_dir
            parent_dir="$(dirname "${filepath}")"

            # If the parent directory also doesn't exist, then exit with an
            # error
            if [[ ! -e "${parent_dir}" ]]; then
                error_messages+=("must have write permissions for '${filepath}', but parent directory '${parent_dir}' does not exist")
                exit_code=1
                check_filepath=false
            else
                filepath="${parent_dir}"
            fi
        fi
        if ${check_filepath} && [[ ! -w "${filepath}" ]]; then
            error_messages+=("must have write permissions for '${filepath}'")
            exit_code=1
        fi
    done

    # Check for set variables
    for var in "${set_variables[@]}"; do
        if [[ -z "${!var}" ]]; then
            error_messages+=("variable '${var}' must be set")
            exit_code=1
        fi
    done

    # Check for empty variables
    for var in "${empty_variables[@]}"; do
        if [[ -n "${!var}" ]]; then
            error_messages+=("variable '${var}' must be empty")
            exit_code=1
        fi
    done

    # Check values
    for key in "${!values[@]}"; do
        if [[ "${key}" != "${values["${key}"]}" ]]; then
            error_messages+=("value '${key}' is not '${values["${key}"]}'")
            exit_code=1
        fi
    done

    # Check variable values
    for var in "${!variable_values[@]}"; do
        if [[ "${!var}" != "${variable_values["${var}"]}" ]]; then
            error_messages+=("variable '${var}' is set to '${!var}', not '${variable_values["${var}"]}'")
            exit_code=1
        fi
    done

    # Check for required dependencies
    for dep in "${required_dependencies[@]}"; do
        if ! command -v "${dep}" &> /dev/null; then
            error_messages+=("missing required command: '${dep}'")
            exit_code=1
        fi
    done

    # Check for optional dependencies
    for dep in "${optional_dependencies[@]}"; do
        if ! command -v "${dep}" &> /dev/null; then
            warning_messages+=("missing optional command: '${dep}'")
        fi
    done

    # Check for one of a set of dependencies
    for name in "${!one_of[@]}"; do
        local found=false
        local found_dep
        for dep in ${one_of["${name}"]}; do
            if command -v "${dep}" &> /dev/null; then
                found=true
                found_dep="${dep}"
                break
            fi
        done
        if ! ${found}; then
            error_messages+=("missing '${name}': ${one_of["${name}"]}")
            exit_code=1
        else
            # Set the variable to the found dependencies
            read -r "${name}" <<< "${found_dep}"
        fi
    done


    ## Output the results

    # First, check to see if we need to suppress the output
    local suppress_output=false
    if [[
        (-n "${failure_message}" && "${do_verbose}" == "false") ||
        "${do_quiet}" == "true"
    ]]; then
        suppress_output=true
    fi

    # Print any warning messages
    if ! ${suppress_output}; then
        for msg in "${warning_messages[@]}"; do
            echo "warning: ${msg}" >&2
        done

        # Print any error messages
        if [[ ${exit_code} -ne 0 ]]; then
            for msg in "${error_messages[@]}"; do
                echo "error: ${msg}" >&2
            done
        fi
    fi

    # If there were explicit success and failure messages, then print them
    if [[ ${exit_code} -eq 0 ]] && [[ -n "${success_message}" ]]; then
        echo "${success_message}"
    elif [[ ${exit_code} -ne 0 ]] && [[ -n "${failure_message}" ]]; then
        echo "${failure_message}" >&2
    fi

    # If this function is being called from an interactive shell, then
    # exit on failure, else return
    if ${do_exit_on_failure} && [[ ! "${-}" =~ i && "${exit_code}" -ne 0 ]]; then
        if ! ${suppress_output}; then
            echo "exiting due to unmet dependencies" >&2
        fi
        exit "${exit_code}"
    fi
    return "${exit_code}"
}

# @description Run benchmarks on a command
# @usage benchmark --iterations <num> command [args...]
function benchmark() {
    local iterations=1
    local do_silent=false
    local do_progress=true
    local do_show_output=false
    local cmd=()

    # determine these after processing the args
    local progress_as_header=false
    local progress_as_inplace=false

    # Parse the command and arguments
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            --iterations)
                iterations="${2}"
                shift 2
                ;;
            --silent)
                do_silent=true
                shift 1
                ;;
            --progress)
                do_progress=true
                shift 1
                ;;
            --no-progress)
                do_progress=false
                shift 1
                ;;
            --show-output)
                do_show_output=true
                shift 1
                ;;
            --no-show-output)
                do_show_output=false
                shift 1
                ;;
            --)
                shift 1
                cmd+=("${@}")
                break
                ;;
            *)
                cmd+=("${1}")
                shift 1
                ;;
        esac
    done

    # If showing progress *and* output, then show a header above each iteration
    if ${do_progress}; then
        if ${do_show_output}; then
            progress_as_header=true
        else
            progress_as_inplace=true
        fi
    fi

    if ${do_silent}; then
        exec 9>/dev/null 8>/dev/null
    else
        exec 9>&1 8>&2
    fi

    if ${do_show_output}; then
        exec 3>&1 4>&2
    else
        exec 3>/dev/null 4>/dev/null
    fi

    debug-vars do_silent iterations cmd

    # Run the command the specified number of times
    time (
        for ((i = 0; i < iterations; i++)); do
            # # Print the progress header
            # if ${progress_as_header}; then
            #     echo -e "\033[1miteration\033[0m ${i}"
            # elif ${progress_as_inplace}; then
            #     printf '\r[%d/%d] ' "${i}" "${iterations}"
            # fi
            "${cmd[@]}"
        done 1>&9 2>&8
    )

    # Restore the output
    exec 9>&- 8>&- 3>&- 4>&-
}

# @description Print a function definition, optionally renaming it
# @usage print-function <function name> [<new name>]
function print-function() {
    local f_name="${1}"
    local f_name_new="${2:-${f_name}}"
    local f_declare

    # Ensure a function was given
    [[ -z "${f_name}" ]] && return

    # Get the function declaration and exit with an error if it doesn't exist
    f_declare=$(declare -f "${f_name}" 2>/dev/null)
    if [[ -z "${f_declare}" ]]; then
        echo "error: no such function '${f_name}'" >&2
        return 1
    fi

    # Print the function source, optionally renaming the function
    awk -v name="${f_name_new}" '
        NR == 1 { printf("function %s() {\n", name) }
        NR > 2
    ' <<< "${f_declare}"
}

# @description Split a quoted string into an array (xargs quoting applies)
# @usage split-quoted <quoted string> [<array name>]
# @example
#     $ split-quoted "one two 'three four' five" NUMBER_ARRAY
#     $ declare -p NUMBER_ARRAY
#     declare -a NUMBER_ARRAY=([0]="one" [1]="two" [2]="three four" [3]="five")
function split-quoted() {
    local quoted="${1}"
    local varname="${2:-SPLIT_ARRAY}"
    local lines
    local err_msg exit_code=0

    # Link the local `arr` to the specified variable name
    declare -n arr="${varname}"

    # Split the quoted string into lines
    if lines=$(xargs -n1 printf '%s\n' <<< "${quoted}" 2>&1); then
        # Read the lines into the array
        readarray -t arr <<< "${lines}"

        # Print the array
        printf '%s\n' "${arr[@]}"
    else
        exit_code=1
        # Look for the error
        err_msg=$(grep '^xargs: .*' <<< "${lines}")
        err_msg="${err_msg#xargs: }"
        err_msg="${err_msg%%;*}"
        echo "error: ${err_msg}" >&2
    fi

    # Unlink the local `arr`
    unset -n arr

    return ${exit_code}
}

function search-back() {
    :  'Search for a file or directory traversing parent directories

        This function searches for a file or directory by traversing parent
        directories until (a) it finds the file or directory or (b) it reaches
        the root directory.

        @usage
            [-d/--directory] [-f/--file] [-h/--help] [-m/--max-depth <num>]
            [-v/--verbose] <name>
        
        @option -h/--help
            Print this help message and exit.
        
        @option -d/--directory
            Search for a directory.
        
        @option -f/--file
            Search for a file.
        
        @option -m/--max-depth <num>
            The maximum number of directories to search before giving up.
        
        @option -v/--verbose
            Print the directories being searched.
        
        @arg name
            The name of the file or directory to search for.
        
        @stdout
            The full path to the file or directory if found.
        
        @return 0
            If the file or directory is found.
        
        @return 1
            If the file or directory is not found.
    '
    # Default values
    local do_verbose=false
    local do_directory=false
    local do_file=false
    local max_depth=-1 # -1 means no limit
    local name

    # Parse the options
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -h | --help)
                echo "${FUNCNAME[0]}: ${1}"
                grep -E '^\s+\#\s+' "${BASH_SOURCE[0]}" | sed 's/^\s\+#\s\+//'
                return 0
                ;;
            -d | --directory)
                do_directory=true
                do_file=false
                shift
                ;;
            -f | --file)
                do_file=true
                do_directory=false
                shift
                ;;
            -m | --max-depth)
                max_depth="${2}"
                shift 2
                ;;
            -v | --verbose)
                do_verbose=true
                shift
                ;;
            --)
                shift
                name="${@}"
                break
                ;;
            *)
                name="${1}"
                shift
                ;;
        esac
    done

    # Ensure a name was given
    [[ -z "${name}" ]] && return 1

    # Disallow "." and ".."
    if [[ "${name}" =~ ^(.*/)?\.\.?(/.*)?$ ]]; then
        echo "error: path cannot include './' or '../'" >&2
        return 1
    fi

    # If no file or directory option was given, search for both
    if ! ${do_directory} && ! ${do_file}; then
        do_directory=true
        do_file=true
    fi

    debug-vars do_verbose do_directory do_file max_depth name

    # Set up a trap to restore the current directory on function return
    local _search_back_pwd="${PWD}"
    restore_search_back_pwd() {
        cd "${_search_back_pwd}"
    }
    trap restore_search_back_pwd RETURN

    # Traverse the parent directories
    local depth=0
    local match=""
    while [[ -z "${match}"  ]]; do
        # Print the current directory if verbose mode is enabled
        if ${do_verbose}; then
            echo "${PWD}"
        fi

        # Search for the file or directory
        if ${do_directory} && [[ -d "${name}" ]]; then
            match="${PWD%/}/${name}"
        elif ${do_file} && [[ -f "${name}" ]]; then
            match="${PWD%/}/${name}"
        fi

        # Check if the maximum depth has been reached
        if [[ ${max_depth} -gt 0 ]] && [[ ${depth} -ge ${max_depth} ]]; then
            break
        fi

        # If we've just chceked the root directory, break out of the loop
        if [[ "${PWD}" == "/" ]]; then
            break
        fi

        # Move up a directory
        cd ..
        ((depth++))
    done

    # Return the result
    if [[ -n "${match}" ]]; then
        echo "${match}"
        return 0
    fi
    return 1
}