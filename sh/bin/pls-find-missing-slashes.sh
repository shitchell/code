#!/bin/bash
#
# This script parses a PL/SQL script to determine if it is missing any slashes
# after the END keyword for SQL*Plus.
#
# Logic:
# - Track:
#   - in_block: whether or not we are currently in a PL/SQL block
#   - block_level: the number of nested PL/SQL blocks we are currently in
#   - block_start_line: the line number where the current outermost block starts
#   - block_end_line: the line number where the current outermost block ends
#   - slash_required: whether we are currently waiting for the next non-empty
#     line to have a slash
# - If a line contains BEGIN, then:
#   - validate it is on its own line, else throw an INVALID BLOCK START error
#   - increment block_level
#   - if not in a block, set in_block to true and set block_start_line to the
#     current line number
# - CREATE (OR REPLACE) PACKAGE (BODY) blocks are special cases.
#   - CREATE PACKAGE ...; starts a new block without a BEGIN keyword. That block
#     ends with END.
# - CREATE (OR REPLACE) TYPE blocks are special cases.
#   - CREATE TYPE ... (AS|UNDER) ...; is a "single" line block that ends with a
#     semicolon. This script allows for that "single" line to span multiple
#     lines until the semicolon is found.
#   - CREATE TYPE ... IS ...; is a multiline block and ends with END.
#   - For simplicity of logic, require that the AS, UNDER, and IS keywords be
#     on the same line as the CREATE TYPE keyword, failing with an
#     INVALID START error if they are not. This should be updated in the future
#     to allow them to be on different lines, e.g.:
#       CREATE TYPE foo
#       AS OBJECT (
#         ...
#       );
# - If a line contains END, then:
#   - validate it is on its own line, else throw an INVALID BLOCK END error
#   - If it is END IF, END LOOP, or END CASE, then ignore it
#   - decrement block_level
#   - if block_level is 0, then we found the end of the outermost block:
#     - set in_block to false
#     - set block_end_line to the current line number
#     - set slash_required to true
# - If we are waiting for a semicolon to terminate a single line block, then:
#   - if the line contains a semicolon, then:
#     - validate it is on its own line, else throw an INVALID BLOCK END error
#     - decrement block_level
# - If a line contains a slash but slash_required is false, then throw an
#   UNNECESSARY SLASH warning. This will not result in a failure exit code since
#   it is not necessarily an error.
#
# PL/SQL BLOCK START statements:
# - BEGIN:  ends with END
# - CREATE (OR REPLACE) TYPE ... (AS|UNDER):  ends with ;
# - CREATE (OR REPLACE) PACKAGE (BODY):  ends with END
#
# PL/SQL BLOCK END statements:
# - END( <block_name>)?
# - Ignore: END IF, END LOOP, END CASE
#
# Validations:
# - BLOCK START statements must be on their own line, else throw an INVALID
#   BLOCK START error
# - BLOCK END statements must be on their own line, else throw an INVALID BLOCK
#   END error
#
# Errors:
# - ERROR_MISSING_SLASH (11):  file contains missing slashes
# - ERROR_INVALID_BEGIN (12):  file contains invalid BEGIN statements
# - ERROR_INVALID_END (13):  file contains invalid END statements
# - ERROR_INVALID_BEGIN_END (14):  file contains invalid BEGIN and END statements
# - ERROR_INVALID_SLASH (15):  file contains invalid slashes
# - All errors are reported after the file is parsed to ensure we do not miss
#   any errors
# - If the file contains any INVALID BLOCK START or INVALID BLOCK END errors,
#   then we cannot trust whether or not missing slash errors are valid, so we
#   exit with an INVALID BLOCK START/END error and do not report any missing
#   slash errors.
# - Unnecessary slash warnings are printed to stderr, not stdout. All other
#   errors are printed to stdout.

## traps #######################################################################
################################################################################

# Always restore output before exiting
trap restore-output EXIT


## usage functions #############################################################
################################################################################

function help-epilogue() {
    echo "parse pl/sql scripts to find missing slashes"
}

function help-full() {
    help-usage
    help-epilogue
    echo
    echo "Options:"
    cat << EOF
    -h                             display usage
    --help                         display this help message
    -i/--insert                    insert missing slashes
    -c/--context <int>             number of lines to display before and after
                                   the missing slash
    -b/--show-block                print a block if it contains an error
    -v/--show-all-files            print the filepath before each file, even if
                                   there is only one file or no errors
    -q/--quiet                     do not display any output
EOF
}

function help-usage() {
    echo "usage: $(basename "${0}") [-h] [-i] [-b] [-c <int>] [-q] <filepath>..."
}

