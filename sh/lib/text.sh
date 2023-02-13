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

            if [ "${char}" = "[" ] && [ "${prev_char}" != "\\" ]; then
                # if we hit an unescaped '[' character, stop changing letters until we reach an unescaped ']' character
                no_change=1
            elif [ "${char}" = "]" ] && [ "${prev_char}" != "\\" ]; then
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
# @usage json-escape <string>
# @attribution https://stackoverflow.com/a/29653643 https://stackoverflow.com/a/74426351/794241
function json-escape() {
    local string="${1}"
    [[ -z "${string}" ]] && string=$(cat -)
    [[ -z "${string}" ]] && return

    LANG=C awk '
        BEGIN {
            for ( i = 1; i <= 127; i++ ) {
                # Handle reserved JSON characters
                switch ( i ) {
                    case 8: repl[ sprintf( "%c", i) ] = "\\b"; break
                    case 9: repl[ sprintf( "%c", i) ] = "\\t"; break
                    case 10: repl[ sprintf( "%c", i) ] = "\\n"; break
                    case 12: repl[ sprintf( "%c", i) ] = "\\f"; break
                    case 13: repl[ sprintf( "%c", i) ] = "\\r"; break
                    case 34: repl[ sprintf( "%c", i) ] = "\\\""; break
                    case 92: repl[ sprintf( "%c", i) ] = "\\\\"; break
                    default: repl[ sprintf( "%c", i) ] = sprintf( "\\u%04x", i );
                }
            }

            for ( i = 1; i < ARGC; i++ ) {
                s = ARGV[i]
                # printf("%s", "\"")  # uncomment to surround with double quotes

                while ( match( s, /[\001-\037\177"\\]/ ) ) {
                    printf("%s%s", \
                        substr(s,1,RSTART-1), \
                        repl[ substr(s,RSTART,RLENGTH) ] \
                    )
                    s = substr(s,RSTART+RLENGTH)
                }
                print s #"\""  # uncomment to surround with double quotes
            }
            exit
        }
    ' "${string}"
}

# Convert an array with values in the format `key=value` to a JSON object
function json-map-from-keys() {
    local values=("${@}")

    # if no values given, check stdin
    if [ ${#values[@]} -eq 0 ]; then
        while read -r line; do
            values+=("${line}")
        done
    fi

    local json='{'
    for value in "${values[@]}"; do
        local key=$(echo "${value}" | cut -d '=' -f 1 | json-escape)
        local val=$(echo "${value}" | cut -d '=' -f 2- | json-escape)
        json="${json}\"${key}\": \"${val}\", "
    done
    json="${json%, }}"

    echo "${json}"
}
