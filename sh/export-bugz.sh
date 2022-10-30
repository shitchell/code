#!/bin/bash
#
# Export Bugzilla data to CSV including attachments and comments.
#
# For integration with JIRA, we must include multiple "Comment" and "Attachment"
# columns. There should be as many "Comment" columns as the issue with the most
# comments. There should be as many "Attachment" columns as the issue with the
# most attachments. Each issue that has fewer comments or attachments should
# have empty columns for the missing data.
#
# Jira settings:
#  - File encoding: ISO-8859-1
#  - CSV Delimiter: ,
#  - Date format:
#    - yyyy-MM-dd hh:mm:ss | default
#    - M/dd/yyyy  h:mm:ss a | %-m/%-d/%-Y %l:%M:%S %p
#  - Fields
#    - Attachment: Attachment / Map field value
#    - Comment: Comment Body / Map field value
#    - Description: Description / Map field value
#
# Bugzilla statuses:
#  [X] CLOSED
#  [ ] CONFIRMED
#  [ ] IN_PROGRESS
#  [X] ON HOLD
#  [X] PENDING VERIFICATION
#  [ ] RESOLVED
#  [ ] UNCONFIRMED


include-source 'csv.sh'
include-source 'json.sh'

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
    -A/--no-attachments     don'select export attachments
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
    -s/--date-format        strftime format to use for dates in the output
                            (e.g. `-s "%Y-%m-%d %H:%M:%S"`)
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
    DATE_FORMAT=""
    EXPORT_ATTACHMENTS=0
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
            -s|--date-format)
                DATE_FORMAT="${2}"
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

        # Ensure only safe characters are in filenames and collapse whitespace
        filename=$(
            echo "${filename}" \
                | tr -cd '[:alnum:][:space:]()._-' \
                | sed -E 's/[[:space:]]+/ /g'
        )

        export-attachment "${bug_id}" "${attach_id}" "${filename}"
    done
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
    local separator="${2:-$'\t\n\034'}"
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

