: 'Module for importing functions from bash & zsh scripts.

`include-source <filename>` will search the current directory or
<SHELL>_PATH_LIB (falls back on PATH if unset) for <filename>, then source it
into the current shell. Scripts that call `include-source` can be "compiled"
with `compile-sources` to replace any calls to `include-source` with the
contents of the included script.

I have a lot of useful utility functions that I like to reuse across my
scripts, but copy/pasting them is annoying, and deploying many bash scripts to
a client can get untidy. These functions allow me to keep all of those utility
functions in one place, which allows me to much more quickly employ them and
cut down development time, while still being able to deploy just one compiled
file to a client.

# Setup

  1. Setup the lib dir(s)
     * create a <SHELL>_LIB_PATH environment variable to include the directories
       to search for importable scripts, e.g.:
         export BASH_LIB_PATH="$HOME/bin/lib:$HOME/code/bash/lib"
         export ZSH_LIB_PATH="$HOME/bin/lib:$HOME/code/zsh/lib"
     * OR create a LIB_DIR environment variable to include a single directory
       to search for importable scripts, e.g.:
         export LIB_DIR="$HOME/code/bash/lib"
  2. Source this script in your shell.

# Usage

```sh
include-source "<script_name[.sh]|url>"
compile-sources "<script_path>" ["<script_path>" ...]
```

# Example

## Add these lines to ~/.bashrc to enable the include/compile functions

```sh
# ~/.bashrc

export BASH_LIB_PATH="$HOME/bin/lib:$HOME/code/bash/lib"
source "$HOME/code/bash/lib/include.sh"
```

## Write two bash "libraries" to be imported into other scripts:

```sh
# $HOME/code/bash/lib/somelib.sh

function somelib_func() {
  echo "Hello from somelib_func!"
}
```

```sh
# https://raw.githubusercontent.com/foo/bar/master/gitlib.sh

function gitlib_func() {
  echo "[gitlib_func] $@"
  return 0
}
```

## Write a script that imports the above two libraries

```sh
# ./foo.sh

#!/usr/bin/env bash

include-source "https://raw.githubusercontent.com/foo/bar/master/gitlib.sh"
include-source "somelib"

if gitlib_func "do the thing"; then
  somelib_func "we did the thing!"
fi
```

## Run the script

```sh
$ ./foo.sh
[gitlib_func] do the thing
Hello from somelib_func!
```

## Optionally, compile the above script into a single file

Compile ./foo.sh to ./foo.compiled.sh
```sh
$ compile-sources ./foo.sh > foo.compiled.sh
$ cat ./foo.compiled.sh
#!/usr/bin/env bash

# include-source "https://raw.githubusercontent.com/foo/bar/master/gitlib.sh"
function gitlib_func() {
  echo "[gitlib_func] $@"
  return 0
}
# compile-sources: end of "https://raw.githubusercontent.com/foo/bar/master/gitlib.sh"
# include-source "somelib"
function somelib_func() {
  echo "Hello from somelib_func!"
}
# compile-sources: end of "somelib.sh"

if func_from_gitlib "do the thing"; then
  func_from_somelib "we did the thing!"
fi
```

Compile multiple files in place
```sh
$ compile-sources -i ./foo.sh ./bar.sh
```

Remove, instead of commenting out, the `include-source` call from the compiled
file and do not include the closing tag at the end of the included source code
```sh
$ compile-sources -i -T "./foo.sh" "./bar.sh"
```

# TODO
  - Prevent infinite recursion in include-source
  - Make compile-sources work for `source` calls as well
  - Use regex to import only functions from the included script
    - Allow for modifying imported function names with a prefix/suffix
'

## helpful functions ###########################################################
################################################################################

