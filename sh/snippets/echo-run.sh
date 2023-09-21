function echo-run() {
    local cmd=("${@}")
    local exit_code

    echo "args: ${#cmd[@]}" >&2

    # echo the command...
    printf "\033[32m\u25b6 %s" "${cmd[0]}"
    # ...if there are more than one arguments, print them
    [[ ${#cmd[@]} -gt 1 ]] && printf " %q" "${cmd[@]:1}"
    # ...reset the color and print a newline
    printf "\033[0m\n"

    # if we only have one argument and it contains a space, run it with eval
    if [[ ${#cmd[@]} -eq 1 && "${cmd[0]}" =~ " " ]]; then
        cmd=(eval "${cmd[0]}")
    fi
    # run the command, prepending each line of output with a vertical bar
    "${cmd[@]}" 2>&1 | sed -e '$ ! s/^/\x1b[32m\xe2\x94\x82\x1b[0m / ; $ s/^/\x1b[32m\xe2\x95\xb0\x1b[0m /'
    exit_code=${PIPESTATUS[0]}

    # oh no errors
    if [[ ${exit_code} -ne 0 ]]; then
        echo -e "\033[31mcommand exited with status ${exit_code}\033[0m"
    fi

    # return its exit code
    return ${exit_code}
}

echo-run cd .
echo-run echo $'so much\noutput\nbruh'
echo-run echo "hello
world" -e "wat it do" foo \
    bar this is another thing
echo-run 'echo hello world && exit 25'
