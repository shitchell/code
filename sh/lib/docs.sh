#!/usr/bin/env bash
: "
This module provides functions for generating help documentation for shell
libraries and functions based on Python-style docstrings.

# Example

Docstrings will take the following format:

    function foo() {
        :  '[@summary] This is a brief <80 character summary
            [@description] This is a description. The @description tag here is
            optional; all lines of text from the 2nd line to the first explicit @tag
            will be parsed as the description. Any leading/trailing whitespace will
            be trimmed, so a blank line or two before/after *any* value is fine :)

            @usage
                [-h/--help] [-f/--foo <value>] <arg1> <arg2> [<arg3>]

            @option -h
                Show a brief help message

            @option --help
                Show a longer help message

            @option -f/--foo <value>
                Use <value> for the foo thingy

            @arg <arg1>
                This is a string that indicates the thing

            @arg <arg2>
                This is an integer which indicates this other thing

            @optarg <arg3>
                This is an optional string that indicates one last thing

            @setenv FOO
                This will set the FOO environment variable to 'bar'

            @other-label
                This is a label that does a thing

            @stdin
                This is what the function will read from stdin

            @stdout
                This is what the function will output

            @stderr
                This is what the function will output to stderr

            @return 0
                Successfully did the thing

            @return 1
                Something went wrong

            @return 2
                Could not find a file
        '
        echo 'hello world'
    }

Docstrings can use either single or double quotes.

# Standard labels

You can use create any tags you like, but a few specific tags are used by this
library when generating documentation: 

- @description: A description of the function. Any text from the 2nd line (the
  line after the colon) until the first line with an explicit @label will be
  parsed as the description.
- @summary: A brief, <80 character summary of the function. Any text on the
  first line (the same line as the colon) will be parsed as the summary unless
  an explicit @label is used.
- @usage: A compact, summarized list of all options the function accepts
  *without* the function name included (see above).
- @option: Describes a command line option and any parameters it accepts
- @arg: Describes a required positional argument. Order matters! The first
  occurence of '@arg' will be interpreted as the first positional argument, the
  second will be interpreted as the second, etc...
- @arg+: Describes 1 or more required positional arguments.
- @arg*: Describes 0 or more required positional arguments.
- @optarg: Describes an optional positional argument.
- @setenv: Describes an environment variable that the function will set.
- @example: Provides a single example of how to use the function.
- @stdin: Describes what the function will read from stdin.
- @stdout: Describes what the function will output to stdout.
- @stderr: Describes what the function will output to stderr.
- @return: Describes an exit code.

# Auto-generated labels

There are two additional labels which get automatically generated for every
function:

- @uses_subshell: Boolean indicating whether the function runs in a subshell,
  i.e.: whether it is defined with curly braces or parentheses.
- @redirection: Any redirections defined after the closing brace/parenthesis of
  the function. For most functions, this is empty.

If you try to manually specify these labels in a docstring, they will be
overwritten with their appropriate values as parsed. If you would like to give
any additional information on the behavior associated with a function's
redirections or running in a subshell, do so in the description or any other
label as appropriate.

# Behavior

## General

The parser will use the following pattern when extracting labels and their 
values: /^\s*@([-A-Za-z0-9]+)\s+(.*)/, where the first capture group is the
label and the second is its value. This basically translates to:

- leading whitespace is ignored
- it looks for an '@' symbol followed by letters, numbers, and/or dashes for the
  label
- it looks for one or more spaces after the label, and then everything else on
  the line is parsed as the value

Once a label has been defined, all subsequent lines will be added to its value,
with leading/trailing whitespace trimmed. Line breaks follow OpenMarkdown rules:
a single line break is replaced with a space, and two line breaks become a
single newline.

## Arrays and associative arrays

