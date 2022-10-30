# @description Print an array as a comma-separated list with quotes as needed
# @arg+ $@ The array to print
# @opt -n|--no-newline Do not print a newline at the end of the list
# @opgarg -d|--delimiter The delimiter to use between elements
# @stdout The array as a csv quoted, delimeted list
# @exit 0
# @exit 1 If the array is empty
function csv-echo {
    # Parse the arguments
    local no_newline=0
    local delimiter=","
    declare -a items

    while [ ${#} -gt 0 ]; do
        case "${1}" in
            -n|--no-newline)
                no_newline=1
                shift
                ;;
            -d|--delimiter)
                delimiter="${2}"
                shift 2
                ;;
            *)
                items+=("${1}")
                shift
                ;;
        esac
    done

    local is_first=1
    for item in "${items[@]}"; do
        if [ ${is_first} -eq 1 ]; then
            is_first=0
        else
            printf '%s' "${delimiter}"
        fi

        csv-quote "${item}"
    done

    if [ ${no_newline} -eq 0 ]; then
        echo
    fi
}

# @description Quote a string for use in a CSV file
# @arg $@ The string to quote
# @opgarg -d|--delimiter The CSV delimiter used
# @stdout The quoted string
# @exit 0
# @exit 1 If the string is empty
function csv-quote {
    # Parse the arguments
    local delimiter=","
    local item

    while [ ${#} -gt 0 ]; do
        case "${1}" in
            -d|--delimiter)
                delimiter="${2}"
                shift 2
                ;;
            *)
                [ -z "${item}" ] && item="${1}"
                shift 1
                ;;
        esac
    done

    if [ -z "${item}" ]; then
        return 1
    fi

    # If the item contains whitespace, the delimieter, or a double quote, quote
    # it
    if [[ "${item}" =~ [[:space:]${delimiter}\"] ]]; then
        # Replace double quotes with two double quotes
        item="${item//\"/\"\"}"
        printf '"%s"' "${item}"
    else
        printf '%s' "${item}"
    fi
}
