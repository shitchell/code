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

# @description If PREVIEW_LINES is set, return only the first N lines, else cat
# @usage preview-output [--text <text>] [--label <label>] [--preview <int>] [<file>]
function preview-output() {
    local file=""
    local label="line"
    local data=""
    local lines=0
    local preview_lines="${PREVIEW_LINES}"

    # Parse the arguments
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            --text)
                data="${2}"
                shift 2
                ;;
            --label)
                label="${2}"
                shift 2
                ;;
            --preview)
                preview_lines="${2}"
                shift 2
                ;;
            -)
                file="/dev/stdin"
                shift 1
                ;;
            -*)
                echo "error: unknown option: ${1}" >&2
                return ${E_INVALID_OPTION:-1}
                ;;
            *)
                file="${1}"
                shift 1
                ;;
        esac
    done

    if [[ -n "${preview_lines}" && ! "${preview_lines}" =~ ^[0-9]+$ ]]; then
        echo "error: invalid preview line count: ${preview_lines}" >&2
        return ${E_INVALID_OPTION:-1}
    fi

    if [[ "${file}" == "-" ]]; then
        file="/dev/stdin"
    elif [[ -z "${file}" && -z "${data}" ]]; then
        echo "error: no text provided" >&2
        return ${E_ERROR:-1}
    fi

    if [[ -n "${file}" && -z "${data}" ]]; then
        data=$(cat "${file}" 2>/dev/null)
    fi
    lines=$(wc -l <<< "${data}" 2>/dev/null)
    debug-vars preview_lines file data lines

    if [[ -n "${preview_lines}" && ${preview_lines} -lt ${lines} ]]; then
        debug "previewing ${preview_lines} lines of ${file}"
        local remainder=$((lines - preview_lines))
        local s=$([[ "${remainder}" != 1 ]] && echo "s")
        local lines_to_show=${preview_lines}
        while read -r line && ((lines_to_show > 0)); do
            echo "${line}"
            ((lines_to_show--))
        done <<< "${data}"
        echo "...and ${remainder} more ${label}${s}"
    else
        debug "previewing all lines of ${file}"
        printf '%s\n' "${data}"
    fi
}


## awk/sed #####################################################################
################################################################################

# @description Remove ANSI escape codes from the specified string
function rmansi() {
    sed $'s,\x1B\[[0-9;]*[a-zA-Z],,g'
}

function awk-csv() {
    awk -v FPAT="([^,]*)|(\"[^\"]*\")"
}

# @description Uniqueify a set of strings based on a column without sorting
# @usage uniqueify [-c <column>] [-d <delimiter>] <file>
function uniq-column() {
    local column=1
    local delimiter=$'\t'
    local filepath data

    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -c)
                column="${2}"
                shift 2
                ;;
            -d)
                delimiter="${2}"
                shift 2
                ;;
            -)
                filepath="/dev/stdin"
                shift 1
                ;;
            --)
                shift 1
                break
                ;;
            -*)
                echo "error: unknown option: ${1}" >&2
                return ${E_INVALID_OPTION}
                ;;
            *)
                filepath="${1}"
                shift 1
                ;;
        esac
    done

    debug-vars column delimiter filepath

    if [[ -n "${filepath}" ]]; then
        data=$(cat "${filepath}" 2>/dev/null) || {
            echo "error: cannot read file: ${filepath}" >&2
            return ${E_FILE_ERROR}
        }
    fi

    if [[ -z "${data}" ]]; then
        data=$(cat)
    fi

    debug-vars data

    if [[ -z "${data}" ]]; then
        return ${E_ERROR}
    fi

    awk -F "${delimiter}" -v col="${column}" '
        {
            value = $col
            if (!seen[value]) {
                seen[value] = 1
                print $0
            }
        }
    ' <<< "${data}"
}
