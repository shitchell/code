#!/usr/bin/env bash
: '
This module provides functions for generating help documentation for shell
libraries and functions based on Python-style docstrings.
'

include-source 'debug.sh'

function generate-library-docs() {
    : '
    Generate help documentation for a library based on a docstring defined as
    the first line under its signature.

    @usage       generate-library-docs <library_name>
    @return     0 if the library was successfully documented
    @return     1 general error
    @return     2 if the library name was not provided
    @return     3 if the library does not exist
    '
    local lib_name="${1}"
    local lib_body lib_docstring
    local exit_code=0

    # Ensure a library name was provided
    [[ -z "${lib_name}" ]] && return 2

    # Get the library signature and body
    lib_body=$(declare -f "${lib_name}") || return 3

    # Extract the docstring
    lib_docstring=$(__extract_docstring "${lib_body}") || return ${?}

    # Parse
    eval "$(__parse_docstring "${lib_docstring}")" || return ${?}

    # Output the docstring
    declare -p DOCSTRING
}

function generate-function-docstring() {
    : '
    Generate help documentation for a function based on a doc string defined as
    the first line under its signature.
    
    @usage      <function_name>
    @return     0 if the function was successfully documented
    @return     1 general error
    @return     2 if the function name was not provided
    @return     3 if the function does not exist
    '
    local f_name="${1}"
    local docstring_var="${2:-DOCSTRING}"
    local f_body f_docstring f_is_subshell f_redirect
    local exit_code=0

    # Ensure a function name was provided
    [[ -z "${f_name}" ]] && return 1

    # Get the function signature and body
    f_body=$(declare -f "${f_name}") || return 3
    
    # Extract the docstring
    f_docstring=$(__extract_docstring "${f_body}") || return ${?}
    
    # Parse
    eval "$(__parse_docstring "${f_docstring}")" || return ${?}

    # Determine if the function uses a subshell
    if __uses_subshell "${f_body}"; then
        f_is_subshell=true
    else
        f_is_subshell=false
    fi
    DOCSTRING[uses_subshell]="${f_is_subshell}"

    # Extract any redirection
    f_redirect=$(__extract_redirection "${f_body}")
    DOCSTRING[redirection]="${f_redirect}"

    # If the function contains a usage component that does not start with the
    # function name, then prepend the function name to the usage
    if [[ -n "${DOCSTRING[usage]}" && "${DOCSTRING[usage]}" != "${f_name} "* ]]; then
        DOCSTRING[usage]="${f_name} ${DOCSTRING[usage]}"
    fi

    # Output the docstring in a format that is both pretty and eval-able
    echo "declare -A ${docstring_var}=("
    for key in "${!DOCSTRING[@]}"; do
        printf '    [%s]=%q\n' "${key}" "${DOCSTRING[${key}]}"
    done
    echo ")"
}

function __uses_subshell() {
    : '
    Determine if a function body uses a subshell, e.g.:
    
        function test-func() (
            echo "this is a subshell"
        )

    @usage       <function_body>
    @return      0 if the function uses a subshell
    @return      1 if the function does not use a subshell
    @return      2 if the function body was not provided
    '
    local f_body="${1}"
    local f_is_subshell=false

    # Ensure a function body was provided
    [[ -z "${f_body}" ]] && return 2

    # Check for an open parenthesis on line 3
    local line_num=0
    while read -r line; do
        # Skip the first two lines (signature and opening brace)
        ((line_num++ < 2)) && continue

        debug "checking line: '${line}'"

        # Determine if the first non-space character is an open parenthesis
        [[ "${line}" =~ ^[[:space:]]*"(" ]] && return 0 || return 1
    done <<< "${f_body}"
}