function parse-args() {
    # Default values
    FILEPATHS=()
    CONTEXT=0
    DO_INSERT=false
    DO_QUIET=false
    DO_SHOW_BLOCK=false
    DO_SHOW_ALL_FILES=false

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -h | --help)
                help-full
                exit 0
                ;;
            -i | --insert)
                DO_INSERT=true
                shift
                ;;
            -c | --context)
                CONTEXT="${2}"
                shift 2
                ;;
            -b | --show-block)
                DO_SHOW_BLOCK=true
                shift
                ;;
            -q | --quiet)
                DO_QUIET=true
                shift
                ;;
            -v | --show-all-files)
                DO_SHOW_ALL_FILES=true
                shift
                ;;
            *)
                FILEPATHS+=("${1}")
                shift
                ;;
        esac
    done

    # If no filepaths were specified, print usage and exit
    if [[ ${#FILEPATHS[@]} -eq 0 ]]; then
        help-usage >&2
        exit 1
    fi

    debug "FILEPATHS:      ${FILEPATHS[@]}"
    debug "CONTEXT:        ${CONTEXT}"
    debug "DO_SHOW_BLOCK:  ${DO_SHOW_BLOCK}"
    debug "DO_INSERT:      ${DO_INSERT}"
    debug "DO_QUIET:       ${DO_QUIET}"
}


## helpful functions ###########################################################
################################################################################

# @description Print debug messages
function debug() {
    local prefix timestamp
    if [[ "${DEBUG}" == "1" || "${DEBUG}" == "true" || -n "${DEBUG_LOG}" ]]; then
        timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
        prefix="\033[36m[${timestamp}]\033[0m "
        prefix+="\033[35m$(basename "${BASH_SOURCE[-1]}")"
        [[ "${FUNCNAME[1]}" != "main" ]] && prefix+="\033[1m:${FUNCNAME[1]}()\033[0m"
        prefix+="\033[32m:${BASH_LINENO[0]}\033[0m -- "
        printf "%s\n" "${@}" \
            | awk -v prefix="${prefix}" '{print prefix $0}' >> "${DEBUG_LOG:-/dev/stderr}"
    fi
}

# @description Disable stdout and stderr, saving them off first
function disable-output() {
    debug "disabling output"
    exec 3>&1 4>&2
    exec 1>/dev/null 2>&1
}

# @description Restore stdout and stderr
function restore-output() {
    exec 1>&3 2>&4
    exec 3>&- 4>&-
} >/dev/null 2>&1

# @description Parse a file to find missing slashes
# @usage pls-find-missing-slashes <filepath>
# @exit 1 generic bash error
# @exit 2 file is empty
# @exit 3 file is not found
# @exit 4 file is not readable
# @exit 10 generic awk error
# @exit 11 missing slash(es)
# @exit 12 invalid BEGIN statement(s)
# @exit 13 invalid END statement(s)
# @exit 14 invalid BEGIN and END statement(s)
# @exit 15 invalid slash(es)
function pls-find-missing-slashes() {
    # Default values
    local do_allow_unnecessary_slashes=true
    local filepath="/dev/stdin"

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -u | --allow-unnecessary-slashes)
                do_allow_unnecessary_slashes=true
                shift
                ;;
            *)
                filepath="${1}"
                shift
                ;;
        esac
    done

    # If the filepath is a "-", then read from stdin
    if [[ -d "${filepath}" ]]; then
        debug "file is a directory: ${filepath}"
        return 3
    elif ! [[ -f "${filepath}" ]]; then
        debug "file not found: ${filepath}"
        return 3
    elif ! [[ -r "${filepath}" ]]; then
        debug "file not readable: ${filepath}"
        return 4
    elif [[ -z "${filepath}" ]]; then
        debug "filepath not given"
        return 2
    elif ! [[ -f "${filepath}" && -r "${filepath}" ]]; then
        debug "unknown error"
        return 1
    fi

    debug "parsing file: ${filepath}"

    # Find all lines that end with "END" and do not have a slash, accounting
    # nested BEGIN..END statements. In the case of nested statements, the slash
    # is only required for the outermost statement.
    # Note: this does not necessarily accept valid SQL. It demands that certain
    #       statements be on their own line, such as BEGIN and CREATE PACKAGE.
    #       This was a design decision to make the script simpler and to
    #       enforce a standard.
    awk -v DEBUG="${DEBUG}" -v ALLOW_UNNECESSARY_SLASHES="${do_allow_unnecessary_slashes}" '
        function debug(msg) {
            if (DEBUG == "true" || DEBUG == 1) {
                # Print a timestamp, the file line number, and the message
                printf("[%s] (LN%03d:%d)  %s\n", strftime("%Y-%m-%d %H:%M:%S"), NR, block_level, msg) > "/dev/stderr"
            }
        }

        function increment_block_level() {
            block_level += 1
            if (in_block == 0) {
                in_block = 1
                block_start_line = NR
                slash_required = 0
                block_ends_with_semicolon = 0
            }
        }

        function decrement_block_level() {
            block_level -= 1
            if (in_block == 1 && block_level == 0) {
                in_block = 0
                block_end_line = NR
                slash_required = 1
                block_level = 0
                block_ends_with_semicolon = 0
                block_range = block_start_line ":" block_end_line
            }
        }

        BEGIN {
            debug("AWK BEGIN")
            IGNORECASE = 1 # SQL does not care about case, so neither do we

            # Error exit codes
            ERROR_GENERIC = 10
            ERROR_MISSING_SLASH = 11
            ERROR_INVALID_BEGIN = 12
            ERROR_INVALID_END = 13
            ERROR_INVALID_BEGIN_END = 14
            ERROR_INVALID_SLASH = 15

            # Track stuff
            slash_required = 0
            in_comment = 0
            in_block = 0
            block_level = 0
            block_start_line = 0
            block_end_line = 0
            block_ends_with_semicolon = 0
            valid_slash_count = 0
            missing_slash_count = 0
            #missing_slash_blocks # array
            invalid_begin_count = 0
            #invalid_begin_lines # array
            invalid_end_count = 0
            #invalid_end_lines # array
            invalid_slash_count = 0
            #invalid_slash_lines # array
        }

        # We found the start of a multiline comment, so start ignoring lines
        # until we find the end
        /^\s*\/\*/ {
            debug("COMMENT START on line " NR)
            # If we found a comment, then we are in a comment
            in_comment = 1
            next
        }

        # If we are in a comment, determine if we found the end of the comment
        in_comment == 1 {
            if ($0 ~ /.*\*\//) {
                debug("COMMENT END on line " NR)
                in_comment = 0
            } else {
                debug("COMMENT on line " NR)
            }
            next
        }

        block_ends_with_semicolon == 1 {
            # We are waiting for a semicolon to end the block
            if ($0 ~ /;/) {
                # Make sure the semicolon does not have any text after it
                if ($0 ~ /^[^;]*;\s*$/) {
                    debug("SINGLE LINE BLOCK END on line " NR " -- " $0)
                } else {
                    debug("INVALID BLOCK END on line " NR " -- " $0)
                    invalid_end_count += 1
                    invalid_end_lines[invalid_end_count] = NR
                }
                decrement_block_level()
            }
            next
        }

        # We found the start of a "CREATE TYPE" block, which is a special case
        # because it might be a multiline with a BEGIN..END block inside of it,
        # or it might be a single line (which needs to be handled differently)
        /\<CREATE\s+(OR\s+REPLACE\s+)?TYPE\>/ {
            # Determine if it is on its own line or not
            increment_block_level()
            if ($0 ~ /^[^;]+;?\s*$/ && $0 ~ /^\s*CREATE/) {
                # It is on its own line, so determine if it is multiline or not
                if ($0 ~ /\<AS\>/ || $0 ~ /\<UNDER\>/) {
                    # It is single line
                    debug("SINGLE LINE BLOCK START on line " NR " -- " $0)
                    block_ends_with_semicolon = 1
                } else if ($0 ~ /\<IS\>/) {
                    # It is multiline
                    debug("BLOCK START on line " NR " -- " $0)
                } else {
                    # If we ended up here, it is probably because the AS, IS, or
                    # under is on a different line. This is fine and should be
                    # accepted, but we are not allowing it for simplicity of
                    # logic for now. This should be updated in the future.
                    # TODO: allow AS, IS, and UNDER on different lines
                    debug("INVALID BLOCK START on line " NR " -- " $0)
                    invalid_begin_count += 1
                    invalid_begin_lines[invalid_begin_count] = NR
                }
            } else {
                debug("INVALID BLOCK START on line " NR " -- " $0)
                # We have a block start statement on the same line as another
                # statement. This is valid SQL but we are not allowing it, so
                # store this line and exit with an error later
                invalid_begin_count += 1
                invalid_begin_lines[invalid_begin_count] = NR
            }
            next
        }

        # We found the start of a "BEGIN" or "CREATE PACKAGE"
        # block
        /\<BEGIN\>/ || /\<CREATE\s+(OR\s+REPLACE\s+)?PACKAGE(\s+BODY)?\>/ {
            increment_block_level()

            # Determine if it is on its own line or not
            if ($0 ~ /^[^;]+;?\s*$/ && ($0 ~ /^\s*BEGIN/ || $0 ~ /^\s*CREATE/)) {
                # It is on its own line
                debug("BLOCK START on line " NR " -- " $0)
            } else {
                # We have a block start statement on the same line as another
                # statement. This is valid SQL but we are not allowing it, so
                # store this line and exit with an error later
                debug("INVALID BLOCK START on line " NR " -- " $0)
                invalid_begin_count += 1
                invalid_begin_lines[invalid_begin_count] = NR
            }
        }

        # Skip ignorable END statements
        /\<END\s+(IF|LOOP|CASE)\>/ {
            # Determine if it is on its own line or not
            if ($0 ~ /^[^;]+;?\s*$/) {
                debug("IGNORABLE BLOCK END on line " NR " -- " $0)
            } else {
                debug("INVALID BLOCK END on line " NR " -- " $0)
                # We have a block end statement on the same line as another
                # statement. This is valid SQL but we are not allowing it, so
                # store this line and exit with an error later
                invalid_end_count += 1
                invalid_end_lines[invalid_end_count] = NR
            }
            next
        }

        # We found the end of a block
        /\<END\>/ {
            decrement_block_level()

            # Determine if it is on its own line or not
            if ($0 ~ /^[^;]+;?\s*$/) {
                # It is on its own line
                debug("BLOCK END on line " NR " -- " $0)
            } else {
                debug("INVALID BLOCK END on line " NR " -- " $0)
                invalid_end_count += 1
                invalid_end_lines[invalid_end_count] = NR
            }
            next
        }

        # A slash is not required, and we found a slash
        slash_required == 0 && /^\s*\/\s*$/ {
            debug("INVALID SLASH on line " NR " -- " $0)
            invalid_slash_count += 1
            invalid_slash_blocks[invalid_slash_count] = block_range
            next
        }

        # A slash is required, and we found a non-empty line
        slash_required == 1 && /.*[^\s].*/ {
            debug("SLASH REQUIRED on line " NR " -- " $0)
            # If a slash is required, and the line is not empty, then this line
            # SHOULD have a slash. So check if it does not.
            if ($0 !~ /\/\s*$/) {
                # If the line does not have a slash, then add the block start
                # and end lines to the missing slash blocks array.
                missing_slash_count += 1
                missing_slash_blocks[missing_slash_count] = block_range
            } else {
                # If the line does have a slash, then increment the valid slash
                # count.
                valid_slash_count += 1
            }
            slash_required = 0
            next
        }

        # Review any errors and exit
        END {
            debug("AWK END -- slash_required: " slash_required " -- in_block: " in_block " -- block_level: " block_level)

            # If we reach the end in a block, then we are missing a slash
            if (in_block == 1) {
                debug("MISSING SLASH on line " NR " -- " $0)
                block_range = block_start_line ":" NR
                missing_slash_count += 1
                missing_slash_blocks[missing_slash_count] = block_range
            }

            # If a slash is required at the end of the file, then add the
            # currently set block start and end lines to the missing slash
            # blocks array.
            if (slash_required == 1) {
                block_range = block_start_line ":" block_end_line
                missing_slash_count += 1
                missing_slash_blocks[missing_slash_count] = block_range
            }

            # Print any errors/warnings
            for (i = 1; i <= invalid_begin_count; i++) {
                print "ERROR: invalid block start on line " invalid_begin_lines[i]
            }
            for (i = 1; i <= invalid_end_count; i++) {
                print "ERROR: invalid block end on line " invalid_end_lines[i]
            }
            # If there were any invalid blocks, exit, because we cannot trust
            # the slash counts after this point
            if (invalid_begin_count > 0 && invalid_end_count > 0) {
                exit ERROR_INVALID_BEGIN_END
            } else if (invalid_begin_count > 0) {
                exit ERROR_INVALID_BEGIN
            } else if (invalid_end_count > 0) {
                exit ERROR_INVALID_END
            }
            for (i = 1; i <= missing_slash_count; i++) {
                print "ERROR: missing slash for block on lines " missing_slash_blocks[i]
            }
            for (i = 1; i <= invalid_slash_count; i++) {
                # Since slashes *can* be used to re-run a block, it is not
                # necessarily an error to have a slash on a line that does not
                # require one. However, we usually do not want them, so print a
                # warning.
                print "WARNING: unnecessary slash after block on lines " invalid_slash_blocks[i] > "/dev/stderr"
            }

            # Debug if no slashes were required
            if (valid_slash_count == 0 && missing_slash_count == 0) {
                debug("NO SLASHES REQUIRED")
            }

            # Determine the exit code
            if (missing_slash_count > 0) {
                exit ERROR_MISSING_SLASH
            } else if (invalid_slash_count > 0 && ALLOW_UNNECESSARY_SLASHES == "false") {
                exit ERROR_INVALID_SLASH
            } else {
                exit 0
            }
        }' "${filepath}"
}


