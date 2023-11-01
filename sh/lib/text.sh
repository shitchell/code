# Accept a string and replace all characters A-Z with [Aa-Zz], e.g.:
#   "Jim's 2 o'clock meeting" -> "[Jj][Ii][Mm]'[Ss] 2 [Oo]'[Cc][Ll][Oo][Cc][Kk] [Mm][Ee][Ee][Tt][Ii][Nn][Gg]"
function case-insensitive-pattern() {
    local pattern="$1"
    local insensitive_pattern=""

    # Loop over each character and replace all letters with their case
    # insensitive counterparts
    local no_change=0 # flag to indicate whether to change the character
    local prev_char="" # track the previous character to account for escaped ']' characters
    while read -r char; do
        if [ ${no_change} -eq 0 ] && [[ "${char}" =~ [A-Za-z] ]] && [ "${prev_char}" != "\\" ]; then
            # if we're actively changing the character and reach a letter, replace it with its case-insensitive counterpart
            insensitive_pattern="${insensitive_pattern}[${char^^}${char,,}]"
        else
            # otherwise, just copy the character as-is
            insensitive_pattern="${insensitive_pattern}${char}"

            if [[ "${char}" == "[" && "${prev_char}" != "\\" ]]; then
                # if we hit an unescaped '[' character, stop changing letters until we reach an unescaped ']' character
                no_change=1
            elif [[ "${char}" == "]" && "${prev_char}" != "\\" ]]; then
                # we've reached an unescaped ']', so resume changing letters
                no_change=0
            fi
        fi

        # store the previous character for the next iteration
        prev_char="${char}"
    done <<< $(grep -o . <<< "${pattern}")

    echo "${insensitive_pattern}"
}

# Return 0 if the specified string is hexadecimal, 1 otherwise
function is-hex() {
    [[ "${1}" =~ ^[0-9a-fA-F]+$ ]]
}

# Return 0 if the specified string is a valid integer, 1 otherwise
function is-int() {
    [[ "${1}" =~ ^[0-9]+$ ]]
}

# Return 0 if the specified string is a valid floating point number, 1 otherwise
function is-float() {
    [[ "${1}" =~ ^[0-9]+\.[0-9]+$ ]]
}

# Return 0 if the specified string is a valid number (integer or floating point), 1 otherwise
function is-number() {
    is-int "${1}" || is-float "${1}"
}

# Remove leading/trailing whitespace from the specified string
function trim() {
    local string="${1}"
    [[ -z "${string}" ]] && read -t 0 && read -r string
    [[ -z "${string}" ]] && return 1
    string="${string#"${string%%[![:space:]]*}"}" # remove leading whitespace characters
    string="${string%"${string##*[![:space:]]}"}" # remove trailing whitespace characters
    echo "${string}"
}

# @description Join the specified strings with the specified delimiter
# @usage join <delimiter> <string> [<string>...]
function join() {
    local delimiter="${1}"
    shift
    printf "%s" "${1}"
    shift
    for string in "${@}"; do
        printf "%s%s" "${delimiter}" "${string}"
    done
}

# @description Convert text to lowercase
# @usage to-lower <string>
function to-lower() {
    awk '{print tolower($0)}' <<< "${1-$(cat)}"
}

# @description Convert text to uppercase
# @usage to-upper <string>
function to-upper() {
    awk '{print toupper($0)}' <<< "${1-$(cat)}"
}

# @description Convert text to randomized upper/lowercase
# @usage to-random-case <string>
# function to-random-case() {
#     local string="${1}"
#     local random_string=""
#     local char=""
#     local random_number=0
#     local random_number_max=0
#     local random_number_min=0
#     local random_number_range=0

#     for (( i = 0; i < ${#string}; i++ )); do
#         char="${string:i:1}"
#         random_number_max=1
#         random_number_min=0
#         random_number_range=$(( random_number_max - random_number_min + 1 ))
#         random_number=$(( RANDOM % random_number_range + random_number_min ))
#         if [ ${random_number} -eq 0 ]; then
#             random_string+="${char,,}"
#         else
#             random_string+="${char^^}"
#         fi
#     done

#     echo "${random_string}"
# }
function to-random-case() {
    awk '{
        srand()
        for (i=1; i<=length($0); i++) {
            if (rand() < 0.5) {
                printf("%s", toupper(substr($0, i, 1)))
            } else {
                printf("%s", tolower(substr($0, i, 1)))
            }
        }
        printf("\n")
    }' <<< "${1-$(cat)}"
}

## latest urlencode from work laptop
# function urlencode() {
#     local string="${1}"
#     local data

#     if [[ $# != 1 ]]; then
#         echo "usage: urlencode <string>" >&2
#         return 1
#     fi

