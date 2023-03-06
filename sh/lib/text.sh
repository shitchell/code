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
    string="${string#"${string%%[![:space:]]*}"}" # remove leading whitespace characters
    string="${string%"${string##*[![:space:]]}"}" # remove trailing whitespace characters
    echo "${string}"
}

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


## awk/sed #####################################################################
################################################################################

function awk-csv() {
    awk -v FPAT="([^,]*)|(\"[^\"]*\")"
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
