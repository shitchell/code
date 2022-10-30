# @description Escape a string for use in a JSON file
# @arg $1 The string to escape
# @stdin A string to escape
# @stdout The escaped string
# @exit 0
function json-escape() {
    local str="${1}"

    if [ -z "${str}" ]; then
        str=$(cat)
    fi

    echo "${str}" \
        | sed 's/"/\\"/g' \
        | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g' \
        | sed -e ':a' -e 'N' -e '$!ba' -e 's/\r/\\r/g' \
        | sed -e ':a' -e 'N' -e '$!ba' -e 's/\t/\\t/g'
}