#     data="$(curl -s -o /dev/null -w %{url_effective} --get --data-urlencode "${string}" "")"
#     if [[ $? != 3 ]]; then
#         echo "Unexpected error" 1>&2
#         return 2
#     fi

#     echo "${data##/?}"
# }

# function urlencode() {
    # # urlencode <string>
    # local string="${1}"
    # local string_urlencoded=""
    # local length="${#1}"
    # for (( i = 0; i < length; i++ )); do
        # local c="${1:i:1}"
        # case $c in
            # [a-zA-Z0-9.~_-]) string_urlencoded+="${c}" ;;
            # *) string_urlencoded+=$(printf '%%%02X' "'$c") ;;
        # esac
    # done
    # echo "${string_urlencoded}"
# }

## latest urlencode/decode from librem
# # @description Format a string to be URL encoded
# # @usage urlencode <string>
# # @caveats Does not handle special characters / UTF-8 well
# function urlencode() {
    # local string="${1}"
    # local strlen=${#string}
    # local encoded=""
    # local pos c o
# 
    # for ((pos=0; pos<strlen; pos++)); do
        # c=${string:$pos:1}
        # case "$c" in
            # [-_.~a-zA-Z0-9])
                # o="${c}"
                # ;;
            # *)
                # printf -v o '%%%02x' "'$c"
                # ;;
        # esac
# 
        # encoded+="${o}"
    # done
    # printf "%s\n" "${encoded}"
    # # You can either set a return variable (FASTER)   REPLY="${encoded}"
    # #+or echo the result (EASIER)... or both... :p}'"
# }

# @description Format a string to be URL encoded
# @usage urlencode <string>
# @usage echo <string> | urlencode -
function urlencode() {
    local string="${1}"
    local LANG=C
    local IFS=

    if [[ "${string}" == "-" ]]; then
        string="$(cat && echo x)"
        string="${string%x}"
    fi

    if [[ -z "${string}" ]]; then
        return 1
    fi

    printf "%s" "${string}" | while read -n1 -r -d "$(echo -n "\000")" c; do
        case "$c" in
            [-_.~a-zA-Z0-9])
                echo -n "$c"
                ;;
            *)
                printf '%%%02x' "'$c"
                ;;
        esac
    done
}

# function urlencode() {
    # local string="${1}"
    # local data
#
    # if [[ $# != 1 ]]; then
        # echo "usage: urlencode <string>" >&2
        # return 1
    # fi
#
    # data="$(curl -s -o /dev/null -w %{url_effective} --get --data-urlencode "${string}" "")"
    # if [[ $? != 3 ]]; then
        # echo "Unexpected error" 1>&2
        # return 2
    # fi
#
    # echo "${data##/?}"
# }

# @description Parse a URL encoded string into plain text
# @usage urldecode <string>
# @usage echo <string> | urldecode -
function urldecode() {
    local string="${1}"
    local LANG=C
    local IFS=

    if [[ "${string}" == "-" ]]; then
        string="$(cat && echo x)"
        string="${string%x}"
    fi

    if [[ -z "${string}" ]]; then
        return 1
    fi

    # This is perhaps a risky gambit, but since all escape characters must be
    # encoded, we can replace %NN with \xNN and pass the lot to printf -b, which
    # will decode hex for us
    printf '%b' "${string//%/\\x}"
}


## awk/sed #####################################################################
################################################################################

function awk-csv() {
    awk -v FPAT="([^,]*)|(\"[^\"]*\")"
}

# @description Uniqueify lines based on one or more fields
# @usage uniqueify [-d <delimiter>] [-c <column>] file
# @usage cat file | uniqueify [-d <delimiter>] [-c <column>]
function uniqueify() {
    local delimiter=" "
    local columns=()
    local file="-"

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -d | --delimiter)
                delimiter="${2}"
                shift 2
                ;;
            -c | --column)
                columns+=("${2}")
                shift 2
                ;;
            *)
                file="${1}"
                shift 1
                ;;
        esac
    done

    # Use awk to uniqueify the lines
    awk -F "${delimiter}" -v delimiter="${delimiter}" -v columns="${columns[*]}" '
        BEGIN {
            split(columns, columns_array, " ")
            for (i in columns_array) {
                column = columns_array[i]
                if (column ~ /^[0-9]+$/) {
                    column_array[column] = 1
                } else {
                    column_array[column] = 0
                }
                print "-- column: " column " | i: " i " | column_array[column]: " column_array[column] > "/dev/stderr";
            }
        }
        {
            key = ""
            for (i in column_array) {
                if (column_array[i] == 1) {
                    key = key delimiter $i
                } else {
                    key = key delimiter "\"" $i "\""
                }
            }
            print "-- key: " key > "/dev/stderr";
            if (!seen[key]++) {
                print
            }
            else { print "skipping: " $0 > "/dev/stderr" }
        }
    ' < <(cat "${file}")
}