function __extract_redirection() {
    : '
    Determine if a function uses redirection and, if so, output its value.

    @usage       <function_body>
    @stdout      The redirection value
    @return      0 if the function uses redirection
    @return      1 if the function does not use redirection
    @return      2 if the function body was not provided
    '
    local f_body="${1}"
    local f_redirect f_is_subshell

    # Ensure a function body was provided
    [[ -z "${f_body}" ]] && return 2

    # Loop over each line, tracking both the current and previous line. If a
    # function uses a subshell, then the redirection will be on the second to
    # last line of the function body.
    local line_num=0 lines=()
    while read -r line; do
        # Skip the first two lines (signature and opening brace)
        ((line_num++ < 2)) && continue

        # Determine if the function is a subshell on the third line
        if ((line_num == 3)); then
            [[ "${line}" =~ ^[[:space:]]*"(" ]] \
                && f_is_subshell=true \
                || f_is_subshell=false
            continue
        fi

        # Add the line
        lines+=("${line}")
    done <<< "${f_body}"

    debug-vars f_is_subshell lines

    # Check if the function includes any redirection on the last line (normal
    # functions) or the second to last line (subshells)
    local redirect_regex redirect_line
    if ${f_is_subshell}; then
        redirect_regex='.*\) (.*)$'
        redirect_line="${lines[-2]}"
    else
        redirect_regex='} (.*)$'
        redirect_line="${lines[-1]}"
    fi
    if [[ "${redirect_line}" =~ ${redirect_regex} ]]; then
        f_redirect="${BASH_REMATCH[1]}"
        echo "${f_redirect}"
        return 0
    else
        return 1
    fi
}

