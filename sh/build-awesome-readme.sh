#!/bin/bash
#
# Reads the tools CSV/TSV file and builds a markdown index + list of all tools


## usage functions #############################################################
################################################################################

function help-epilogue() {
    echo "build an awesome index and list"
}

function help-full() {
    help-usage
    help-epilogue
    echo
    cat << EOF
    -h                 display usage info
    --help             display the full help
    --tsv              interpret utility list as a TSV file
    --csv              interpret utility list as a CSV File
    --auto             attempt to automatically detect whether file is TSV or CSV
    --header  <file>   a markdown header to be included at the top of the README
    --footer <file>    a markdown footer to be included at the bottom of the README
    --awesome <file>   the file that contains the tabulated awesome list
    --build-dir <dir>  the directory to build the README in
EOF
}

function help-usage() {
    echo "usage: $(basename $0) [-h] ..."
}

function parse-args() {
    # Default parameters
    DEFAULT_FILE_FORMAT="tsv" # "csv", "tsv"
    FILE_FORMAT=""
    AWESOME_FILEPATH="./awesome.tsv"
    HEADER_FILEPATH="./header.md"
    FOOTER_FILEPATH="./footer.md"
    FILE_DELIMITER=""
    BUILD_DIR="./_build"
    DO_AUTO_DETECT=false

    # Loop over the arguments
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
            --csv)
                FILE_FORMAT="csv"
                shift 1
                ;;
            --tsv)
                FILE_FORMAT="tsv"
                shift 1
                ;;
            --auto)
                DO_AUTO_DETECT=true
                shift 1
                ;;
            --header)
                HEADER_FILEPATH="${2}"
                shift 2
                ;;
            --footer)
                FOOTER_FILEPATH="${2}"
                shift 2
                ;;
            --awesome)
                AWESOME_FILEPATH="${2}"
                shift 2
                ;;
            --)
                shift 1
                break
                ;;
            *)
                if [[ -z "${AWESOME_FILEPATH}" ]]; then
                    AWESOME_FILEPATH="${1}"
                else
                    help-usage >&2
                    exit 0
                fi
                shift 1
                ;;
        esac
    done

    # If any arguments were left over, treat them as files
    if [ ${#} -gt 0 ]; then
        if [[ -z "${AWESOME_FILEPATH}" ]]; then
            AWESOME_FILEPATH="${1}"
        else
            help-usage >&2
            exit 0
        fi
    fi
}


## useful functions ############################################################
################################################################################

function awk-delimited() {
    local delimiter="${1}"
    shift 1
    awk -v FPAT="([^${delimiter}]*)|(\"[^\"]*\")" -v OFS="${delimiter}" "${@}"
}

# automatically detect if a file is a CSV or TSV
function auto-detect-format() {
    local filepath="${1}"
    local csv_points=0
    local tsv_points=0

    # Check the extension
    local extension="${filepath##*.}"
    extension="${extension,,}"
    [[ "${extension}" == "csv" ]] && let csv_points+=1
    [[ "${extension}" == "tsv" ]] && let tsv_points+=1

    # Check the first two lines
    local lines
    readarray -t lines < <(head -n 2 "${filepath}")
    for line in "${lines[@]}"; do
        [[ "${first_line}" =~ "," ]] && let csv_points+=1
        [[ "${first_line}" =~ $'\t' ]] && let tsv_points+=1
    done

    # If the file has zero points in both categories, then it's probably not a
    # CSV or TSV file
    if [[ ${csv_points} -eq 0 && ${tsv_points} -eq 0 ]]; then
        echo "error: could not auto-detect file format" >&2
        return 1
    fi

    # If the file has equal points in both categories, then it's ambiguous
    if [[ ${csv_points} -eq ${tsv_points} ]]; then
        echo "error: ambiguous file format" >&2
        return 2
    fi

    # Else, return the format with the most points
    if [[ ${csv_points} -gt ${tsv_points} ]]; then
        echo "csv"
    else
        echo "tsv"
    fi
}

function get-column-index() {
    local column_name="${1}"
    local filepath="${2}"
    local delimiter="${3}"

    head -n1 "${filepath}" \
        | awk-delimited "${delimiter}" -v column_name="${column_name}" '{
            for (i=1;i<=NF;i++) {
                if ($i == column_name) {
                    print i;
                }
            }
        }'
}

# Convert a GitHub markdown header to an anchor
# e.g.: "## Foo Bar" -> "foo-bar"
function header-to-anchor() {
    local header="${1}"
    local anchor="${header,,}"
    anchor="${anchor// /-}"
    anchor="${anchor//[^a-z0-9-]/}"
    echo "${anchor}"
}

# Convert text to title case
function title-case() {
    local string="${1}"
    local words
    readarray -t words < <(echo "${string}" | tr ' ' '\n')
    echo "${words[@]^}"
}


## main ########################################################################
################################################################################

