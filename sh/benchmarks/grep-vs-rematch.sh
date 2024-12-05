#!/usr/bin/env bash
#
# Test the speed of invoking `grep` vs POSIX extended regex

include-source 'colors'

# Define some colors
C_NUM="${C_CYAN}"
C_PATTERN="${C_BLUE}"
C_TITLE="${S_BOLD}"
C_SUBTITLE="${S_BOLD}${C_CYAN}"
C_COMMENT="${S_DIM}"
C_CMD="${C_GREEN}"

function time_matchfunc() {
    # Time a function call that matches a pattern in a file
    local FUNC="${1}"
    local FILE="${2}"
    local PATTERN="${3}"
    local START=${EPOCHREALTIME} END=
    local matched_lines=""

    # Call the function
    matched_lines=$(match_${FUNC} "${FILE}" "${PATTERN}")
    END=${EPOCHREALTIME}

    # bc <<< "scale=6; ${END} - ${START}" | sed 's/^\./0./'
    # echo -e "s\t$(wc -l <<< "${matched_lines}") lines matched"
    printf "%fs\t%d lines matched\n" \
        "$(bc <<< "scale=6; ${END} - ${START}")" \
        "$(wc -l <<< "${matched_lines}")"
}

function match_grep() {
    # Use `grep` to match the pattern
    grep -E "${2}" "${1}"
}

function match_rematch_while() {
    # Test the speed of invoking `[[ =~ ]]` in a while loop
    while read -r line; do
        if [[ "${line}" =~ ${2} ]]; then
            # Don't actually do anything, but do access the BASH_REMATCH array
            # just in case that impacts performance and will almost always be
            # the case in a real-world scenario
            echo "match: ${BASH_REMATCH[*]}"
        fi
    done < "${1}"
}

function match_rematch_for() {
    # Test the speed of invoking `[[ =~ ]]` in a for loop
    readarray -t file_contents < "${1}"
    for line in "${file_contents[@]}"; do
        if [[ "${line}" =~ ${2} ]]; then
            # Don't actually do anything, but do access the BASH_REMATCH array
            # just in case that impacts performance and will almost always be
            # the case in a real-world scenario
            echo "match: ${BASH_REMATCH[*]}"
        fi
    done
}

# Test the following patterns
PATTERNS=(
    '^[[:space:]]*#.*'  # comments
    '.*[0-9].*'         # lines with numbers
    '.*[a-z].*'         # lines with at least 1 lowercase letter
    '^[^A-Z]*$'         # lines without any uppercase letters
)

# Generate a few files with text from this script
echo -n "${C_COMMENT}* generating test files${C_RESET} "
FILE_CONTENTS=$(<"${0}")
FILES=()
LINECOUNTS=()
BASE_LINECOUNT=$(wc -l <<< "${FILE_CONTENTS}")
for i in {0..10}; do
    printf '.'
    filename=$(printf ".gvr-%02d.txt" "${i}")
    FILES+=("${filename}")
    ## if the file already exists, continue
    if ! [[ -f "${filename}" ]]; then
        ## grow the files exponentially
        for ((j=0; j < (2**i); j++)); do
            printf '%s' "${FILE_CONTENTS}" >> "${filename}"
        done
    fi
    linecount=$(( BASE_LINECOUNT * (2**i) ))
    LINECOUNTS+=("${linecount}")
done
echo " done${S_RESET}"
## set a trap to remove the files
trap 'rm -f -- "${FILES[@]}"' EXIT

# Test the speed of invoking `grep` vs POSIX extended regex
for i in "${!FILES[@]}"; do
    # Print a newline between each file
    ((i > 0)) && printf "\n"

    # Print the file name and line count
    FILE="${FILES[${i}]}"
    LINECOUNT="${LINECOUNTS[${i}]}"
    printf "${C_TITLE}### FILE %02d ${C_COUNT}(%d)${S_RESET}${C_TITLE} ###${S_RESET}\n" \
        "${i}" "${LINECOUNT}"

    # Test each pattern
    for PATTERN in "${PATTERNS[@]}"; do
        printf "  ${C_SUBTITLE}Pattern: ${C_PATTERN}%s${S_RESET}\n" \
            "${PATTERN}"
        printf "    ${C_CMD}grep${S_RESET}:           ${C_COUNT}%s${S_RESET}\n" \
            "$(time_matchfunc grep "${FILE}" "${PATTERN}")"
        printf "    ${C_CMD}[[ =~ ]]/while${S_RESET}: ${C_COUNT}%s${S_RESET}\n" \
            "$(time_matchfunc rematch_while "${FILE}" "${PATTERN}")"
        printf "    ${C_CMD}[[ =~ ]]/for${S_RESET}:   ${C_COUNT}%s${S_RESET}\n" \
            "$(time_matchfunc rematch_for "${FILE}" "${PATTERN}")"
    done
done