function __debug() {
    :  'Print a debug message if DEBUG or DEBUG_LOG is set

        @usage
            [<msg> ...]

        @optarg <msg>
            The message to print

        @return 0
            If debugging is enabled

        @return 1
            If debugging is not enabled

        @stderr
            The message to print
    '
    local prefix timestamp
    if [[
            "${INCLUDE_DEBUG}" == "1"
            || "${INCLUDE_DEBUG}" == "true"
            || -n "${INCLUDE_DEBUG_LOG}"
        ]]; then
        [[ ${#} -eq 0 ]] && return 0
        timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
        prefix="\033[36m[${timestamp}]\033[0m "
        prefix+="\033[35m$(basename "${BASH_SOURCE[-1]}")"
        [[ "${FUNCNAME[1]}" != "main" ]] && prefix+="\033[1m:${FUNCNAME[1]}()\033[0m"
        prefix+="\033[32m:${BASH_LINENO[0]}\033[0m -- "
        printf "%s\n" "${@}" \
            | awk -v prefix="${prefix}" '{print prefix $0}' >> "${INCLUDE_DEBUG_LOG:-/dev/stderr}"
    else
        return 1
    fi
}

function get-shell() {
    :  'Reliably determine the current shell

        @stdout
            The current shell
    '
    local process_name=$(ps -p "$$" -o args= | awk '{print $1}' | sed 's/^-//')
    local shell=$(basename "${process_name}" | tr '[:upper:]' '[:lower:]')
    echo "${shell}"
}

function functionname() {
    :  'Cross-shell function for returning the calling function name

        @usage
            [<stack index>]
    
        @optarg <stack index>
            The index of the function in the call stack to return

        @stdout
            The name of the calling function
        
        @return 0
            If the function name was successfully returned
        
        @return 108
            If the shell is not recognized
    '
    local shell=$(get-shell)
    local index=${1:- -1}
    case "${shell}" in
        bash)
            echo ${FUNCNAME[${index}]}
            ;;
        zsh)
            echo ${funcstack[${index}]}
            ;;
        *)
            echo "unknown shell: ${shell}" >&2
            return 108
            ;;
    esac
}

function in-array() {
    :  'Checks if an item is in an array.

        @usage
            <item> <array-item-1> [<array-item-2> ...

        @arg <item>
            The item to check for in the array
        
        @arg+
            The array to check

        @return 0
            The item is in the array

        @return 1
            The item is not in the array
    '
    #__debug "_call(${@})"

    local item array el
    item="${1}"
    array=( "${@:2}" )

    for el in ${array[@]}; do
        if [[ "${el}" == "${item}" ]]; then
            return 0
        fi
    done

    return 1
}


## include-source ##############################################################
################################################################################

## Usage functions
###

function __include_source_help_usage() {
    echo "usage: $(functionname) [-hlnNcCvV] <path>"
}

function __include_source_help_epilogue() {
    echo "import shell scripts"
}

function __include_source_help_full() {
    __include_source_help_usage
    __include_source_help_epilogue
    echo
    echo "Imports the specified shell script. The specified script can be the"
    echo "name of a script in <SHELL>_LIB_PATH, the name of a script in PATH,"
    echo "the name of a script in the current directory, or a url to a script."
    echo
    cat << EOF
    -h/--help          show help info
    -l/--location      print the location of the imported script
    -n/--dry-run       don't import the script
    -N/--no-dry-run    import the script
    -c/--cat           print the contents of the imported script
    -C/--no-cat        don't print the contents of the imported script
    -v/--verbose       be verbose
    -V/--no-verbose    don't be verbose
EOF
}

function __include_source_parse_args() {
    # default values
    VERBOSE=0
    DO_CAT=0
    DO_SOURCE=1
    SHOW_LOCATION=0

    # parse arguments
    POSITIONAL_ARGS=()
    while [[ ${#} -gt 0 ]]; do
        local arg="$1"
        case "$arg" in
            -v | --verbose)
                VERBOSE=1
                shift
                ;;
            -V | --no-verbose)
                VERBOSE=0
                shift
                ;;
            -l | --location)
                SHOW_LOCATION=1
                shift
                ;;
            -L |--no-location)
                SHOW_LOCATION=0
                shift
                ;;
            -N | --no-source)
                DO_SOURCE=0
                shift
                ;;
            -n | --source)
                DO_SOURCE=1
                shift
                ;;
            -c | --cat)
                DO_CAT=1
                shift
                ;;
            -C | --no-cat)
                DO_CAT=0
                shift
                ;;
            -h)
                __include_source_help_usage
                __include_source_help_epilogue
                return 3
                ;;
            --help)
                __include_source_help_full
                return 3
                ;;
            -*)
                echo "$(functionname): invalid option '$arg'" >&2
                return 1
                ;;
            *)
                POSITIONAL_ARGS+=("$arg")
                shift
                ;;
        esac
    done
    set -- "${POSITIONAL_ARGS[@]}"
}


## Helpful functions
###