Some labels like the description are expected to appear only once. Others are
anticipated to appear multiple times, and some can be thought of as their own
associative array, e.g.: exit codes and options. Because of the limitations of
bash associative arrays, we handle these a little funkily. Bash associative
arrays do not allow for storing anything other than strings as values, i.e.: we
cannot store an array or an associative array inside another associative array.
To that end, we use the ANSI Record Separator (0x1E) and Unit Separator (0x1F)
characters (https://stackoverflow.com/a/18782271). For *any* label which is
repeated, including single-use labels like @description, any re-occurence will
yield a Record Separator in its value. For *specific* labels outlined below,
their values will be parsed to produce a subsequent key and value to be
separated by a Unit Separator character in the DOCSTRING associative array. As
an example:

    : '
    @description This is a description
    @option -h/--help: Show a helpful help message
    @option -f/--foo <arg>: Sets foo to the arg
    @return 0: Great success
    '

Will result in the following DOCSTRING values:

    declare -A DOCSTRING=(
        [description]='This is a description'
        [option]=$'-h/--help\x1fShow a helpful help message\x1e-f/--foo <arg>\x1fSets foo to the arg'
        [return]=$'0\x1fGreat success'
    )

The following labels will be produce Unit Record separators:

  - @option
  - @arg
  - @optarg
  - @return

The keys/values of these labels can use either a colon (:) or newline (\n) to
separate the key from the value:

    : '
    @option -h/--help: Show a helpful help message
    @option -f/--foo <arg>
      Sets foo to the arg
    '
"

include-source 'debug.sh'

function generate-library-docs() {
    : '
    Generate help documentation for a library based on a docstring defined as
    the first line under its signature.

    @usage      generate-library-docs <library_name>
    @stdout     The docstring as a "declare" statement
    @return     0: if the library was successfully documented
    @return     1: general error
    @return     2: if the library name was empty
    @return     3: if the library was not found
    '
    local lib_name="${1}"
    local lib_body lib_docstring
    local exit_code=0

    # Ensure a library name was provided
    [[ -z "${lib_name}" ]] && return 2

    # Get the library signature and body
    lib_body=$(declare -f "${lib_name}") || return 3

    # Extract the docstring
    lib_docstring=$(
        __extract_docstring --trim-docstring --no-trim-lines "${lib_body}"
    ) || return ${?}

    # Parse
    eval "$(__parse_docstring "${lib_docstring}")" || return ${?}

    # Output the docstring
    declare -p DOCSTRING
}

function generate-function-docstring() {
    : '
    Generate help documentation for a function based on a docstring defined as
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

        @usage
            [-t/--trim] [-T/--no-trim] [-l/--trim-lines] [-L/--no-trim-lines]
            [-d/--trim-docstring] [-D/--no-trim-docstring]
            [-s/--separate-summary] [-S/--no-separate-summary
            <function_body>
        @option -t/--trim
            Trim leading/trailing whitespace from the docstring and each line
        @option -T/--no-trim
            Do not trim leading/trailing whitespace from the docstring or lines
        @option -l/--trim-lines
            Trim leading/trailing whitespace from each line, but not the
            docstring
        @option -L/--no-trim-lines
            Do not trim leading/trailing whitespace from any lines
        @option -d/--trim-docstring
            Trim leading/trailing whitespace from the docstring
        @option -D/--no-trim-docstring
            Do not trim leading/trailing whitespace from the docstring
        @option -s/--separate-summary
            Insert a US (0x1F) character between the summary and the rest of the
            docstring
        @option -S/--no-separate-summary
            Do not insert a US (0x1F) character between the summary and the rest
            of the docstring
        @arg <function_body>
            The body of the function
        @stdout
            The docstring
        @return 0
            If the docstring was successfully extracted
        @return 1
            If the function body was not provided
        @return 2
            If a docstring was not found
    '
    # Default values
    local f_body
    local f_docstring
    local do_separate_summary=true
    local do_trim_line_whitespace=true
    local do_trim_docstring_whitespace=true

    # Parse the values
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -s | --separate-summary)
                do_separate_summary=true
                shift 1
                ;;
            -S | --no-separate-summary)
                do_separate_summary=false
                shift 1
                ;;
            -t | --trim)
                do_trim_line_whitespace=true
                do_trim_docstring_whitespace=true
                shift 1
                ;;
            -T | --no-trim)
                do_trim_line_whitespace=false
                do_trim_docstring_whitespace=false
                shift 1
                ;;
            -l | --trim-lines)
                do_trim_line_whitespace=true
                shift 1
                ;;
            -L | --no-trim-lines)
                do_trim_line_whitespace=false
                shift 1
                ;;
            -d | --trim-docstring)
                do_trim_docstring_whitespace=true
                shift 1
                ;;
            -D | --no-trim-docstring)
                do_trim_docstring_whitespace=false
                shift
                ;;
            *)
                f_body="${1}"
                shift 1
                ;;
        esac
    done

    # Ensure a function body was provided
    [[ -z "${f_body}" ]] && return 1

    # Extract the docstring
    local line_num=0
    local quote="" # "'" or "\""
    local terminator="" terminator_regex="" terminator_found=false
    while IFS=$'\n' read -r line; do
        # Remove leading/trailing whitespace from the line
        if ${do_trim_line_whitespace}; then
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"
        fi

        # Increment the line number
        let line_num++
        debug "parsing line #${line_num}: '${line}'"

        # Skip the first two lines (signature and opening brace)
        ((line_num <= 2)) && continue

        # If the line number is 3, ensure that it is the start of a docstring,
        # i.e. that it matches /^\s*:\s+['"]/
        if ((line_num == 3)); then
            if [[ "${line}" =~ ^[[:space:]]*("( ")?":"[[:space:]]+(["'\""])(.*) ]]; then
                # Determine the type of quote used
                quote="${BASH_REMATCH[2]}"
                # Set the line to the part of the docstring after the quote
                line="${BASH_REMATCH[3]}"
                # If we are separating the summary out and this first line is
                # not empty, then add a US (0x1F) character to the end of the
                # line
                if ${do_separate_summary} && [[ -n "${line}" ]]; then
                    line+=$'\x1F'
                fi
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

    # Remove any leading/trailing whitespace from the docstring
    if ${do_trim_docstring_whitespace}; then
        f_docstring="${f_docstring#"${f_docstring%%[![:space:]]*}"}"
        f_docstring="${f_docstring%"${f_docstring##*[![:space:]]}"}"
    fi

    # If the docstring was not found, return an error
    [[ -z "${f_docstring}" ]] && return 2

    # Output the docstring
    echo "${f_docstring}"
}

