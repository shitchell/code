# returns the name of the current shell
function get-shell() {
    basename "`ps -p "$$" -o args= | awk '{print $1}' | sed 's/^-//'`" \
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

# Checks if an item is in an array.
# usage: in-array <item> "${array[@]}"
# returns 0 if the item is in the array, 1 otherwise
function in-array() {
    local item=${1}
    local array=${2}
    local e
    for e in ${array[@]}; do
        if [ "${e}" = "${item}" ]; then
            return 0
        fi
    done
    return 1
}

# Get the index of an item in an array.
# usage: index-of <item> "${array[@]}"
# returns the index of the item in the array, or -1 if not found
function index-of() {
    local item=${1}
    shift
    local array=("${@}")

    local e
    local index=0
    local ret_value=-1
    for e in "${!array[@]}"; do
        if [ "${array[$e]}" = "${item}" ]; then
            ret_value=${index}
            break
        fi
        index=$((index + 1))
    done

    echo ${ret_value}
    return ${ret_value}
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
