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

function urlencode() {
    # urlencode <string>
    local string="${1}"
    local string_urlencoded=""
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) string_urlencoded+="${c}" ;;
            *) string_urlencoded+=$(printf '%%%02X' "'$c") ;;
        esac
    done
    echo "${string_urlencoded}"
}


## awk/sed #####################################################################
################################################################################

function awk-csv() {
    awk -v FPAT="([^,]*)|(\"[^\"]*\")"
}
