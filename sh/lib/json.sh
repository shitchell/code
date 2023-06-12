include-source 'text.sh'

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

# @description Parse a JSON-formatted string
# @arg $1 The string to parse
# @stdin A string to parse
# @stdout The parsed string
function json-parse() {
    local str="${1}"

    if [ -z "${str}" ]; then
        str=$(cat)
    fi
    
    echo "${str}" \
        | awk '{
            gsub(/\\n/, "\n")
            gsub(/\\r/, "\r")
            gsub(/\\t/, "\t")
            gsub(/\\"/, "\"")
            print
        }' \
        | printf "%b" "$(cat)"
}

# @description determine the type of a JSON value
# @usage json-type <value>
function json-type() {
    # Remove leading and trailing whitespace and newlines
    local value=$(echo "${1}" | tr -d '\n' | trim "${1}" | tr -d '\n')
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