function __extract_docstring() {
    :  'Extract the docstring from a function body.

        @usage       <function_body>
        @stdout      The docstring
        @return      0 if the docstring was successfully extracted
        @return      1 if the function body was not provided
        @return      2 if the docstring was not found
    '
    local f_body="${1}"
    local f_docstring

    # Ensure a function body was provided
    [[ -z "${f_body}" ]] && return 1

    # Extract the docstring
    local line_num=0
    local quote="" # "'" or "\""
    local terminator="" terminator_regex="" terminator_found=false
    while read -r line; do
        # Remove leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # Increment the line number
        let line_num++
        debug "parsing line #${line_num}: '${line}'"

        # Skip the first two lines (signature and opening brace)
        ((line_num <= 2)) && continue

        # If the line number is 3, ensure that it is the start of a docstring,
        # i.e. that it matches /^\s*:\s+['"]/
        if ((line_num == 3)); then
            if [[ "${line}" =~ ^("( ")?":"[[:space:]]+(["'\""])(.*) ]]; then
                # Determine the type of quote used
                quote="${BASH_REMATCH[2]}"
                # Set the line to the part of the docstring after the quote
                line="${BASH_REMATCH[3]}"
                # Set the terminator to the quote + ";". Because double quoted
                # strings can include escaped double quotes, we need to add a
                # negative lookbehind to ensure that the quote is not escaped.
                if [[ "${quote}" == "'" ]]; then
                    debug "using single quotes"
                    terminator="';"
                    terminator_regex="';\$"
                else
                    debug "using double quotes"
                    terminator='";'
                    terminator_regex='(?<!\\)";$'
                fi
            else
                return 2
            fi
        fi

        # Check to see if the line ends with the terminator
        if grep -qP "${terminator_regex}" <<< "${line}"; then
            debug "terminator found"
            # If the line ends with the terminator, then we've reached the end
            # of the docstring. Remove the terminator and set the flag to true
            line="${line%${terminator}}"
            debug "removed terminator from line: '${line}'"
            terminator_found=true
        fi

        # Add the line to the docstring
        [[ -n "${f_docstring}" ]] && f_docstring+=$'\n'
        [[ -n "${line}" ]] && f_docstring+="${line}"

        # If the terminator was found, then break the loop
        ${terminator_found} && break
    done <<< "${f_body}"

    # Remove any leading/trailing whitespace
    f_docstring="${f_docstring#"${f_docstring%%[![:space:]]*}"}"
    f_docstring="${f_docstring%"${f_docstring##*[![:space:]]}"}"

    # If the docstring was not found, return an error
    [[ -z "${f_docstring}" ]] && return 2

    # Output the docstring
    echo "${f_docstring}"
}

function __parse_docstring() {
    : '
    Parse the docstring of a function.
    
    The @description is optional. All lines until the first line matching
    /^\s*@/ are considered part of the description. The @usage and @return
    docstring are required and must be on their own lines. Any other lines
    which match the pattern "@{component} {value}" will have that component
    extracted and added to the output.

    Output is a `declare` statement which can be `eval`ed to set a DOCSTRING
    associative array whose keys are the docstring and values are the
    corresponding values.

    @usage       <docstring>
    @return      0 if the docstring was successfully parsed
    @return      1 if the docstring was not provided
    @return      2 if the docstring was invalid
    '
    local docstring="${1}"
    declare -A DOCSTRING=(
        [description]=""
        [usage]=""
        [return]=""
    )

    if [[ -z "${docstring}" && -t 2 && ! -t 0 ]]; then
        debug "reading docstring from stdin"
        # If the docstring is empty and we're in a terminal, try reading stdin
        docstring=$(cat -)
    fi

    if [[ -z "${docstring}" ]]; then
        debug "no docstring provided"
        return 1
    fi

    # Extract the docstring
    local component="description" component_value
    while read -r line; do
        debug "parsing line: '${line}'"
        # Remove leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        if [[ "${line}" =~ ^"@"([A-Za-z]+)[[:space:]]*(.*) ]]; then
            # We've found a new component! Ensure the last component has no
            # leading/trailing whitespace and switch to the new component
            val="${DOCSTRING[${component}]}"
            val="${val#"${val%%[![:space:]]*}"}"
            val="${val%"${val##*[![:space:]]}"}"
            DOCSTRING[${component}]="${val}"
            # Start the new component
            component="${BASH_REMATCH[1]}"
            line="${BASH_REMATCH[2]}"
        fi

        # If the line is empty, add a newline to the current component
        [[ -z "${line}" ]] && DOCSTRING[${component}]+=$'\n' && continue

        # If we already have a value for this component, then add either a
        # space or newline depending on the component
        if [[ -n "${DOCSTRING[${component}]}" ]]; then
            case "${component}" in
                return)
                    DOCSTRING[${component}]+=$'\n'
                    ;;
                *)
                    DOCSTRING[${component}]+=" "
                    ;;
            esac
        fi
        DOCSTRING["${component}"]+="${line}"
    done <<< "${docstring}"

    # Validate that at least 1 component was found
    local is_valid=false
    for component in "${!DOCSTRING[@]}"; do
        [[ -n "${DOCSTRING[${component}]}" ]] && is_valid=true && break
    done
    ${is_valid} || return 2

    # Output the docstring as a `declare` statement
    declare -p DOCSTRING
}

function test-func-subshell-single() (
    : '
    @description This is a subshell test function, and it
                 includes newlines
    @usage       [-h] [--help] <arg1> [<arg2> ...]
    '
    for i in {1..2}; do
        return ${i}
    done
)

function test-func-subshell-double-redirect() (
    : "
    @description This is a subshell \"test\"; function, and it
                 includes newlines and multiple trixy escaped double quotes\";

    like this one:

    \";

    @usage       [-h] [--help] <arg1> [<arg2> ...]"; echo hi
    for i in {1..2}; do
        return ${i}
    done
) 2>&1 > >(tee /tmp/log.txt)


function test-func-single() {
    : '
    @description This is a test function, and it
                 includes newlines
    @usage       [-h] [--help] <arg1> [<arg2> ...]
    '
    for i in {1..2}; do
        return ${i}
    done
}

function test-func-single-redirect() {
    : "
    @description This is a test function, and it
                 includes newlines and multiple trixy escaped double quotes\";

    like this one:

    \";

    @usage       [-h] [--help] <arg1> [<arg2> ...]"; echo hi
    for i in {1..2}; do
        return ${i}
    done
} 2>&1  1>&2
