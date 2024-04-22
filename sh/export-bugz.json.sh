#!/bin/bash
#
# Export Bugzilla data to json including attachments.
#
# Jira JSON sections:
#  - users
#  - issues
#  - links
#  - 

## usage functions #############################################################
################################################################################

function help-usage() {
    echo "usage: $(basename $0) [-hAcCeEq] [-a <directory>] [-r <prefix>] [-w <where clause>] [-l <limit>] [-o <orderby clause>] [-d <database>] [-u <db username>] [-p <db password>] [-H <db host>] [-P <db port>]"
}

function help-epilogue() {
    echo "Export Bugzilla data to json including attachments"
}

function help-full() {
    help-usage
    help-epilogue
    echo
    cat << EOF
    -h                      display usage
    --help                  display this help message
    -a/--attachments-dir    directory to export attachments to
    -A/--no-attachments     don't export attachments
    -c/--comments           include comments in the description
    -C/--no-comments        don't include comments in the description
    -r/--attachment-prefix  prefix to add to attachment filepath in JSON output
                            (e.g.: 'https://server.com/bugzilla/')
    -e/--url-encode         url encode attachment filenames
    -E/--no-url-encode      don't url encode attachment filenames
    -w/--where              SQL WHERE clause to filter bugs
                            (e.g. `-w "bugs.bug_id > 1000"`)
    -l/--limit              SQL LIMIT clause to limit the number of results
    -o/--order-by           SQL ORDER BY clause to order the results
                            (e.g. `-o "bugs.bug_id DESC"`)
    -d/--db                 database to use
    -u/--user               database username
    -p/--password           database password
    -H/--host               database host
    -P/--port               database port
    -q/--quiet              don't print anything to stdout
EOF
}

function parse-args() {
    # Default values
    ATTACHMENTS_DIR="./attachments"
    ATTACHMENTS_PREFIX=""
    EXPORT_ATTACHMENTS=1
    INCLUDE_COMMENTS=0
    URL_ENCODE_ATTACHMENTS=0
    DB_NAME="bugzilla"
    DB_USER="root"
    DB_PASSWORD="${MYSQL_PWD}"
    DB_HOST="localhost"
    DB_PORT="3306"
    SQL_WHERE=""
    SQL_LIMIT=""
    SQL_ORDER_BY=""
    VERBOSITY=1

    # Loop over the arguments
    declare -ga REFS
    declare -ga FILEPATHS
    while [[ ${#} -gt 0 ]]; do
        case ${1} in
            -h)
                help-usage
                help-epilogue
                exit 0
                ;;
            --help)
                help-full
                exit 0
                ;;
            -a|--attachments-dir)
                ATTACHMENTS_DIR="${2}"
                EXPORT_ATTACHMENTS=1
                shift 2
                ;;
            -A|--no-attachments)
                ATTACHMENTS_DIR=""
                EXPORT_ATTACHMENTS=0
                shift
                ;;
            -r|--attachments-prefix)
                ATTACHMENTS_PREFIX="${2}"
                shift 2
                ;;
            -c|--comments)
                INCLUDE_COMMENTS=1
                shift
                ;;
            -C|--no-comments)
                INCLUDE_COMMENTS=0
                shift
                ;;
            -e|--url-encode)
                URL_ENCODE_ATTACHMENTS=1
                shift
                ;;
            -E|--no-url-encode)
                URL_ENCODE_ATTACHMENTS=0
                shift
                ;;
            -w|--where)
                SQL_WHERE="WHERE ${2}"
                shift 2
                ;;
            -l|--limit)
                SQL_LIMIT="LIMIT ${2}"
                shift 2
                ;;
            -o|--order-by)
                SQL_ORDER_BY="ORDER BY ${2}"
                shift 2
                ;;
            -d|--db)
                DB_NAME="${2}"
                shift 2
                ;;
            -u|--user)
                DB_USER="${2}"
                shift 2
                ;;
            -p|--password)
                DB_PASSWORD="${2}"
                shift 2
                ;;
            -H|--host)
                DB_HOST="${2}"
                shift 2
                ;;
            -P|--port)
                DB_PORT="${2}"
                shift 2
                ;;
            -q|--quiet)
                VERBOSITY=0
                shift 1
                ;;
            -*)
                GIT_LOG_OPTS+=("${1}")
                exit 1
                ;;
            *)
                if [ ${positional_files} -eq 0 ]; then
                    REFS+=("${1}")
                else
                    FILEPATHS+=("${1}")
                fi
                shift 1
                ;;
        esac
    done
}