# Convert newlines to Jira's newline format
function jira-newlines() {
    local string="${1}"

    # If no arguments are passed, read from stdin
    if [ ${#} -eq 0 ]; then
        string=$(cat)
    fi

    if [ -z "${string}" ]; then
        echo "jira-newlines: invalid number of arguments" >&2
        return 1
    fi

    echo "${string}" | tr -d '\r' | sed ':a;N;$!ba;s/\n/\n\\\\ /g'
}


## main ########################################################################
################################################################################

function main() {
    parse-args "${@}"

    # Verify connection to the database and table
    if ! get-sql "SHOW TABLES" -s -s >/dev/null; then
        echo "error: unable to connect to database, exiting" >&2
        echo "  database: ${DB_NAME}" >&2
        echo "  host:     ${DB_HOST}" >&2
        echo "  port:     ${DB_PORT}" >&2
        echo "  user:     ${DB_USER}" >&2
        return 1
    fi

    # Get the max number of comments across all bugs
    local max_comments
    if [ ${INCLUDE_COMMENTS} -eq 1 ]; then
        local max_comments_query="
            SELECT MAX(comments) FROM (
                SELECT COUNT(*) AS comments FROM longdescs GROUP BY bug_id
            ) AS comments
        "
        max_comments=$(
            get-sql "${max_comments_query}" -s -s
        )
        # Comments include the description, so subtract 1
        let max_comments--
    fi

    # Get the max number of attachments across all bugs
    local max_attachments
    if [ ${EXPORT_ATTACHMENTS} -eq 1 ]; then
        local max_attachments_query="
            SELECT MAX(attachments) FROM (
                SELECT COUNT(*) AS attachments FROM attachments GROUP BY bug_id
            ) AS attachments
        "
        max_attachments=$(
            get-sql "${max_attachments_query}" -s -s
        )
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
            (SELECT COUNT(*) FROM attachments WHERE attachments.bug_id = bugs.bug_id) AS attachments_count,
            (SELECT COUNT(*) FROM longdescs WHERE longdescs.bug_id = bugs.bug_id) AS comments_count
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
    "

    # Determine all Asset Suite Issues that have been updated since '2022-09-27 12:00:00'
    local asset_suite_bugs_updated_query="
        SELECT bugs.bug_id, bugs.delta_ts as last_modified, bugs.short_desc as summary FROM bugs
        LEFT JOIN components ON components.id = bugs.component_id
        LEFT JOIN products ON products.id = bugs.product_id
        WHERE products.name = 'Asset Suite' AND components.name = 'Issue' AND bugs.delta_ts > '2022-09-27 12:00:00'
        ORDER BY bugs.bug_id ASC;
    "

    # Create a table that includes all of the bug ids that have been exported
    # with a timestamp of when they were exported, where the bug_id is a foreign
    # key to the bugs table
    # Exported:
    # +-------------+--------------+------+-----+---------+----------------+
    # | Field       | Type         | Null | Key | Default | Extra          |
    # +-------------+--------------+------+-----+---------+----------------+
    # | bug_id      | mediumint(9) | NO   | PRI | NULL    |                |
    # | export_ts   | datetime     | NO   |     | NULL    |                |
    # | bug_status  | varchar(64)  | NO   | MUL | NULL    |                |
    # +-------------+--------------+------+-----+---------+----------------+
    local create_exported_table_query="
        CREATE TABLE IF NOT EXISTS exported (
            bug_id mediumint(9) NOT NULL,
            export_ts datetime NOT NULL,
            bug_status varchar(64) NOT NULL,
            PRIMARY KEY (bug_id),
            FOREIGN KEY (bug_id) REFERENCES bugs(bug_id)
        );
    "
    # Read the 'trizilla-pv-ids.txt' file and insert the bug_ids into the table with a timestamp of '2022-09-27 11:38:38'
    # 'trizilla-pv-ids.txt' is in the format of:
    #  1483
    #  1738
    #  1913
    #  ...
    local insert_exported_table_query="
        INSERT INTO exported (bug_id, export_ts, bug_status) VALUES $(sed -e 's/^/(/' -e 's/$/, "2022-09-27 11:38:38", "PENDING VERIFICATION"),/' trizilla-pv-ids.txt | sed '$ s/,$//')
    "

    # Determine all Asset Suite Issues that have been updated since they were exported
    local asset_suite_bugs_updated_since_exported_query="
        SELECT bugs.bug_id as 'Bug ID', bugs.delta_ts as 'Last Modified', exported.bug_status as 'Exported Status', bugs.bug_status AS 'Status', bugs.short_desc as 'Summary' FROM bugs
        LEFT JOIN components ON components.id = bugs.component_id
        LEFT JOIN products ON products.id = bugs.product_id
        LEFT JOIN exported ON exported.bug_id = bugs.bug_id
        WHERE products.name = 'Asset Suite' AND components.name = 'Issue' AND bugs.delta_ts > exported.export_ts
        ORDER BY bugs.bug_id ASC;
    "

    # Determine all Asset Suite Issues that have been created since '2022-09-27 11:38:38'
    local asset_suite_bugs_created_since_exported_query="
        SELECT bugs.bug_id as 'Bug ID', bugs.delta_ts as 'Last Modified', exported.bug_status as 'Exported Status', bugs.bug_status AS 'Status', bugs.short_desc as 'Summary' FROM bugs
        LEFT JOIN components ON components.id = bugs.component_id
        LEFT JOIN products ON products.id = bugs.product_id
        LEFT JOIN exported ON exported.bug_id = bugs.bug_id
        WHERE products.name = 'Asset Suite' AND components.name = 'Issue' AND bugs.creation_ts > '2022-09-27 11:38:38'
        ORDER BY bugs.bug_id ASC;
    "

    # Determine how many bugs there are in the Asset Suite product and Issue component,
    # grouped by status, along with a total count of all bugs in the product/component
    local asset_suite_bugs_status_query="
        SELECT bugs.bug_status, COUNT(*) FROM bugs
            LEFT JOIN components ON components.id = bugs.component_id
            LEFT JOIN products ON products.id = bugs.product_id
            WHERE products.name = 'Asset Suite' AND components.name = 'Issue'
            GROUP BY bugs.bug_status
        UNION SELECT 'Total', COUNT(*) FROM bugs
            LEFT JOIN components ON components.id = bugs.component_id
            LEFT JOIN products ON products.id = bugs.product_id
            WHERE products.name = 'Asset Suite' AND components.name = 'Issue';
    "

    # Get every bug_id of every bug in the Asset Suite product and Issue component
    local asset_suite_bugs_query="
        SELECT bugs.bug_id FROM bugs
        LEFT JOIN components ON components.id = bugs.component_id
        LEFT JOIN products ON products.id = bugs.product_id
        WHERE products.name = 'Asset Suite' AND components.name = 'Issue'
        ORDER BY bugs.bug_id ASC;
    "

    # Determine all Asset Suite Issues that have been updated since '2022-10-04 09:30:00'
    local asset_suite_bugs_updated_query="
        SELECT bugs.bug_id, bugs.delta_ts as last_modified, bugs.bug_status, bugs.short_desc as summary FROM bugs
        LEFT JOIN components ON components.id = bugs.component_id
        LEFT JOIN products ON products.id = bugs.product_id
        WHERE products.name = 'Asset Suite' AND components.name = 'Issue' AND bugs.delta_ts > '2022-10-05 09:00:00'
        ORDER BY bugs.bug_id ASC;
    "

    # Find all attachments for bug 1954
    local asset_suite_bug_1954_attachments_query="
        SELECT attachments.attach_id, attachments.bug_id, attachments.creation_ts, attachments.description, attachments.filename, attachments.ispatch, attachments.isobsolete, attachments.isprivate, attachments.mimetype, attachments.submitter_id, attachments.thedata, attachments.thedata AS 'Attachment Data' FROM attachments
        WHERE attachments.bug_id = 1954;
    "
    # Find all issues opened by "quinn.gribben@trinoor.com", including their summary and how many attachments they have
    local asset_suite_issues_opened_by_quinn_query="
        SELECT bugs.bug_id as 'Bug ID', bugs.cf_c2e_ref as 'OPG Ref', bugs.creation_ts as 'Created', bugs.short_desc as 'Summary', COUNT(attachments.attach_id) AS 'Number of Attachments' FROM bugs
        LEFT JOIN attachments ON attachments.bug_id = bugs.bug_id
        LEFT JOIN profiles ON profiles.userid = bugs.reporter
        WHERE profiles.login_name = 'quinn.gribben@trinoor.com'
        GROUP BY bugs.bug_id
        ORDER BY bugs.bug_id ASC;
    "

    # List all products and components
    local products_and_components_query="
        SELECT products.name AS 'Product', components.name AS 'Component' FROM products
        LEFT JOIN components ON components.product_id = products.id
        ORDER BY products.name ASC, components.name ASC;
    "

    # List the issue count grouped by product, component, and status
    local issue_count_by_product_component_status_query="
        SELECT products.name AS 'Product', components.name AS 'Component', bugs.bug_status AS 'Status', COUNT(*) AS 'Count' FROM bugs
        LEFT JOIN components ON components.id = bugs.component_id
        LEFT JOIN products ON products.id = bugs.product_id
        GROUP BY products.name, components.name, bugs.bug_status
        ORDER BY products.name ASC, components.name ASC, bugs.bug_status ASC;
    "

    # Show the character encoding used for all columns in the bugs table
    local bugs_table_character_encoding_query="
        SELECT column_name, character_set_name FROM information_schema.columns
        WHERE table_schema = 'bugs' AND table_name = 'bugs';
    "

    # Show the character encoding used for the trizilla database
    local trizilla_database_character_encoding_query="
        SELECT default_character_set_name FROM information_schema.schemata
        WHERE schema_name = 'bugs';
    "

    # +------------------------+-------------+----------------------+-------+
    # | Product                | Component   | Status               | Count |
    # +------------------------+-------------+----------------------+-------+
    # | TAShelix Documentation | Asset Suite | CONFIRMED            |    34 |
    # | TAShelix Documentation | eSoms       | CONFIRMED            |     5 |
    # | TAShelix Documentation | Maximo      | CONFIRMED            |    15 |
    # | TAShelix Documentation | Maximo      | RESOLVED             |     3 |
    # +------------------------+-------------+----------------------+-------+
    # Loop over all of the TAShelix Documentation Components and Statuses, calling `export-bugz.sh` to export each bug
    # products=("TAShelix Documentation" "TAShelix Documentation" "TAShelix Documentation" "TAShelix Documentation")
    # components=("Asset Suite" "eSoms" "Maximo" "Maximo")
    # statuses=("CONFIRMED" "CONFIRMED" "CONFIRMED" "RESOLVED")
    # for ((i=0; i<${#products[@]}; i++)); do
    #     product=${products[$i]}
    #     component=${components[$i]}
    #     status=${statuses[$i]}
    #     MYSQL_PWD="${DB_PASSWORD}" ~/code/sh/export-bugz.sh -u trizilla -d trizilla -r https://devops.trinoor.com/bugzilla \
    #         -w "products.name = '${product}' AND components.name = '${component}' AND bugs.bug_status = '${status}'" \
    #         -c -a "./attachments" -e \
    #             | tee trizilla-${product// /_}-${component// /_}-"${status// /_}".csv
    # done

    # Loop over all of the TAShelix Documentation Statuses, calling `export-bugz.sh` to export each bug, grouped by product and status
    # products=("TAShelix Documentation" "TAShelix Documentation")
    # statuses=("CONFIRMED" "RESOLVED")
    # for ((i=0; i<${#products[@]}; i++)); do
    #     product=${products[$i]}
    #     status=${statuses[$i]}
    #     MYSQL_PWD="${DB_PASSWORD}" ~/code/sh/export-bugz.sh -u trizilla -d trizilla -r https://devops.trinoor.com/bugzilla \
    #         -w "products.name = '${product}' AND bugs.bug_status = '${status}'" \
    #         -c -a "./attachments" -e \
    #             | tee trizilla-${product// /_}-"${status// /_}".csv
    # done

    # Read the query into an array, replacing tabs with field separators
    IFS=$'\n' read -r -d '' -a bugs_output < <(get-sql "${bugs_query}" $'\034')
    local sql_ec=${?}

    # Exit if the command returned no output
    if [ ${#bugs_output[@]} -eq 0 ]; then
        if [ ${sql_ec} -ne 0 ]; then
            echo "error: MySQL command failed (${sql_ec})" >&2
            exit 1
        fi
        echo "error: MySQL command returned no output" >&2
        exit 1
    fi
    echo "## Processing ${#bugs_output[@]} bugs" >&2
    echo >&2

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
    local comments_count=0
    for line in "${bugs_output[@]}"; do
        # Store the header / column names from the first line and print the
        # CSV header
        if [ ${is_header} -eq 1 ]; then
            # Store the column names
            IFS=$'\034' column_names=(${line}'')
            is_header=0

            # Print the CSV header
            csv-echo -n "${column_names[@]}"

            # Print $max_comments comments headers
            if [ ${INCLUDE_COMMENTS} -eq 1 ]; then
                for ((i=0; i<${max_comments}; i++)); do
                    echo -n ",Comment"
                done
            fi

            # Print $max_attachments attachments headers
            if [ ${EXPORT_ATTACHMENTS} -eq 1 ]; then
                for ((i=0; i<${max_attachments}; i++)); do
                    echo -n ",Attachment"
                done
            fi

            echo
            continue
        fi

        # Extract each piece of data from the line
        IFS=$'\034' row_data=(${line}'')

        # Loop over and print out each column
        local num_items=${#column_names[@]}
        local comma
        for ((i=0; i<${num_items}; i++)); do
            local key=${column_names[${i}]}
            local value=${row_data[${i}]}
            # echo "processing ${i}/${num_items} '${key}' = '${value}'"

            # Unescape any escaped characters
            value=$(printf '%b' "${value}")

            # Handle certain keys specially
            if [ "${key}" = "bug_id" ]; then
                # Store this for use fetching attachments
                bug_id=${value}
            elif [ "${key}" = "attachments_count" ]; then
                attachments_count=${value}
            elif [ "${key}" = "comments_count" ]; then
                let value--
                comments_count=${value}
            elif [ -n "${DATE_FORMAT}" ] && (
                [ "${key}" = "created" ] \
                || [ "${key}" = "modified" ] \
                || [ "${key}" = "deadline" ] \
                || [ "${key}" = "lastdiffed" ]
            ); then
                # Format the date using the specified format
                value=$(
                    date -d "${value}" +"${DATE_FORMAT}" \
                        | sed -E 's/^\s*//;s/\s*$//'
                )
            fi

            # CSV quote value if necessary
            value=$(csv-quote "${value}")

            if [ "${key}" = "description" ]; then
                value=$(echo "${value}" | jira-newlines)
            elif [ "${key}" = "cf_cust_id" ]; then
                # If the value is "na", then set it to an empty string
                if [ "${value}" = "na" ]; then
                    value=""
                else
                    # This will include labels, so uppercase and remove everything
                    # except spaces, numbers, letters, and hyphens
                    value=$(
                        echo "${value}" \
                            | tr '[:lower:]' '[:upper:]' \
                            | tr -cd '[:alnum:][:space:]-'
                    )
                fi
            fi

            # And a comma if necessary
            if [ ${i} -lt $((num_items - 1)) ]; then
                comma=","
            else
                comma=""
            fi

            # Print out the value
            printf "%s%s" "${value}" "${comma}"
        done

        # If exporting comments, print
        if [ ${INCLUDE_COMMENTS} -eq 1 ]; then
            local comments_query comments_output comments_ec comments

            # Get the comments for this bug
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
            "
            IFS=$'\n' comments_output=($(get-sql "${comments_query}" $'\034' -s -s))
            comments_ec=$?
            if [ ${comments_ec} -ne 0 ]; then
                echo "error: could not fetch comments for ${bug_id} (${comments_ec})" >&2
            fi

            # Loop over and print out the comments
            local comments_processed=0
            local is_first=1
            for comment in "${comments_output[@]}"; do
                # echo "processing bug ${bug_id} comment #${comments_processed} '${comment}'" >&2
                # Skip the first comment; it's a duplicate of the description
                if [ ${is_first} -eq 1 ]; then
                    is_first=0
                    continue
                fi

                # Extract each piece of data from the line
                IFS=$'\034' comment_row_data=(${comment}'')
                local author="${comment_row_data[0]}"
                local created="${comment_row_data[1]}"
                local body="${comment_row_data[2]}"

                # Echo the comment if the body is not empty
                if [ -n "${body}" ]; then
                    # If a date format was specified, format the date
                    if [ -n "${DATE_FORMAT}" ]; then
                        created=$(
                            date -d "${created}" +"${DATE_FORMAT}" \
                                | sed -E 's/^\s*//;s/\s*$//'
                        )
                    fi
                    # Unescape any escaped characters
                    body=$(printf '%b' "${body}")
                    # Jira requires newlines in comments to have a \\ on the second line
                    body=$(csv-quote "${body}")
                    # Remove the leading and trailing double quotes
                    body="${body:1}"
                    body="${body:0:-1}"
                    # Fix the newlines
                    body=$(echo "${body}" | jira-newlines)

                    # printf ",%s;%s;%s" \
                    #     $(csv-quote "${created}") \
                    #     $(csv-quote "${author}") \
                    #     $(csv-quote "${body}" \
                    #         | tr -d '\r' \
                    #         | sed -e 's/\\n/\n\\\\ /g'
                    #     )
                    printf ',"%s"' "${created};${author};${body}"
                    # Increment the number of comments processed
                    let comments_processed++
                else
                    echo -n
                    # echo "skipping empty comment for bug ${bug_id}" >&2
                    # echo "  - created: '${created}'" >&2
                    # echo "  - author:  '${author}'" >&2
                    # echo "  - body:    '${body}'" >&2
                fi
            done
            # If we didn't process all of the comments, print empty fields
            if [ ${comments_processed} -lt ${max_comments} ]; then
                local needed_fields=$((max_comments - comments_processed))
                for ((i=0; i<${needed_fields}; i++)); do
                    echo -n ","
                done
            fi

        fi

        # Export and print out the attachments if requested
        if [ ${EXPORT_ATTACHMENTS} -eq 1 ]; then
            local attachments_processed=0
            while IFS= read -r attachment_filepath; do
                if [ -z "${attachment_filepath}" ]; then
                    continue
                fi
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
                printf ",%s" $(csv-quote "${attachment_filepath}")
                let attachments_processed++
            done < <(export-attachments "${bug_id}")
            # If we didn't process all of the attachments, print empty fields
            if [ ${attachments_processed} -lt ${max_attachments} ]; then
                local needed_fields=$((max_attachments - attachments_processed))
                for ((i=0; i<${needed_fields}; i++)); do
                    echo -n ","
                done
            fi
        fi

        # End the row
        echo
        let row++
    done
}

## run #########################################################################
################################################################################

[ "${BASH_SOURCE[0]}" == "${0}" ] && main "${@}"