function __bash_libs_get_path() {
    : '
    Return the value of <SHELL>_LIB_PATH or PATH if it is not set.

    @stdout     The value of <SHELL>_LIB_PATH or PATH
    '
    #__debug "_call(${@})"
    local path shell_lower shell_upper lib_path lib_path_value

    # reliably determine the shell
    local shell_lower=$(get-shell)
    local shell_upper=$(echo "${shell_lower}" | tr '[:lower:]' '[:upper:]')

    # determine the current shell's lib path
    local lib_path_name="${shell_upper}_LIB_PATH"
    #__debug "lib_path_name: ${lib_path_name}"

    # load the value of the lib path from the environment
    if [ "${shell_lower}" = "bash" ]; then
        #__debug "getting bash lib path"
        local lib_path_value="${!lib_path_name}"
    elif [ "${shell_lower}" = "zsh" ]; then
        #__debug "getting zsh lib path"
        local lib_path_value="${(P)lib_path_name}"
    else
        #__debug "attempting generic lib path eval"
        # attempt a generic eval, although chances are low that the rest of
        # the module will work even if this does
        eval local lib_path_value="\$${lib_path_name}"
        if [ $? -ne 0 ]; then
            echo "$(functionname): failed to determine the value of '${lib_path_name}'" >&2
            return 1
        fi
    fi

    lib_path="${lib_path_value:-${PATH}}"

    # If LIB_DIR is set, append it to the lib path
    if [[ -n "${LIB_DIR}" ]]; then
        [[ -n "${lib_path}" ]] \
            && lib_path="${LIB_DIR}:${lib_path}" \
            || lib_path="${LIB_DIR}"
    fi

    #__debug "lib_path: ${lib_path}"
    echo "${lib_path}"
}

function __bash_libs_get_filepath() {
    : '
    Given a library name (with or without the .sh extension), get its filepath
    in the current directory, <SHELL>_LIB_PATH, or PATH

    @usage      <filename>[.sh]
    @stdout     The path to the file
    '
    #__debug "_call(${@})"

    local filename="${1}"

    # look for the file in the current directory with and without the .sh
    # extension
    if [[ -f "$(pwd)/${filename}" && -r "$(pwd)/${filename}" ]]; then
        echo "$(pwd)/${filename}"
        return 0
    elif [[ -f "$(pwd)/${filename}.sh" && -r "$(pwd)/${filename}.sh" ]]; then
        echo "$(pwd)/${filename}.sh"
        return 0
    fi

    # Try to find the path in <SHELL>_LIB_PATH or PATH, with or without the .sh
    local lib_path_array
    IFS=":" read -ra lib_path_array <<< "$(__bash_libs_get_path)"
    #__debug "lib_path_array: ${lib_path_array[@]}"
    for dir in "${lib_path_array[@]}"; do
        #__debug "looking for '${filename}' in '${dir}'"
        # determine if a readable file with the given name exists in this dir
        if [[ -f "${dir}/${filename}" && -r "${dir}/${filename}" ]]; then
            #__debug "found '${filename}' in '${dir}'"
            echo "${dir}/${filename}"
            return 0
        elif [[ -f "${dir}/${filename}.sh" && -r "${dir}/${filename}.sh" ]]; then
            #__debug "found '${filename}.sh' in '${dir}'"
            echo "${dir}/${filename}.sh"
            return 0
        fi
    done

    # if we get here, we didn't find the file
    return 1
}

