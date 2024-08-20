#!/usr/bin/env bash
#
# Demonstration of a function used as the condition in a while loop.
#
# Example: Read integers from a file and sum them
#   let sum=0
#   while get-integers file.txt; do
#     let sum+=INTEGER
#     echo "int: ${INTEGER}"$'\t'"sum: ${sum}"
#   done
#
# The gist for a while-function loop:
# - the function gets called again at the top of each loop iteration
# - will typically going to read from stdin (since stdin will be preserved
#   across each iteration / function call as well as the last seek position)
# - yields data for each iteration by:
#   - echoing the data to stdout to be captured as part of the loop condition
#     usage: `while data=$(get-data); do echo "${data}"; ...`
#   - exporting a variable inside the function to be used in the loop body
#     usage: `while get-data; do echo "${DATA}"; ...`
# - returns 0 when the function is ready for the next iteration to start
# - returns 1 when the function is done and the loop should exit

## ---- While loop function ----------------------------------------------------

function get-integers() {
    echo "[get-integers] args: ${*}" >&2
    local -- integer
    local -i exit_code

    # Read 1 character at a time until we hit an integer, then continue reading
    # until we hit a non-integer character. Return 0 every time we find an
    # integer. The while loop will exit once this function returns 1, so we'll
    # return 1 once we reach the end of stdin
    while IFS= read -r -n 1 -d '' char; do
        echo "[get-integers] char: ${char}" >&2
        if [[ "${char}" =~ [0-9] ]]; then
            # We found an integer, so add it to the current integer and continue
            integer+="${char}"
            continue
        else
            # Not a number. If we've already started reading an integer, that
            # means we hit its end, so echo it, reset the integer, and return 0
            if [[ -n "${integer}" ]]; then
                echo "${integer}"
                INTEGER="${integer}"
                integer=""
                return 0
            fi
        fi
    done

    exit_code=${?}

    echo "[get-integers] ec: ${exit_code}" >&2

    # The read function will return 0 when it reaches the end of the file
    if [[ ${exit_code} -eq 0 ]]; then
        # EOF!
        return 1
    else
        # We got an error
        echo "[get-integers] Error reading file" >&2
        return 1
    fi
}

FILE="${1}"
FILE_CONTENTS=""

if [[ -z "${FILE}" ]]; then
    # Create fake file contents
    FILE_CONTENTS='
        It was a cold 9th of december at 12:23
        when 42 little elves came to visit.

        They brought 3 gifts each, and 7 of them
        brought 1 extra gift for the host.
    '
else
    FILE_CONTENTS="$(cat "${FILE}")"
fi

echo "File contents:"
echo "${FILE_CONTENTS}"
echo


echo "Using the exported INTEGER variable to store the integer value:"
let sum=0
while get-integers >/dev/null; do
    let sum+=INTEGER
    echo "[main-01] int: ${INTEGER}"$'\t'"sum: ${sum}"
done <<<"${FILE_CONTENTS}"
echo


echo "Using a variable to store the stdout of each call to get-integers:"
let sum=0
while int=$(get-integers); do
    let sum+=int
    echo "[main-02] int: ${int}"$'\t'"sum: ${sum}"
done <<<"${FILE_CONTENTS}"
echo