## helpful functions ###########################################################
################################################################################

# Echo the specified number of indent strings without a newline
function echo-indent() {
    local indent_level=${1:-0}
    local indent_string=${2}
    [ -z "${indent_string}" ] && indent_string="${INDENT_STRING:-  }"

    while [ ${indent_level} -gt 0 ]; do
        echo -n "${indent_string}"
        let indent_level--
    done
}

# Echo the specified message with the specified indent level
function echo-indented() {
    local indent_level=${1:-0}
    local message=${2:-""}

    echo-indent ${indent_level} ${INDENT_STRING:-" "}
    echo "${message}"
}

function get-sql() {
    local sql_query="${1:-""}"
    local field_separator=${2}

    if [ -n "${field_separator}" ]; then
        shift 2
    else
        shift 1
    fi

    # Set up the mysql options
    local mysql_opts=(
        "--user=${DB_USER}"
        "--host=${DB_HOST}"
        "--port=${DB_PORT}"
        "--database=${DB_NAME}"
        "--batch"
        "--column-names"
        "--protocol=tcp"
        "--execute=${sql_query}"
        ${@}
    )

    # Run the query
    local rows # declared first to allow for capturing the return code
    rows=$(MYSQL_PWD="${DB_PASSWORD}" mysql "${mysql_opts[@]}")
    local exit_code=${?}

    if [ ${exit_code} -ne 0 ]; then
        return ${exit_code}
    fi

    if [ -n "${field_separator}" ] \
    && [ "${field_separator}" != $'\t' ]; then
        rows=$(echo "${rows}" | awk -v FS="${field_separator}" '{gsub("\t", FS); print}')
    fi

    echo "${rows}"
}

