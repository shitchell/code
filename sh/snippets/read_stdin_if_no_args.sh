function takes-input() {
    param="${1}"
    
    if [[ -z "${param}" && -t 2 && ! -t 0 ]]; then
        param=$(cat)
    fi
    
    if [[ -z "${param}" ]]; then
        echo "usage: echo data | takes-input" >&2
        echo "usage: takes-input data" >&2
        return 1
    fi
    
    echo "you typed: ${param}"
}

takes-input "${@}"