function __bash_libs_get_location() {
    : '
    Get the location of the shell lib, whether a file or url

    @usage      <filename>
    @stdout     The location of the file
    '
    #__debug "_call(${@})"

    local filename="${1}"

    # determine if the file is a filepath or a url
    if [ "${filename}" =~ ^https?:// ]; then
        echo "${filename}"
        return 0
    fi

    local filepath="$(__bash_libs_get_filepath "${filename}")"
    if [ $? -eq 0 ]; then
        echo "${filepath}"
        return 0
    fi
    return 1
}

## Main functions
###

# Import a shell script from a url
function source-url() {
    : '
    Download a shell script from a url and source it in the current shell

    @usage <url>
    '
    #__debug "_call(${@})"

    local url="${1}"
    local filename="${url##*/}"

    # treat the filename as a url
    if [ "${SHOW_LOCATION}" -eq 1 ] 2>/dev/null; then
        echo "${url}"
        return 0
    elif [ "${VERBOSE}" -eq 1 ] 2>/dev/null; then
        echo "$(functionname): sourcing '${filename}'"
    fi

    # download the script
    local tmp_dir=$(mktemp -dt "`functionname`.XXXXX")
    local script_file="${tmp_dir}/${filename}"

    curl -s -o "${script_file}" "${url}"
    if [ $? -ne 0 ] && [ "${VERBOSE}" -eq 1 ]; then
        echo "$(functionname): failed to download '${filename}'" >&2
        return 1
    fi

    # print the contents of the script if requested
    if [ "${DO_CAT}" -eq 1 ]; then
        cat "${script_file}"
    fi

    # source the contents of the downloaded script
    if [ "${DO_SOURCE}" -eq 1 ]; then
        source "${script_file}"
        local source_exit_code=$?
    fi

    # remove the temporary directory
    rm -rf "${tmp_dir}"

    # return the exit code of the sourced script if available
    return ${source_exit_code:-0}
}

# Import a shell script from a filename
function source-lib() {
    : '
    Given a library name, find it in the LIB_PATH or PATH and source it in the
    current shell.

    @usage      <lib>[.sh]
    '
    #__debug "_call(${@})"

    local filename="${1}"

    # get the path to the file
    local filepath=$(__bash_libs_get_filepath "${filename}")

    # if we couldn't find the file, exit with an error
    if [ -z "${filepath}" ]; then
        echo "$(functionname): failed to find '${filename}'" >&2
        return 1
    fi

    # print the location of the file if requested
    if [ "${SHOW_LOCATION}" -eq 1 ]; then
        echo "${filepath}"
        return 0
    fi

    # print the contents of the script if requested
    if [ "${DO_CAT}" -eq 1 ]; then
        cat "${filepath}"
    fi

    # source the file
    if [ "${DO_SOURCE:-1}" -eq 1 ]; then
        if [ "${VERBOSE:-0}" -eq 1 ]; then
            echo "$(functionname): sourcing '${filepath}'"
        fi
        source "${filepath}"
        return $?
    fi
}

# Import a shell script from ${<SHELL>_LIB_PATH:-${PATH}} given a filename
function include-source() {
    : '
    Given a library name or url, source it in the current shell.

    @usage      [-h/--help] [-l/--location] [-L/--no-location] [-n/--dry-run]
                [-N/--no-dry-run] [-c/--cat] [-C/--no-cat] [-v/--verbose]
                [-V/--no-verbose] <filename>
    '
    #__debug "_call(${@})"

    local filename="${1}"
    local exit_code=0

    __include_source_parse_args "$@"
    case $? in 0);; 3) return 0 ;; *) return $?;; esac

    local filename="${POSITIONAL_ARGS[0]}"

    # ensure the filename is not empty
    if [ -z "$filename" ]; then
        __include_source_help_usage >&2
        exit_code=1
    else
        # determine whether to treat the filename as a filepath or url
        if [[ "${filename}" =~ ^https?:// ]]; then
            # treat the filename as a url
            source-url "${filename}"
            exit_code=${?}
        else
            source-lib "${filename}"
            exit_code=${?}
        fi
    fi

    unset POSITIONAL_ARGS SHOW_LOCATION VERBOSE DO_CAT DO_SOURCE
    return ${exit_code}
}


## compile-sources #############################################################
################################################################################

## Usage functions
###

function __compile_sources_help_usage() {
    echo "usage: $(functionname) [-hiItT] <file> [<file> ...]"
}

function __compile_sources_help_epilogue() {
    echo 'replace `include-source` calls with the contents of the included file'
}

function __compile_sources_help_full() {
    __compile_sources_help_usage
    __compile_sources_help_epilogue
    echo
    echo "Generates a single compiled shell script that contains the source"
    echo "of the original script along with the source of each included script."
    echo
    cat << EOF
    -h/--help          show help info
    -i/--in-place      replace the original script with the compiled script
    -I/--no-in-place   print the compiled script to stdout
    -b/--backups       keep backups of the original script when replacing it
    -B/--no-backups    do not keep backups of the original script
    -t/--tags          print markers at the beginning and end of each included
                       script
    -T/--no-tags       do not print markers at the beginning and end of each
                       included script
EOF
}

function __compile_sources_parse_args() {
    # default values
    IN_PLACE=0
    IN_PLACE_BACKUPS=1
    INCLUDE_TAGS=1

    # parse arguments
    POSITIONAL_ARGS=()
    while [[ ${#} -gt 0 ]]; do
        local arg="$1"
        case "$arg" in
            -i|--in-place)
                IN_PLACE=1
                shift
                ;;
            -I|--no-in-place)
                IN_PLACE=0
                shift
                ;;
            -b|--backups)
                IN_PLACE_BACKUPS=1
                shift
                ;;
            -B|--no-backups)
                IN_PLACE_BACKUPS=0
                shift
                ;;
            -t|--tags)
                INCLUDE_TAGS=1
                shift
                ;;
            -T|--no-tags)
                INCLUDE_TAGS=0
                shift
                ;;
            -h)
                __compile_sources_help_usage
                __compile_sources_help_epilogue
                return 3
                ;;
            --help)
                __compile_sources_help_full
                return 3
                ;;
            -*)
                echo "$(functionname): invalid option '$arg'" >&2
                return 1
                ;;
            *)
                POSITIONAL_ARGS+=("$arg")
                shift
                ;;
        esac
    done
    set -- "${POSITIONAL_ARGS[@]}"
}