function __parse_docstring() {
    : '
    Parse a docstring into an associate array of labels and values.
    
    The @description is optional. All lines until the first line matching
    /^\s*@/ are considered part of the description. The @usage and @return
    docstring are required and must be on their own lines. Any other lines
    which match the pattern "@{component} {value}" will have that component
    extracted and added to the output.

    Output is a "declare" statement which can be evaluated to set a DOCSTRING
    associative array whose keys are the docstring and values are the
    corresponding values.

    @usage       <docstring>
    @return      0 if the docstring was successfully parsed
    @return      1 if the docstring was not provided
    @return      2 if the docstring was invalid
    '
    # Default values
    local docstring
    local trim_description=true
    local trim_value_whitespace=true
    declare -A DOCSTRING=(
        [description]=""
        [usage]=""
        [return]=""
    )

    # Parse the values
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -t | --trim)
                do_trim_line_whitespace=true
                do_trim_docstring_whitespace=true
                shift 1
                ;;
            -T | --no-trim)
                do_trim_line_whitespace=false
                do_trim_docstring_whitespace=false
                shift 1
                ;;
            -l | --trim-lines)
                do_trim_line_whitespace=true
                shift 1
                ;;
            -L | --no-trim-lines)
                do_trim_line_whitespace=false
                shift 1
                ;;
            -d | --trim-docstring)
                do_trim_docstring_whitespace=true
                shift 1
                ;;
            -D | --no-trim-docstring)
                do_trim_docstring_whitespace=false
                shift
                ;;
            *)
                docstring="${1}"
                shift 1
                ;;
        esac
    done

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
    local is_first=true
    local component="description" component_value
    while IFS=$'\n' read -r line; do
        debug "parsing line: '${line}'"
        # Remove leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # If this is the first line, and it ends with a US (0x1F) character,
        # then treat it as the summary and remove the US character
        if ${is_first} && [[ "${line}" =~ $'\x1F'$ ]]; then
            DOCSTRING[summary]="${line%$'\x1F'}"
            is_first=false
            continue
        fi

        if [[ "${line}" =~ ^[[:space:]]*"@"([A-Za-z]+)[[:space:]]*(.*) ]]; then
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
    This is a test function with a single quoted docstring.

    @usage       [-h] [--help] <arg1> [<arg2> ...]
    @stdout      a simple greeting
    @return      0: success, which this never returns. ever.
    @return      1: always, no matter what
    '
    echo "hello world"
    for i in {1..2}; do
        return ${i}
    done
}

function test-func-single-redirect() {
    : '
    This is a test function with a single quoted docstring and redirection.

    @usage       [-h] [--help] <arg1> [<arg2> ...]
    @stdout      a simple greeting
    @return      0: success, which this never returns. ever.
    @return      1: always, no matter what
    '
    echo "hello world"
    for i in {1..2}; do
        return ${i}
    done
} 2>&1  1>&2
