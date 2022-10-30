#!/bin/bash

# Author: shaun.mitchell@trinoor.com
# Date:   2022-07-25
#
# Updates a customization metadata file with the files associated with specified
# customizations. The input file is a csv where each line contains the name of a
# customization and the path to a file...
#
# eg:
#  AS9-CUS-AB-1234,path/to/file.txt
#  AS9-CUS-AB-1235,path/to/other-file.txt
#
# ...where each filepath is relative to the root of the git repository.
#
# The script should be run in a git repository or passed the path to a git
# repository to search the history for each file's last modification time and to
# obtain the file's md5 hash.

include-source 'echo.sh'
include-source 'debug.sh'
include-source 'opg-as-common.sh'
include-source 'text.sh'


### Command line parameters
DATA_FILE=${1}
META_FILE=${2}
REPO_PATH=${3:-.}
###

function usage() {
    debug 'usage() '"$@"
    echo "usage: $(basename $0) <data-file> <metadata-file> [<git-repo>]"
}

function check-params() {
    debug 'check-params() '"$@"
    # Require at least two parameters
    if [ -z "${DATA_FILE}" ] || [ -z "${META_FILE}" ]; then
        usage >&2
        exit 1
    fi

    # Ensure each parameter is a file
    if [ ! -f "${DATA_FILE}" ]; then
        echo "error: data file '${DATA_FILE}' does not exist" >&2
        exit 1
    fi
    if [ ! -f "${META_FILE}" ]; then
        echo "error: metadata file '${META_FILE}' does not exist" >&2
        exit 1
    fi

    # Check that REPO_PATH is a git repository
    if [ ! -d "${REPO_PATH}/.git" ]; then
        echo "error: '${REPO_PATH}' is not a git repository" >&2
        exit 1
    fi
}

# A function for reading csv data using awk
function awk-csv() {
    debug 'awk-csv() '"$@"
    awk -v FPAT="([^,]*)|(\"[^\"]*\")"
}

# Parse a line from the csv file and return an array
function parse-line() {
    debug 'parse-line() '"$@"
    # remove any \r or \n from the line
    line="${1//[\r\n]}"
    # use awk-csv to loop over each field in the line, remove any quotes, strip
    # any spaces, and separate each field with an almost null character
    echo "${line}" | awk-csv '{
        for (i = 1; i <= NF; i++) {
            if ($i ~ /^".*"$/) {
                printf("%s", substr($i, 2, length($i) - 2));
            } else {
                gsub(/^\s*|\s*$/, "", $i);
                printf("%s", $i);
            }
            if (i < NF) {
                printf("\1");
            }
        }
    }'
}

# Validate the given argument as a valid customization nam
function validate-customization() {
    debug 'validate-customization() '"$@"
    cust_name="${1}"
    pat_as9="AS9-CUS([A-Z]{,2})?-[A-Z]{,3}-[0-9]{4}"
    pat_inc="INC*"
    if [[ "$1" =~ $pat_as9 ]] || [[ "$1" =~ $pat_inc ]]; then
        return 0
    else
        return 1
    fi
}

# Simply return the customization with "INC-" prefixed
function update-customization-id() {
    debug 'update-customization-id() '"$@"
    echo "INC-$1"
}

# Define an alias for git to use the correct path to the repository
# function git() {
#     git --git-dir="${REPO_PATH}/.git" --work-tree="${REPO_PATH}" "$@"
# }
alias git='git --git-dir="${REPO_PATH}/.git" --work-tree="${REPO_PATH}"'

# Map git name statuses to the names used in the metadata file
function git-status-map() {
    debug 'git-status-map() '"$@"
    local mapped_status=""
    case "${1}" in
        "A")
            mapped_status="create"
            ;;
        "M")
            mapped_status="update"
            ;;
        "D")
            mapped_status="delete"
            ;;
        *)
            mapped_status="unknown-${1}"
            ;;
    esac
    echo "${mapped_status}"
    debug "mapped_status: ${mapped_status}"
}

# Get last mode, timestamp, and checksum for a file
function get-file-info() {
    debug 'get-file-info() '"$@"
    filepath="${1}"
    info="$(git log -1 --name-status --no-renames --format="%at %h" -- "${filepath}" 2>/dev/null | grep -v '^$')"
    if [ -z "${info}" ]; then
        return 1
    fi
    header="$(echo "${info}" | head -n 1)"
    # The timestamp is the first half of the first line of the output
    timestamp="$(echo "${header}" | cut -d ' ' -f 1)"
    # The hash is the second half of the first line of the output
    hash="$(echo "${header}" | cut -d ' ' -f 2)"
    # The mode is the first character of the second line
    mode="$(echo "${info}" | awk NR==2 | head -c 1)"
    mode="$(git-status-map "${mode}")"
    # Determine the checksum of the file at that commit
    file_contents="$(git show "${hash}:${filepath}" 2>/dev/null)"
    if [ -n "${file_contents}" ]; then
        checksum="$(md5sum <<< "${file_contents}" | cut -d ' ' -f 1)"
    else
        checksum=""
    fi
    debug "${filepath} timestamp=${timestamp} hash=${hash} mode=${mode} checksum=${checksum}"
    echo "${hash} ${mode} ${timestamp} ${checksum}"
}