function main() {
    parse-args "${@}"

    # If no file format was specified, attempt to auto-detect it
    if [[ -z "${FILE_FORMAT}" ]]; then
        if ${DO_AUTO_DETECT}; then
            FILE_FORMAT="$(auto-detect-format "${AWESOME_FILEPATH}")"
            if [[ ${?} -ne 0 ]]; then
                exit ${?}
            fi
        else
            FILE_FORMAT="${DEFAULT_FILE_FORMAT}"
        fi
    fi

    # Set up the file delimiter
    FILE_DELIMITER=$(
        case "${FILE_FORMAT}" in
            csv)
                echo ","
                ;;
            tsv)
                echo $'\t'
                ;;
            *)
                echo "error: unknown file format '${FILE_FORMAT}'" >&2
                exit 1
                ;;
        esac
    )

    # Parse the awesome list
    local header
    local name_index description_index url_index tags_index
    local name description url tags
    local line markdown_entry
    local line_number=0
    
    ## get the index of each required column
    name_index=$(
        get-column-index "name" "${AWESOME_FILEPATH}" "${FILE_DELIMITER}"
    )
    description_index=$(
        get-column-index "description" "${AWESOME_FILEPATH}" "${FILE_DELIMITER}"
    )
    url_index=$(
        get-column-index "url" "${AWESOME_FILEPATH}" "${FILE_DELIMITER}"
    )
    tags_index=$(
        get-column-index "tags" "${AWESOME_FILEPATH}" "${FILE_DELIMITER}"
    )

    ## ensure that all required columns were found
    if [[
        -z "${name_index}" || -z "${description_index}" || -z "${url_index}" ||
        -z "${tags_index}"
    ]]; then
        echo "error: could not find all required columns" >&2
        echo >&2
        echo "the following columns are required:" >&2
        echo "    name, description, url, tags" >&2
        exit 1
    fi

    ## set up the build directory
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}/tags"

    ## loop over each line to build out the tag information
    while read -r line; do
        # Increment the line number
        let line_number+=1

        # Get the name, description, url, and tags
        name=$(
            awk-delimited "${FILE_DELIMITER}" \
                -v index="${name_index}" '{print $index}' <<< "${line}"
        )
        description=$(
            awk-delimited "${FILE_DELIMITER}" \
                -v index="${description_index}" '{print $index}' <<< "${line}"
        )
        url=$(
            awk-delimited "${FILE_DELIMITER}" \
                -v index="${url_index}" '{print $index}' <<< "${line}"
        )
        tags=$(
            awk-delimited "${FILE_DELIMITER}" \
                -v index="${tags_index}" '{print $index}' <<< "${line}"
        )
        readarray -t tags < <(echo "${tags}" | tr ';' '\n')

        # Add the tags to the list of all tags
        for tag in "${tags[@]}"; do
            echo "${tag}" >> "${BUILD_DIR}/tags.txt"

            # Add an entry for this tool under the tag section
            markdown_entry=$(
                printf -- "- [%s](%s) - %s\n" "${name}" "${url}" "${description}"
            )
            echo "${markdown_entry}" >> "${BUILD_DIR}/tags/${tag}.md"
        done
    done < <(tail -n +2 "${AWESOME_FILEPATH}")

    ## unique-ify the tags
    local sorted_tags
    readarray -t sorted_tags < <(sort -u "${BUILD_DIR}/tags.txt")
    printf "%s\n" "${sorted_tags[@]}" > "${BUILD_DIR}/tags.txt"

    # Start building the README
    local readme="${BUILD_DIR}/README.md"

    ## add the header if it exists
    if [[ -n "${HEADER_FILEPATH}" ]]; then
        cat "${HEADER_FILEPATH}" > "${readme}"
        echo >> "${readme}"
        echo "---" >> "${readme}"
        echo >> "${readme}"
    fi

    ## add the index
    echo "# Index" >> "${readme}"
    echo >> "${readme}"
    local header anchor
    for tag in "${sorted_tags[@]}"; do
        header="$(title-case "${tag}")"
        anchor="$(header-to-anchor "${tag}")"
        echo "- [${header}](#${anchor})" >> "${readme}"
    done
    echo >> "${readme}"
    echo "---" >> "${readme}"

    ## add the list of tools for each category
    echo >> "${readme}"
    local header anchor
    for tag in "${sorted_tags[@]}"; do
        header="$(title-case "${tag}")"
        anchor="$(header-to-anchor "${tag}")"
        echo >> "${readme}"
        echo "## ${header}" >> "${readme}"
        echo >> "${readme}"
        cat "${BUILD_DIR}/tags/${tag}.md" >> "${readme}"
        echo >> "${readme}"
    done

    ## add the footer if it exists
    if [[ -n "${FOOTER_FILEPATH}" ]]; then
        echo >> "${readme}"
        echo "---" >> "${readme}"
        echo >> "${readme}"
        cat "${FOOTER_FILEPATH}" >> "${readme}"
    fi
}


## run #########################################################################
################################################################################

[ "${BASH_SOURCE[0]}" == "${0}" ] && main "${@}"
