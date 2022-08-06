# Module for importing functions from shell scripts.
#
# `include-source <filename>` will search the current directory or
# <SHELL>_PATH_LIB (or PATH if that's not set) for a file with that name, then
# source it in the current shell. Scripts that call `include-source`
# can be "compiled" with `compile-sources` to replace any calls to
# `include-source` with the contents of the included script.
#
# I have a lot of useful utility functions that I like to reuse across my
# scripts, but copy/pasting them is annoying, and deploying many bash scripts to
# a client can get untidy. These functions allow me to keep all of those utility
# functions in one place, which allows me to much more quickly employ them and
# cut down development time, while still being able to deploy just one compiled
# file to a client.
#
#
# Setup:
#   1. Create a <SHELL>_LIB_PATH environment var to include the directories
#      to search for importable scripts.
#      e.g.: BASH_LIB_PATH or ZSH_LIB_PATH
#   2. Source this script in your shell.
#
#
# Usage:
#   include-source "<script_name|url>"
#   compile-sources "<script_path>" ["<script_path>" ...]
#
#
# Example:
#
#  Add these lines to your .bashrc to start using the include/compile functions:
#   : ~/.bashrc
#   export BASH_LIB_PATH="$HOME/bin/lib:$HOME/code/bash/lib"
#   source "$HOME/code/bash/lib/include.sh"
#
#  The source for a couple of bash "libraries" that we'll import into another:
#   : $HOME/code/bash/lib/somelib.sh
#   function somelib_func() {
#     echo "Hello from somelib_func!"
#   }
#
#   : https://raw.githubusercontent.com/foo/bar/master/gitlib.sh
#   function gitlib_func() {
#     echo "[gitlib_func] $@"
#     return 0
#   }
#
#  Our actual script, which imports the above two
#   : ./foo.sh
#   #!/bin/bash
#   include-source 'https://raw.githubusercontent.com/foo/bar/master/gitlib.sh'
#   include-source 'somelib.sh'
#   if gitlib_func "do the thing"; then
#     somelib_func "we did the thing!"
#   fi
#
#  Compiling the above script:
#   : <shell>
#   # compile ./foo.sh to ./foo.compiled.sh
#   $ compile-sources ./foo.sh > foo.compiled.sh
#
#   # compile multiple files in place
#   $ compile-sources -i ./foo.sh ./bar.sh
#
#   # remove, instead of commenting out, the `include-source` call from the
#   # compiled file and don't include the closing tag at the end of the included
#   # source code
#   $ compile-sources -i -T "./foo.sh" "./bar.sh"
#
#  The first generated script will look like this:
#   : ./foo.compiled.sh (generated from `compile-sources`)
#   #!/bin/bash
#   # include-source 'https://raw.githubusercontent.com/foo/bar/master/gitlib.sh'
#   function gitlib_func() {
#     echo "[gitlib_func] $@"
#     return 0
#   }
#   # compile-sources: end of 'https://raw.githubusercontent.com/foo/bar/master/gitlib.sh'
#   # include-source 'somelib.sh'
#   function somelib_func() {
#     echo "Hello from somelib_func!"
#   }
#   # compile-sources: end of 'somelib.sh'
#   if func_from_gitlib "do the thing"; then
#     func_from_somelib "we did the thing!"
#   fi
#
#
# TODO:
#   - Split code into functions
#   - Recursively compile sources
#     - Use a stack to track which files have already been compiled to prevent
#       infinite recursion or duplicate includes

