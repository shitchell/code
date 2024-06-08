#!/usr/bin/env bash
#
# Find all resolves in a string and warn about improperly formatted lines

include-source 'debug'

REGEX_RESOLVES="^RESOLVES: *([A-Z]+-[0-9]+)(([-, ;&]|[Aa][Nn][Dd])+[A-Z]+-[0-9]+)*$"
REGEX_JIRA_ISSUE="([A-Z]+-[0-9]+)"

function find-all-resolves() {
    local commit_msg="${1:- $(cat -)}"
    local resolves_lines line_issues resolved_issues

    # Find all lines that start with "RESOLVES:"
    while read -r line; do
        if [[ "${line}" == "RESOLVES:"* ]]; then
            debug "found resolve line: ${line}"
            resolves_lines+=( "${line}" )
        fi
    done <<< "${commit_msg}"
    
    # Loop over each resolves line and add its resolved issues to the array
    for line in "${resolves_lines[@]}"; do
        debug "validating line: ${line}"
        # Validate the line is formatted correctly
        if [[ "${line}" =~ ${REGEX_RESOLVES} ]]; then
            # Capture all jira issues on the line
            readarray -t line_issues < <(
                grep -oE "${REGEX_JIRA_ISSUE}" <<< "${line}"
            )
            if [[ "${#line_issues[@]}" -gt 0 ]]; then
                debug "found ${#line_issues[@]} issues: ${line_issues[*]}"
                # Add the matched issues to the resolved issues list
                resolved_issues+=( "${line_issues[@]}" )
            else
                echo "warning: no jira issues: ${line}" >&2
            fi
        else
            echo "warning: invalid resolve: '${line}'" >&2
        fi
    done
    
    # Print all of the resolved issues sorted and uniq'd
    printf "%s\n" "${resolved_issues[@]}" | sort -u
}

function find-invalid-resolves() {
    local commit_msg="${1:- $(cat -)}"
    let i=0
    local commit_msg_lines

    # Find all lines that start with "RESOLVES:"
    while read -r line; do
        ((i++))
        if [[ "${line}" == "RESOLVES:"* ]]; then
            if ! [[ "${line}" =~ ${REGEX_RESOLVES} ]]; then
                printf "error: invalid resolve on line %d: '%s'\n" \
                    "${i}" "${line}"
            fi
        fi
    done <<< "${commit_msg}"
}

function _test_resolves() {
    local DATA=""
    DATA+=$'This is a commit.\n\n'
    DATA+=$'I did the stuff\n\n'
    DATA+=$'RESOLVES: ABC-123\n'
    DATA+=$'RESOLVES: ABC-123FOO-234DEF-345\n'
    DATA+=$'RESOLVES:ABC-123, ABC-234 ABC-345, and  ABC-456\n'
    DATA+=$'RESOLVES: \n'
    DATA+=$'RESOLVES:  ABC-123 ABC-234 ABC-345 &  ABC-456\n'
    DATA+=$'RESOLVES: ABC-123  ABC-234  ABC-345  and  ABC-456\n'
    DATA+=$'RESOLVES:'

    echo -e "\033[1m==RUNNING 'RESOLVES' TESTS==\033[0m"
    echo
    echo -e "\033[1mCommit Message:\033[0m"
    awk -v ruler=$'\u2502' '{printf("%02d%s %s\n", NR, ruler, $0)}' <<< "${DATA}"
    echo
    echo -e "\033[1mParsing Resolves:\033[0m"
    echo "${DATA}" | find-all-resolves
    echo
    echo -e "\033[1mParsing Invalid Resolves:\033[0m"
    echo "${DATA}" | find-invalid-resolves
}

# If the lib is run at the command line, run tests
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && _test_resolves
