function blah() {
    :  'This is a function

        It does stuff

        @usage
            <file>

        @stdout
            stuff
        '

        [[ -f "${1}" ]] && echo "it's a file" || echo "it's not a file"
}

awk '
    /: *['"'"'"]/    { doprint = "yes" }
    /['"'"'"];$/     { doprint = "no" }
    doprint == "yes" { sub(/^ {0,8}(: ['"'"'"])?/, ""); print}
    doprint == "no"  { exit 0 }
' < <(declare -f blah)