## helpful functions
###

# Check if the given filepath has any valid `include-source` or `source` calls.
# If the given filepath is "-", read from stdin
function __compile_sources_has_source_calls() {
    local filepath="${1}"

    # get the file's contents
    local contents
    if [ "${filepath}" = "-" ]; then
        contents=$(cat)
    else
        contents=$(cat "${filepath}")
    fi
    echo "${contents}" | grep -Eq '^(include-)?source\b'
}

# Returns the line number of and shell lib specified by  the first occurrence of
# "^include-source\b" in the given file. If '-' is specified, read from stdin
function __compile_sources_find_include_source_line() {
    local filename="${1:- -}"

    # get the contents of the file
    local file_contents
    if [ "${filename}" = "-" ]; then
        file_contents=$(cat)
    else
        file_contents=$(<"${filename}")
    fi

    # get the line number of the first "include-source" line
    local line_number=$(
        echo "${file_contents}" \
        | grep -n "^include-source\b" \
        | cut -d ':' -f1 \
        | head -n1
    )

    # if we couldn't find the line number, exit with an error
    if [ -z "${line_number}" ]; then
        return 1
    fi

    # get the line content of that "include-source" line
    local line=$(echo "${file_contents}" | sed -n "${line_number}p")

    # get the sourced filename from the line
    local sourced_filename=$(echo "${line}" | awk -F " " '{print $2}')

    # remove any single or double quotes from the beginning/end of the filename
    sourced_filename="$(echo "${sourced_filename}" | sed "s/^[\"']//;s/[\"']$//")"

    echo "${line_number}:${sourced_filename}"
}