function get-cust-range {
    debug 'get-cust-range() '"$@"
    cust_name="${1}"
    cust_meta="${2}"

    # Get the line number of the first line of the customization in the metadata file
    cust_start_line=`awk '/<customization id="'"${cust_name}"'">/ { print NR }' "${cust_meta}"`

    # Get the first </customization> tag after the customization if it exists
    if [ "${cust_start_line}" -eq "${cust_start_line}" ] 2>/dev/null; then
        cust_end_line=`awk '/<\/customization>/ { if (NR > '$cust_start_line') { print NR ; exit } }' ${cust_meta}`
        range="${cust_start_line}:${cust_end_line}"
        debug "cust_name=${cust_name} range=${range}"
        echo "${range}"
        return 0
    fi

    # If we get here, the customization was not found in the metadata file
    debug "cust_name=${cust_name} range=NOT_FOUND"
    return 1
}

# Define a function that accepts a customization and an object and returns the line range where the object is found in the metadata file in the format `start_line,end_line`
function get-object-range {
    debug 'get-object-range() '"$@"
    obj_path="${1}"
    cust_name="${2}"
    cust_meta="${3}"

    # Get the customization range
    cust_range=`get-cust-range "${cust_name}" "${cust_meta}"`
    cust_range_start=`echo "${cust_range}" | cut -d',' -f1`
    cust_range_end=`echo "${cust_range}" | cut -d',' -f2`

    if [ -n "$cust_range" ]; then
        # Get the line number of the first line of the object in the metadata file inside the customization range
        obj_line_name="        <name>${obj_path}</name>"
        obj_line_name=`awk -v obj_path="${obj_line_name}" '$0 == obj_path { if (NR > '$cust_range_start' && NR < '$cust_range_end') { print NR ; exit } }' "${cust_meta}"`
        if [ "${obj_line_name}" -eq "${obj_line_name}" ] 2>/dev/null; then
            # We found the object, so go ahead and set the line numbers
            obj_line_start=$(( obj_line_name - 1 ))
            # obj_line_mode=$(( obj_line_start + 2 ))
            # obj_line_ts=$(( obj_line_start + 3 ))
            # obj_line_checksum=$(( obj_line_start + 4 ))
            obj_line_end=$(( obj_line_start + 5 ))
            echo "${obj_line_start}:${obj_line_end}"
            return 0
        fi
    fi

    # If we get here, the object was not found in the metadata file
    return 1
}

function add-cust() {
    debug 'add-cust() '"$@"
    cust_name="${1}"
    cust_meta="${2}"

    sed -i '/<\/customizations>/i\ \ <customization id="'"${cust_name}"'">' ${cust_meta}
    sed -i '/<\/customizations>/i\ \ \ \ <objects>' ${cust_meta}
    sed -i '/<\/customizations>/i\ \ \ \ </objects>' ${cust_meta}
    sed -i '/<\/customizations>/i\ \ </customization>' ${cust_meta}
}

function add-object() {
    debug 'add-object() '"$@"
    obj_path="${1}"
    obj_mode="${2}"
    obj_time="${3}"
    obj_hash="${4}"
    cust_name="${5}"
    cust_meta="${6}"

    # Get the customization range
    cust_line_range=$(get-cust-range "${cust_name}" "${cust_meta}")
    cust_line_range_start=$(echo "${cust_line_range}" | cut -d ':' -f 1)
    cust_line_range_end=$(echo "${cust_line_range}" | cut -d ':' -f 2)
    obj_line_no=$(( cust_line_range_end - 1 ))

    # Add the object to the metadata file
    sed -i "${obj_line_no}i \ \ \ \ \ \ <object>" ${cust_meta}
    let obj_line_no++
    sed -i "${obj_line_no}i \ \ \ \ \ \ \ \ <name>${obj_path}<\/name>" ${cust_meta}
    let obj_line_no++
    sed -i "${obj_line_no}i \ \ \ \ \ \ \ \ <mode>${obj_mode}<\/mode>" ${cust_meta}
    let obj_line_no++
    sed -i "${obj_line_no}i \ \ \ \ \ \ \ \ <timestamp>${obj_time}<\/timestamp>" ${cust_meta}
    let obj_line_no++
    if [ -n "${obj_hash}" ]; then
        # Only add the checksum if it is not empty, i.e. if the file was not deleted
        sed -i "${obj_line_no}i \ \ \ \ \ \ \ \ <checksum>${obj_hash}<\/checksum>" ${cust_meta}
        let obj_line_no++
    fi
    sed -i "${obj_line_no}i \ \ \ \ \ \ <\/object>" ${cust_meta}
}