# Search <SHELL>_LIB_PATH for and source a file with the given name
# Options:
#   -v: show more info about sourcing the file
#   -V: don't show more info about sourcing the file
#   -l: just show the path of the file that would be sourced without sourcing it
#   -n: don't source the file
#   -N: do source the file
#   -h: help
function include-source() {
    local usage="usage: include-source [-vV|--(no-)verbose] [-l|--location] [-nN|--(no-)source] [-h|--help] <file>"

    # default values
    local verbose=0
    local do_source=1
    local show_location=0

    # parse arguments
    local positional_args=()
    while [[ ${#} -gt 0 ]]; do
        local arg="$1"
        case "$arg" in
            -v|--verbose)
                verbose=1
                shift
                ;;
            -V|--no-verbose)
                verbose=0
                shift
                ;;
            -l|--location)
                show_location=1
                shift
                ;;
            -n|--no-source)
                do_source=0
                shift
                ;;
            -N|--source)
                do_source=1
                shift
                ;;
            -h|--help)
                echo ${usage}
                return 0
                ;;
            -*)
                echo "include-source: invalid option '$arg'" >&2
                return 1
                ;;
            *)
                positional_args+=("$arg")
                shift
                ;;
        esac
    done
    set -- "${positional_args[@]}"

    local filename="${1}"
    
    # ensure the filename is not empty
    if [ -z "$filename" ]; then
        echo ${usage} >&2
        return 1
    fi
    # determine whether to treat the filename as a filepath or url
    if [[ "${filename}" =~ ^https?:// ]]; then
        # treat the filename as a url
        if [ "${show_location}" -eq 1 ]; then
            echo "${filename}"
            return 0
        elif [ "${verbose}" -eq 1 ]; then
            echo "include-source: sourcing '${filename}'"
        fi
        if [ "${do_source}" -eq 1 ]; then
            local url_contents="$(curl -s "${filename}")"
            if [ $? -ne 0 ] && [ "${verbose}" -eq 1 ]; then
                echo "include-source: failed to download '${filename}'" >&2
                return 1
            fi
            # source the contents of the url. any output will be errors
            local source_errors=$(source <(curl -s "${filename}") 2>&1)
            if [ -n "${source_errors}" ]; then
                echo "include-source: failed to source '${filename}'" >&2
                echo "${source_errors}" >&2
                return 1
            fi
        fi
        return 0
    else
        # treat the filename as a filepath and search for it
        local filepath=""
        if [ -f "${filename}" ]; then
            # see if it exists in the current directory
            filepath="${filename}"
        else
            local shell_lower=$(
                basename `ps -p "$$" -o args= \
                    | awk '{gsub(/^-?(.*\/)?/, "", $1); print $1}'` \
                    | tr '[:upper:]' '[:lower:]'
            )
            local shell_upper=$(echo "${shell_lower}" | tr '[:lower:]' '[:upper:]')
            # determine the current shell's lib path
            local lib_path="${shell_upper}_LIB_PATH"
            # load the value of the lib path from the environment
            if [ "${shell_lower}" = "bash" ]; then
                local lib_path_value="${!lib_path}"
            elif [ "${shell_lower}" = "zsh" ]; then
                local lib_path_value="${(P)lib_path}"
            else
                # attempt a generic eval, although chances are low that the rest of
                # the module will work even if this does
                eval local lib_path_value="\$${lib_path}"
                if [ $? -ne 0 ]; then
                    echo "include-source: failed to determine the value of '${lib_path}'" >&2
                    return 1
                fi
            fi
            # if the lib path is empty, use PATH
            if [ -z "${lib_path_value}" ]; then
                lib_path_value="${PATH}"
            fi
            # load the path into an array
            IFS=$'\n' local lib_path_array=($(echo "${lib_path_value}" | tr ':' '\n'))
            for dir in ${lib_path_array[@]}; do
                # determine if a readable file with the given name exists in this dir
                if [ -f "${dir}/${filename}" ] && [ -r "${dir}/${filename}" ]; then
                    filepath="${dir}/${filename}"
                    break
                fi
            done
        fi
        if [ -n "${filepath}" ]; then
            # if we found a file, use it
            if [ "${show_location}" -eq 1 ]; then
                echo "${filepath}"
                return 0
            elif [ "${verbose}" -eq 1 ]; then
                echo "include-source: sourcing '${filepath}'"
            fi
            if [ "${do_source}" -eq 1 ]; then
                source "${filepath}"
            fi
            return 0
        else
            # if we didn't find a file, return an error
            echo "-${shell_lower}: ${filename}: no such lib" >&2
            return 1
        fi
    fi
}

# Load files that include "include-source" and replace the "include-source"
# line with the contents of the specified script
# Options:
#   -i: modify files in place
#   -I: don't modify files in place
#   -t: include tags at the beginning/end of source code in the compiled files
#   -T: don't include tags at the beginning/end of source code
#   -h: help
function compile-sources() {
    local usage="usage: include-source [-iI|--(no-)in-place] [-tT|--(no-)tags] [-h|--help] <file> [<file> ...]"

    # default values
    local in_place=0
    local include_tags=1

    # parse arguments
    local positional_args=()
    while [[ ${#} -gt 0 ]]; do
        local arg="$1"
        case "$arg" in
            -i|--in-place)
                in_place=1
                shift
                ;;
            -I|--no-in-place)
                in_place=0
                shift
                ;;
            -t|--tags)
                include_tags=1
                shift
                ;;
            -T|--no-tags)
                include_tags=0
                shift
                ;;
            -h|--help)
                echo ${usage}
                return 0
                ;;
            -*)
                echo "include-source: invalid option '$arg'" >&2
                return 1
                ;;
            *)
                positional_args+=("$arg")
                shift
                ;;
        esac
    done
    set -- "${positional_args[@]}"

    if [ -z "${positional_args[@]}" ]; then
        echo ${usage} >&2
        return 1
    fi

    # loop over each file in the args
    for filename in "${positional_args[@]}"; do
        # load the file contents into a var
        local file_contents=$(cat "${filename}")

        # loop while the file contents contains "^include-source"
        while grep -q "^include-source\b" <<< "${file_contents}"; do
            grep_res=$(grep "^include-source\b" <<< "${file_contents}")
            # get the line number of the first "include-source" line
            local line_number=$(
                echo "${file_contents}" \
                | grep -n "^include-source\b" \
                | cut -d ':' -f1 \
                | head -n1
            )
            # get the line content of that "include-source" line
            local line=$(echo "${file_contents}" | sed -n "${line_number}p")
            # get the sourced filename from the line
            local sourced_filename=$(echo "${line}" | awk -F " " '{print $2}')
            # remove any single or double quotes from the filename
            sourced_filename="$(echo "${sourced_filename}" | sed "s/^[\"']//;s/[\"']$//")"
            # get the filepath to the source file
            local sourced_filepath="$(include-source --location "${sourced_filename}")"
            # get the contents of the source file
            local sourced_contents=""
            local loaded_source_file_contents=0
            if [[ "${sourced_filepath}" =~ ^https?:// ]]; then
                # get the contents of the url
                sourced_contents="$(curl -s "${sourced_filepath}")"
                if [ $? -ne 0 ]; then
                    sourced_contents="# compile-sources: failed to download '${sourced_filepath}'"
                    loaded_source_file_contents=1
                fi
            else
                # ensure file exists and is readable
                if [ ! -f "${sourced_filepath}" ]; then
                    sourced_contents="# compile-sources: failed to find '${sourced_filepath}'"
                    loaded_source_file_contents=1
                elif [ ! -r "${sourced_filepath}" ]; then
                    sourced_contents="# compile-sources: could not read '${sourced_filepath}'"
                    loaded_source_file_contents=1
                else
                    sourced_contents="$(cat "${sourced_filepath}")"
                    loaded_source_file_contents=0
                fi
            fi
            # if the source file is empty, then say as much
            if [ -z "${sourced_contents}" ]; then
                sourced_contents="# compile-sources: empty file '${sourced_filepath}'"
                loaded_source_file_contents=1
            fi
            # if we successfully loaded some content and include_tags is set,
            # then add a line to the end of the source indicating where it ends
            if [ "${loaded_source_file_contents}" -eq 0 ] && [ "${include_tags}" -eq 1 ]; then
                sourced_contents="${sourced_contents}"$'\n'"# compile-sources: end of '${sourced_filename}'"
            fi
            # if include_tags is set, comment out the include-source line and
            # add the source file contents after it, else just replace the
            # include-source line with the source file contents
            if [ "${include_tags}" -eq 1 ]; then
                # comment out the include-source line
                file_contents=$(echo "${file_contents}" | sed "${line_number}s/^/# /")
            else
                # delete the include-source line
                file_contents=$(echo "${file_contents}" | sed "${line_number}d")
                # and decrement the line number by one
                line_number=$((line_number - 1))
            fi
            # insert the contents of the sourced file at the line number
            file_contents=$(
                sed "${line_number}r /dev/stdin" \
                    <(echo "${file_contents}") \
                    <<< "${sourced_contents}"
            )
        done
        # if in-place is enabled, write the file contents to the file
        if [ "${in_place}" -eq 1 ]; then
            echo "${file_contents}" > "${filename}"
        else
            echo "${file_contents}"
        fi
    done
}

# export the functions for use in the shell and in other scripts
export -f include-source compile-sources