## main ########################################################################
################################################################################

function main() {
    parse-args "${@}" || return 1

    # If quiet mode is enabled, disable output
    ${DO_QUIET} && disable-output

    local exit_code=0 iter_exit_code=0

    # Iterate over each filepath
    local error_message error_messages
    for filepath in "${FILEPATHS[@]}"; do
        local missing_slash_count=0
        local missing_slash_line_numbers=()
        local range range_start range_end
        local filename_printed=false

        # Print the filepath if there are multiple filepaths
        if ${DO_SHOW_ALL_FILES}; then
            echo "- ${filepath}"
            debug "printing filename: ${filepath}"
            filename_printed=true
        fi

        # Parse this file
        debug "parsing file: ${filepath}"
        error_messages=$(pls-find-missing-slashes "${filepath}" 2>&1)
        [[ -z "${error_messages}" ]] && continue

        # If we aren't showing all files, then only print the filename if there
        # are errors
        if ! ${filename_printed} && ! ${DO_SHOW_ALL_FILES} && [[ -n "${error_messages}" ]]; then
            debug "printing filename: ${filepath}"
            echo "- ${filepath}"
            filename_printed=true
        fi

        # Track the exit code
        iter_exit_code=${?}
        [[ "${exit_code}" == "0" ]] && exit_code="${iter_exit_code}"
        debug "iter_exit_code: ${iter_exit_code} / exit_code: ${exit_code}"

        # Loop over the error messages
        readarray -t error_messages <<< "${error_messages}"
        debug "error_messages: ${error_messages[@]}"
        for error_message in "${error_messages[@]}"; do
            range="${error_message##* }"
            range_start="${range%%:*}"
            range_end="${range##*:}"

            # If this is an unnecessary slash, increase the range by 1
            if [[ "${error_message}" =~ "unnecessary slash" ]]; then
                range_end="$((range_end + 1))"
            fi

            debug "error range: ${range}"

            # Print warnings to stderr and errors to stdout
            if [[ "${error_message}" =~ ^"WARNING" ]]; then
                if [[ ${#FILEPATHS[@]} -gt 1 ]]; then
                    echo "  ${error_message}" >&2
                else
                    echo "${error_message}" >&2
                fi
            else
                echo "${error_message}"
            fi

            # Print context or the block if requested
            if [[ ${CONTEXT} -gt 0 ]] || ${DO_SHOW_BLOCK}; then
                local start end line_num_padding
                # - If showing block AND context, show context around the block
                # - If showing just context, show context around the end of the
                #   block
                # - If showing just the block... then yeah... just do that
                if [[ ${CONTEXT} -gt 0 ]] && ${DO_SHOW_BLOCK}; then
                    start="$((range_start - CONTEXT))"
                    end="$((range_end + CONTEXT))"
                elif [[ ${CONTEXT} -gt 0 ]]; then
                    start="$((range_end - CONTEXT))"
                    end="$((range_end + CONTEXT))"
                else
                    start="${range_start}"
                    end="${range_end}"
                fi
                line_num_padding="${#end}"
                debug "showing context: ${start} - ${end}"
                awk -v start="${start}" -v end="${end}" -v pad="${line_num_padding}" '
                    NR >= start && NR <= end {
                        printf("  %0"pad"s:%s\n", NR, $0)
                    }
                    NR > end { exit }
                ' "${filepath}"
            fi

            # Track the number of missing slashes and insert them if requested
            if [[ "${error_message}" =~ "missing slash" ]]; then
                let missing_slash_count++
                missing_slash_line_numbers+=("${range}")

                # If insert mode is enabled, then insert the slash
                if ${DO_INSERT}; then
                    debug "inserting slash on line $((range_end + 1))"
                    sed -i "$((range_end + 1))i /" "${filepath}"
                    echo "  inserted slash on line $((range_end + 1))"
                fi
            fi
        done | ([[ ${#FILEPATHS[@]} -gt 1 ]] && sed 's/^/  /' || cat)
    done

    return ${exit_code}
}


## run #########################################################################
################################################################################

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "${@}"