function update-metadata() {
    debug "${@@Q}"
    cust_name="${1}"
    debug "obj_path: ${obj_path}"
    obj_path="${2}"
    debug "cust_name: ${cust_name}"
    cust_meta="${3}"
    debug "cust_meta: ${cust_meta}"

    # Get the requisite information about the file
    debug "getting file information for '${obj_path}'"
    info=$(get-file-info "${obj_path}")

    # Make sure the info is not empty
    if [ -z "${info}" ]; then
        return 1
    fi

    # Extract each piece of information from the info string
    commit_hash="$(echo "${info}" | cut -d ' ' -f 1)"
    obj_mode="$(echo "${info}" | cut -d ' ' -f 2)"
    obj_time="$(echo "${info}" | cut -d ' ' -f 3)"
    obj_hash="$(echo "${info}" | cut -d ' ' -f 4)"

    # Log some infos
    echo "  object mode: ${obj_mode}"
    echo "  update time: ${obj_time} -- $(date -d @${obj_time})"
    echo "  object hash: ${obj_hash}"

    # Ensure that the customization exists in the metadata file
    cust_line_range=`get-cust-range "${cust_name}" "${META_FILE}"`
    [ -n "${cust_line_range}" ] && cust_exists=true || cust_exists=false

    # If the customization does not exist, create it
    if [ "${cust_exists}" = "false" ]; then
        debug "customization '${cust_name}' not found in '${META_FILE}', adding it"
        add-cust "${cust_name}" "${META_FILE}"
    fi

    # Append this object's metadata to the end of its customization's <objects> list
    add-object "${obj_path}" "${obj_mode}" "${obj_time}" "${obj_hash}" "${cust_name}" "${META_FILE}"
    debug "added object '${obj_path}' to customization '${cust_name}'"
}

function main() {
    debug 'main() '"$@"
    # Ensure the parameters are valid
    check-params

    # Determine the number of items to process
    num_items="$(wc -l < "${DATA_FILE}")"
    i=0

    # Loop over the data file. The metadata file require's each file's:
    #   - name: path (relative to the git root)
    #   - mode: last modification type (create, update, or delete)
    #   - timestamp: last modification time (in seconds since the epoch)
    #   - checksum: md5 hash
    while IFS=$'\n' read -r line; do
        # Parse the line, removing any quotes or trailing/leading whitespace
        # parsed_line="$(parse-line "${line}")"
        line="$(echo "${line}" | tr -d '\r\n')"
        debug "parsing line: '${line}'"
        parsed_line="$(echo "${line}" | tr ',' '\t')"
        # remove any leading/trailing whitespace from the parsed line
        parsed_line="$(echo "${parsed_line}")"
        debug "parsed line: '${parsed_line}'"

        # Split the line into its components
        cust_name="$(echo "${parsed_line}" | cut -d $'\t' -f 1 | sed 's/^[ \t]*//;s/[ \t]*$//' | tr '[a-z]' '[A-Z]')"
        debug "cust_name: '${cust_name}'"
        obj_path="$(echo "${parsed_line}" | cut -d $'\t' -f 2 | sed 's/^[ \t]*//;s/[ \t]*$//')"
        debug "obj_path: '${obj_path}'"

        # Check if the customization name conforms to the expected format. If
        # not, then update it
        if ! validate-customization "${cust_name}"; then
            cust_name="$(update-customization-id "${cust_name}")"
        fi

        # Ensure that the object path doesn't have a leading slash
        if [ "${obj_path:0:1}" = "/" ]; then
            obj_path="${obj_path:1}"
        fi

        # Display the current progress, customization, and filepath
        echo "[$((i+1))/$num_items]" ${cust_name}$'\t'${obj_path}

        # Update the metadata file for the given filepath
        update-metadata "${cust_name}" "${obj_path}" "${META_FILE}"

        # Check to see if the file was successully added to the metadata file
        if [ "$?" -ne "0" ]; then
            echo-stderr "error: unable to update '${cust_name}' - '${obj_path}'"
        fi

        let i++
    done < "${DATA_FILE}"
}

# Run the main function if this script is being run directly
[ "${0}" = "${BASH_SOURCE[0]}" ] && main "${@}"