## json ########################################################################
################################################################################

# @description Escape a string for use in JSON, e.g. as a key or value
# @usage json-escape [--(no-)quotes] <string>
# @attribution https://stackoverflow.com/a/29653643 https://stackoverflow.com/a/74426351/794241
function json-escape() {
    local text=()
    local do_quotes="" # false if empty

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -q | --quotes)
                do_quotes=true
                shift
                ;;
            -Q | --no-quotes)
                do_quotes=""
                shift
                ;;
            *)
                text+=("$1")
                shift
                ;;
        esac
    done

    [[ -z "${text}" ]] && text=$(cat -)
    [[ -z "${text}" ]] && return

    awk -v do_quotes="${do_quotes}" '
        BEGIN {
            for ( i = 1; i <= 127; i++ ) {
                # Handle reserved JSON characters and special characters
                switch ( i ) {
                    case 8:  repl[ sprintf( "%c", i) ] = "\\b"; break
                    case 9:  repl[ sprintf( "%c", i) ] = "\\t"; break
                    case 10: repl[ sprintf( "%c", i) ] = "\\n"; break
                    case 12: repl[ sprintf( "%c", i) ] = "\\f"; break
                    case 13: repl[ sprintf( "%c", i) ] = "\\r"; break
                    case 34: repl[ sprintf( "%c", i) ] = "\\\""; break
                    case 92: repl[ sprintf( "%c", i) ] = "\\\\"; break
                    default: repl[ sprintf( "%c", i) ] = sprintf( "\\u%04x", i );
                }
            }

            for ( i = 1; i < ARGC; i++ ) {
                if (i == 1 && do_quotes) {
                    printf("\"")
                } else if (i > 1) {
                    printf(" ")
                }

                s = ARGV[i]
                while ( match( s, /[\001-\037\177"\\]/ ) ) {
                    printf("%s%s", \
                        substr(s,1,RSTART-1), \
                        repl[ substr(s,RSTART,RLENGTH) ] \
                    )
                    s = substr(s,RSTART+RLENGTH)
                }

                printf("%s", s)
                if (i == (ARGC - 1) && do_quotes) {
                    printf("\"")
                }
            }
            exit
        }
    ' "${text[@]}"
}

# @description determine the type of a JSON value
# @usage json-type <value>
function json-type() {
    local value="${1}"
    local json_type

    if [[ "${value}" == "null" ]]; then
        type="null"
    elif [[ "${value}" == "true" || "${value}" == "false" ]]; then
        type="boolean"
    elif [[ "${value}" =~ ^[0-9]+$ ]]; then
        type="integer"
    elif [[ "${value}" =~ ^[0-9]+\.[0-9]+$ ]]; then
        type="float"
    elif [[ "${value}" =~ ^\".*\"$ ]]; then
        type="string"
    elif [[ "${value}" =~ ^\[.*\]$ ]]; then
        type="array"
    elif [[ "${value}" =~ ^\{.*\}$ ]]; then
        type="object"
    else
        type="unknown"
    fi

    echo "${type}"
}

# @description Convert an array with values in the format `key=value` to a JSON object
# @usage json-map-from-keys [--detect-types] <key=value>...
function json-map-from-keys() {
    local key_value_pairs=()
    local detect_types=true

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -d | --detect-types)
                detect_types=true
                shift
                ;;
            -D | --no-detect-types)
                detect_types=false
                shift
                ;;
            *)
                key_value_pairs+=("$1")
                shift
                ;;
        esac
    done

    # if no values given, check stdin
    if [ ${#key_value_pairs[@]} -eq 0 ]; then
        while read -r line; do
            key_value_pairs+=("${line}")
        done
    fi

    local json='{'
    for key_value_pair in "${key_value_pairs[@]}"; do
        local key="${key_value_pair%%=*}"
        local value="${key_value_pair#*=}"
        debug "key_value_pair: ${key} = ${value}"

        # Detect type if requested
        if ${detect_types}; then
            local json_type="$(json-type "${value}")"
            case "${json_type}" in
                "integer" | "float" | "boolean" | "null" | "array" | "object")
                    value="${value}"
                    ;;
                "string" | "unknown")
                    value=$(json-escape -q "${value}")
                    ;;
            esac
        else
            value=$(json-escape -q "${value}")
        fi
        json="${json}\"${key}\": ${value}, "
    done
    json="${json%, }}"

    echo "${json}"
}
