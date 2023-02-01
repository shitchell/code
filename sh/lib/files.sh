# Accepts a filename and, if <filename> already exists, returns a unique
# filename in the format <filename>.<n>
function mkuniq() {
    local filename="${1}"
    if [ -f "${filename}" ]; then
        local n=1
        while [ -f "${filename}.${n}" ]; do
            n=$((n+1))
        done
        filename="${filename}.${n}"
    fi
    echo "${filename}"
}