# accepts a filepath and replaces all "^include-source\b" lines with the
# contents of the included file. if the filepath is '-', read from stdin.
# compiled scripts are output to stdout
# exit codes:
#  0 - success
#  1 - one or more included libs was empty
#  2 - error parsing source file
function __compile_sources() {
    #__debug "_call(${@})"

    # get the filepath
    local filepath="${1}"

    # treat any remaining arguments as already included files from recursive calls
    shift
    local included_sources=("$@")

    # get the file contents
    if [ "${filepath}" = "-" ]; then
        local file_contents=$(cat)
    else
        local file_contents=$(<"${filepath}")
    fi

    # loop while we can find "^include-source\b" lines
    while grep -q "^include-source\b" <<< "${file_contents}"; do
        # get the line number of the first "include-source" line
        local include_source_line=$(echo "${file_contents}" | __compile_sources_find_include_source_line -)
        local line_number=$(echo "${include_source_line}" | cut -d ':' -f1)
        local sourced_filename=$(echo "${include_source_line}" | cut -d ':' -f2)

        # check whether the source has already been included
        if in-array "${sourced_filename}" "${included_sources[@]}"; then
            # if it has, remove the "include-source" line from the file
            local file_contents=$(echo "${file_contents}" | sed -e "${line_number}d")
            continue
        fi

        # add the sourced file to the stack of libs that have been included
        included_sources+=("${sourced_filename}")

        # get the filepath or url of the source
        local included_filepath=$(include-source -l "${sourced_filename}")

        # get the contents of the lib
        local sourced_contents=$(include-source -n --cat "${sourced_filename}" 2>&1)
        local sourced_contents_exit_code=$?

        # if there was an error. exit with an error
        if [ ${sourced_contents_exit_code} -ne 0 ]; then
            echo "${sourced_contents}" >&2
            return 2
        fi

        # if the source file is empty, then exit with an error
        if [ -z "${sourced_contents}" ]; then
            echo "$(functionname): source file '${sourced_filename}' is empty" >&2
            return 1
        else
            # check to see if the source file contains any "include-source" lines
            if grep -q "^include-source\b" <<< "${sourced_contents}"; then
                # if it does, recursively compile the source file
                local sourced_contents=$(echo "${sourced_contents}" | __compile_sources - "${included_sources[@]}")
                # if the recursive sourcing returned a non-zero status, pass it on
                local recursive_exit_code=$?
                if [ "${recursive_exit_code}" -ne 0 ]; then
                    return "${recursive_exit_code}"
                fi
            fi
        fi

        # if we successfully loaded some content and include_tags is set,
        # then add a line to the end of the source indicating where it ends
        if [ "${INCLUDE_TAGS:-1}" -eq 1 ]; then
            local sourced_contents="${sourced_contents}"$'\n'"# $(functionname): end of '${sourced_filename}'"
        fi

        # if include_tags is set, comment out the include-source line and
        # add the source file contents after it, else just replace the
        # include-source line with the source file contents
        if [ "${INCLUDE_TAGS:-1}" -eq 1 ]; then
            # comment out the include-source line
            local file_contents=$(echo "${file_contents}" | sed "${line_number}s/^/# /")
        else
            # delete the include-source line
            local file_contents=$(echo "${file_contents}" | sed "${line_number}d")
            local line_number=$((line_number - 1))
        fi

        # if the line number is 0, then prepend the contents
        if [ "${line_number}" -eq 0 ]; then
            local file_contents="${sourced_contents}"$'\n'"${file_contents}"
        else
            # otherwise, insert the contents after the line number
            local file_contents=$(
                sed "${line_number}r /dev/stdin" \
                    <(echo "${file_contents}") \
                    <<< "${sourced_contents}"
            )
        fi
    done

    # output the compiled file
    echo "${file_contents}"
}


## main functions
###

function compile-sources() {
    : '
    Replace `include-source` calls with the source library contents.

    @usage      [-h/--help] [-i/--in-place] [-I/--no-in-place] [-b/--backups]
                [-B/--no-backups] [-t/--tags] [-T/--no-tags] <file> [<file> ...]
    '
    #__debug "_call(${@})"

    local exit_code=0
    local filepath="${1}"

    __compile_sources_parse_args "$@"
    # exit cleanly if help was displayed or with the exit code if non-zero
    case $? in 0);; 3) return 0 ;; *) return $?;; esac

    # loop over each file in the positional arguments
    for filepath in "${POSITIONAL_ARGS[@]}"; do
        # compile the file
        local compiled_file=$(__compile_sources "${filepath}")
        exit_code=$?

        # if the exit code is non-zero, exit with that code
        if [ "${exit_code}" -ne 0 ]; then
            break
        fi

        # output the compiled file or overwrite the original file as appropriate
        if [ "${IN_PLACE}" -eq 1 ]; then
            if [ "${IN_PLACE_BACKUPS}" -eq 1 ]; then
                # make a backup of the original file
                cp "${filepath}" "${filepath}.bak"
            fi
            echo "${compiled_file}" > "${filepath}"
        else
            echo "${compiled_file}"
        fi
    done

    unset DO_CAT DO_LIST DO_HELP IN_PLACE IN_PLACE_BACKUPS INCLUDE_TAGS POSITIONAL_ARGS
    return ${exit_code}
}


## Export Functions ############################################################
################################################################################

export -f __debug
export -f get-shell
export -f functionname
export -f in-array
export -f __include_source_help_usage
export -f __include_source_help_epilogue
export -f __include_source_help_full
export -f __include_source_parse_args
export -f __bash_libs_get_path
export -f __bash_libs_get_filepath
export -f __bash_libs_get_location
export -f source-url
export -f source-lib
export -f include-source
export -f __compile_sources_help_usage
export -f __compile_sources_help_epilogue
export -f __compile_sources_help_full
export -f __compile_sources_parse_args
export -f __compile_sources_find_include_source_line
export -f __compile_sources
export -f compile-sources


## Export Variables ############################################################
################################################################################

export INCLUDE_SOURCE="include-source"