# Given a bug id and filename, export the attachment to the specified directory
# usage:
#   export-attachment <bug_id> <attachment_id> <filename>
#   export-attachment <attachment_id> <filename>
#   export-attachment <attachment_id>
function export-attachment() {
    if [ ${#} -ge 3 ]; then
        local bug_id="${1}"
        local attachment_id="${2}"
        local attachment_filename="${3}"
        local attachment_dir="${ATTACHMENTS_DIR}/${bug_id}/${attachment_id}"
    elif [ ${#} -eq 2 ]; then
        local attachment_id="${1}"
        local attachment_filename="${2}"
        local bug_id=$(
            get-sql "SELECT bug_id FROM attachments WHERE attach_id=${attachment_id}" -s -s
        )
        local attachment_dir="${ATTACHMENTS_DIR}/${bug_id}/${attachment_id}"
    elif [ ${#} -eq 1 ]; then
        local attachment_id="${1}"
        local bug_id=$(
            get-sql "SELECT bug_id FROM attachments WHERE attach_id=${attachment_id}" -s -s
        )
        local attachment_filename=$(
            get-sql "SELECT filename FROM attachments WHERE attach_id=${attachment_id} LIMIT 1" -s -s
        )
        local attachment_dir="${ATTACHMENTS_DIR}/${bug_id}/${attachment_id}"
    else
        echo "export-attachment: invalid number of arguments" >&2
        return 1
    fi
    local attachment_filepath="${attachment_dir}/${attachment_filename}"

    # echo "exporting attachment '${attachment_id}' to '${attachment_filepath}'" >&2

    # Get the attachment data
    local sql_query="
        SELECT thedata from attach_data
        WHERE id = ${attachment_id}
    "

    # Set up the mysql options
    local mysql_opts=(
        "--user=${DB_USER}"
        "--host=${DB_HOST}"
        "--port=${DB_PORT}"
        "--database=${DB_NAME}"
        "--raw"
        "--column-names=0"
        "--protocol=tcp"
        "--execute=${sql_query}"
    )

    # Create the attachment directory
    mkdir -p "${attachment_dir}"

    # Export the attachment
    MYSQL_PWD="${DB_PASSWORD}" mysql "${mysql_opts[@]}" > "${attachment_filepath}"
    local exit_code=${?}

    if [ ${exit_code} -ne 0 ]; then
        echo "error exporting attachment '${attachment_id}' to '${attachment_filepath}'" >&2
        if [ -f "${attachment_filepath}" ] \
        && [ $(wc -c < "${attachment_filepath}") -eq 0 ]; then
            rm -f "${attachment_filepath}"
        fi
    else
        echo "${attachment_filepath}"
    fi

    return ${exit_code}
}

function export-attachments() {
    local bug_id=${1}

    if [ -z "${bug_id}" ]; then
        return 1
    fi

    # Get all of the attachments for the bug
    local sql_query="
        SELECT attach_id, filename from attachments
        WHERE bug_id = ${bug_id}
    "
    IFS=$'\n' read -r -d '' -a attachments < <(get-sql "${sql_query}" $'\t' -s -s)
    # echo "got attachments:" >&2
    # printf '  %s\n' "${attachments[@]}" >&2

    # Loop over the attachments
    for attachment in "${attachments[@]}"; do
        local attach_id=$(echo "${attachment}" | awk -F $'\t' '{print $1}')
        local filename=$(echo "${attachment}" | awk -F $'\t' '{print $2}')

        export-attachment "${bug_id}" "${attach_id}" "${filename}"
    done
}

# Escape the specified string for JSON
function json-escape() {
    printf '%s' "$1" | python -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

# URL encode the specified string
function urlencode() {
    local string="${1}"
    local data

    if [[ $# != 1 ]]; then
        echo "usage: urlencode <string>" >&2
        return 1
    fi

    data="$(curl -s -o /dev/null -w %{url_effective} --get --data-urlencode "${string}" "")"
    if [[ $? != 3 ]]; then
        echo "Unexpected error" 1>&2
        return 2
    fi

    echo "${data##/?}"
}

# Split a string into an array
function split() {
    local string="${1}"
    local separator="${2:-$'\t \n\f\r'}"
    local array_name="${3}"

    if [ -z "${string}" ]; then
        echo "split: invalid number of arguments" >&2
        return 1
    fi

    local IFS="${separator}"
    if [ -n "${array_name}" ]; then
        read -r -a "${array_name}" <<< "${string}"
    else
        read -r -a array <<< "${string}"
        echo "${array[@]}"
        unset array
    fi
}

# Convert an array to a JSON array
function array-to-json() {
    local array=("${@}")
    local json_array

    if [ ${#array[@]} -eq 0 ]; then
        echo "array-to-json: invalid number of arguments" >&2
        return 1
    fi

    json_array='['
    local is_first=1
    for element in "${array[@]}"; do
        [ ${is_first} -eq 1 ] && is_first=0 || json_array+=' '
        json_array+="$(json-escape "${element}"),"
    done
    json_array="${json_array%,}]"

    echo "${json_array}"
}


## main ########################################################################
################################################################################

function main() {
    parse-args "${@}"

    # Verify connection to the database and table
    if ! get-sql "SHOW TABLES" -s -s >/dev/null; then
        echo "error: unable to connect to database, exiting" >&2
        return 1
    fi

    # Determine any custom fields
    # We select the namez twice so that we can more easily generate the pattern:
    #   bugs.%s as %s
    # in the sql query that follows
    local custom_fields=($(
        get-sql "SELECT name, name FROM fielddefs WHERE custom = 1" ' ' -s -s
    ))

    # Start by querying all the bugs
    local bugs_query="
        SELECT
            bugs.bug_id AS bug_id,
            assigned.login_name AS assigned_to,
            reporter.login_name AS reporter,
            qa.login_name AS qa_contact,
            bugs.short_desc AS summary,
            (
                SELECT thetext FROM longdescs
                WHERE bug_id = bugs.bug_id
                ORDER BY bug_when ASC
                LIMIT 1
            ) AS description,
            bugs.creation_ts AS created,
            bugs.delta_ts AS modified,
            bugs.estimated_time AS estimated_time,
            bugs.remaining_time AS remaining_time,
            bugs.deadline AS deadline,
            bugs.lastdiffed AS lastdiffed,
            bugs.everconfirmed AS everconfirmed,
            bugs.op_sys AS operating_system,
            bugs.rep_platform AS rep_platform,
            components.name AS component,
            products.name as product,
            bugs.version AS version,
            (
                SELECT value FROM bug_see_also
                WHERE bug_id = bugs.bug_id
                LIMIT 1
            ) AS bug_file_loc,
            bugs.priority AS priority,
            bugs.target_milestone AS target_milestone,
            bugs.bug_severity as severity,
            bugs.bug_status AS status,
            bugs.resolution AS resolution,
            `printf "bugs.%s as %s, " "${custom_fields[@]}"`
            (SELECT COUNT(*) FROM attachments WHERE attachments.bug_id = bugs.bug_id) AS attachments_count
        FROM
            bugs
        LEFT JOIN
            profiles AS assigned ON assigned.userid = bugs.assigned_to
        LEFT JOIN
            profiles AS reporter ON reporter.userid = bugs.reporter
        LEFT JOIN
            profiles AS qa ON qa.userid = bugs.qa_contact
        LEFT JOIN
            components ON components.id = bugs.component_id
        LEFT JOIN
            products ON products.id = bugs.product_id
        ${SQL_WHERE}
        ${SQL_ORDER_BY}
        ${SQL_LIMIT}
        ;"

    # Read the query into an array, replacing tabs with field separators
    IFS=$'\n' read -r -d '' -a bugs_output < <(get-sql "${bugs_query}" $'\034')
    local sql_ec=$?

    # Exit if the command exited with a non-zero status or returned no output
    if [ ${#bugs_output[@]} -eq 0 ]; then
        if [ ${sql_ec} -ne 0 ]; then
            echo "error: MySQL command failed (${sql_ec})" >&2
            exit 1
        fi
        echo "error: MySQL command returned no output" >&2
        exit 1
    fi

    # Echo the beginnings of the JSON output
    local indent_level=0
    echo-indented $((indent_level++)) "{"
    echo-indented $((indent_level++)) '"bugs": ['

    # noglob is necessary to prevent globbing of the field separator when
    # creating arrays for each row
    set -f

    # Loop over all of the rows of the SQL query
    local is_header=1
    local row=0
    local column_names=()
    local row_data=()
    local bug_id=""
    local attachments_count=0
    for line in "${bugs_output[@]}"; do
        # Store the header / column names from the first line
        if [ ${is_header} -eq 1 ]; then
            IFS=$'\034' column_names=(${line}'')
            is_header=0
            continue
        fi

        # Extract each piece of data from the line
        IFS=$'\034' row_data=(${line}'')

        # Loop over and print out each key / value pair
        local i=0
        local num_items=${#column_names[@]}
        echo-indented $((indent_level++)) "{"
        local comma=""
        while [ ${i} -lt ${num_items} ]; do
            local key=${column_names[${i}]}
            local value=${row_data[${i}]}

            # Handle certain keys specially
            if [ "${key}" = "bug_id" ]; then
                # Store this for use fetching attachments
                bug_id=${value}
            elif [ "${key}" = "attachments_count" ]; then
                attachments_count=${value}
            elif [ "${key}" = "description" ]; then
                # If exporting comments, add them to the description
                if [ ${INCLUDE_COMMENTS} -eq 1 ]; then
                    local comments_query comments_output comments_ec comments
                    comments_query="
                        SELECT
                            profiles.login_name AS author,
                            longdescs.bug_when AS created,
                            longdescs.thetext AS body
                        FROM
                            longdescs
                        LEFT JOIN
                            profiles ON profiles.userid = longdescs.who
                        WHERE
                            longdescs.bug_id = ${bug_id}
                        ORDER BY
                            longdescs.bug_when ASC
                        ;"
                    IFS=$'\n' comments_output=($(get-sql "${comments_query}" $'\034' -s -s))
                    comments_ec=$?
                    if [ ${comments_ec} -ne 0 ]; then
                        echo "error: could not fetch comments for ${bug_id} (${comments_ec})" >&2
                    elif [ ${#comments_output} -gt 0 ]; then
                        # Loop over all of the comments
                        local comment_row=0
                        for comment_line in "${comments_output[@]}"; do
                            # Skip the first comment; it's a duplicate of the description
                            if [ ${comment_row} -eq 0 ]; then
                                comment_row=1
                                continue
                            fi

                            # Extract each piece of data from the line
                            IFS=$'\034' comment_row_data=(${comment_line}'')
                            local author="${comment_row_data[0]}"
                            local created="${comment_row_data[1]}"
                            local body="${comment_row_data[2]}"

                            # Append the comment to the description
                            value="${value}\\n\\n--- Comment #$((comment_row++)) from ${author} on ${created} ---\\n${body}"
                        done
                    fi

                fi
            fi

            # Escape any double quotes in the value
            value="${value//\"/\\\"}"

            # Print out the key / value pair
            if [ ${i} -lt $((num_items - 1)) ] \
            || [ ${EXPORT_ATTACHMENTS} -eq 1 ]; then
                comma=","
            else
                comma=""
            fi
            echo-indented $((indent_level)) "\"${key}\": \"${value}\"${comma}"

            let i++
        done

        # Export and print out the attachments if requested
        if [ ${EXPORT_ATTACHMENTS} -eq 1 ]; then
            if [ ${attachments_count} -le 0 ]; then
                echo-indented $((indent_level)) '"attachments": []'
            else
                local i_attachments=0
                echo-indented $((indent_level++)) '"attachments": ['
                while IFS= read -r attachment_filepath; do
                    # URL encode the attachment filename if necessary
                    if [ ${URL_ENCODE_ATTACHMENTS} -eq 1 ]; then
                        local attachment_dirname=$(dirname "${attachment_filepath}")
                        local attachment_filename=$(basename "${attachment_filepath}")
                        attachment_filename=$(urlencode "${attachment_filename}")
                        attachment_filepath="${attachment_dirname}/${attachment_filename}"
                    fi
                    # Determine if we need to add a prefix to the filepath
                    if [ -n "${ATTACHMENTS_PREFIX}" ]; then
                        attachment_filepath="${ATTACHMENTS_PREFIX}/${attachment_filepath#\./}"
                    fi
                    [ $((i_attachments + 1)) -lt ${attachments_count} ] && comma="," || comma=""
                    echo-indented $((indent_level)) "\"${attachment_filepath}\"${comma}"
                    let i_attachments++
                done < <(export-attachments "${bug_id}")
                echo-indented $((--indent_level)) "]"
            fi
        fi

        # Print out the closing brace
        [ ${row} -lt $((${#bugs_output[@]} - 2)) ] && comma="," || comma=""
        echo-indented $((--indent_level)) "}${comma}"

        let row++
    done

    # Echo the end of the JSON output
    echo-indented $((--indent_level)) "]"
    echo-indented $((--indent_level)) "}"
}

## run #########################################################################
################################################################################

[ "${BASH_SOURCE[0]}" == "${0}" ] && main "${@}"
