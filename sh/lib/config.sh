# WIP: should probably borrow the config reading functions from `exwrapper`
#
# A library for parsing and reading configuration files.
#
# Example configuration file:
############################################
# # This is a comment
# [section]
# key = value
# key2 = value2
# key3 =( value3.1 "other value 3.2" )
# key4 =(
#   value4.1
#   other value 4.2   
# )
# key6 = true
# key7 = 3.14
# [[sub-section]]
# key5 = value5
#
# [section2]
# key = value
############################################
#
# Example usage:
############################################
# $ source config.sh
# $ config-use "config.txt"
# $ config-get section key
# $ config-get section.sub-section key
# $ config-set section key "new value"
# $ config-set section.sub-section key "${new_array[@]}"
# # Use a per-command configuration file
# $ config-get section key --config-file "config.txt"
# # Return a default value if the key is not found
# $ config-get section key --default "default value"
# # Return an non-zero exit code if the key is not found
# $ config-get section key --exit-on-missing
# # Return a non-zero exit code if the key does not match the expected type
# $ config-get section key --require bool
# # Return a default value if the key does not match the expected type
# $ config-get section key --require bool --default true

## colors ######################################################################
################################################################################

# Declare an associative array which holds all styles, fg colors, and bg colors
declare -gA __ANSI=(
    [reset]=$'\e[0m'
    [bold]=$'\e[1m'
    [dim]=$'\e[2m'
    [italic]=$'\e[3m'
    [underline]=$'\e[4m'
    [blink]=$'\e[5m'
    [reverse]=$'\e[7m'
    [hidden]=$'\e[8m'
    [black]=$'\e[30m'
    [red]=$'\e[31m'
    [green]=$'\e[32m'
    [yellow]=$'\e[33m'
    [blue]=$'\e[34m'
    [magenta]=$'\e[35m'
    [cyan]=$'\e[36m'
    [white]=$'\e[37m'
    [on-black]=$'\e[40m'
    [on-red]=$'\e[41m'
    [on-green]=$'\e[42m'
    [on-yellow]=$'\e[43m'
    [on-blue]=$'\e[44m'
    [on-magenta]=$'\e[45m'
    [on-cyan]=$'\e[46m'
    [on-white]=$'\e[47m'
)

# @description Print a message in color
# @usage echo-color --color --style [<message>]
function echo-color() {
    # Default values
    local color=""
    local message=()
    local styles=()
    local do_newline=true

    # Loop over the arguments
    while [[ ${#} -gt 0 ]]; do
        case ${1} in
            -n)
                do_newline=false
                ;;
            --*)
                styles+=("${1:2}")
                ;;
            *)
                message+=("${1}")
                ;;
        esac
        shift 1
    done

    # Loop over the list of styles
    for style in "${styles[@]}"; do
        local style_code
        if [[ "${style}" =~ ^f[[:digit:]]+$ ]]; then
            style_code=$'\e[38;5;'${style:1}'m'
        elif [[ "${style}" =~ ^b[[:digit:]]+$ ]]; then
            style_code=$'\e[48;5;'${style:1}'m'
        else
            style_code="${__ANSI[${style}]}"
        fi
        if [[ -z "${style_code}" ]]; then
            echo-err "invalid style '${style}'"
            return 1
        fi
        printf "${style_code}"
    done

    # Print the message
    local n=$(${do_newline} && echo '\n')
    printf "%s\033[0m${n}" "${message[@]}"
}

## helpful functions ###########################################################
################################################################################

# @description Print a message to stderr
# @usage echo-err <message>
function echo-err() {
    echo -e "${FUNCNAME[1]}: ${@}" >&2
}

# @description Set the configuration file to use
# @usage config-use <config-file>
# @exit-code 0 If the configuration file exists
# @exit-code 1 If the configuration file does not exist
# @exit-code 2 If the configuration file is not a file
# @exit-code 3 If the configuration file is not readable
# @exit-code 4 If no configuration file is specified
function config-use() {
    __CONFIG_FILE="${1}"
    if [[ ! -e "${__CONFIG_FILE}" ]]; then
        echo-err "configuration file '${__CONFIG_FILE}' does not exist"
        return 1
    fi
    if ! [[ -f "${__CONFIG_FILE}" ]]; then
        echo-err "configuration file '${__CONFIG_FILE}' is a file"
        return 2
    fi
    if ! [[ -r "${__CONFIG_FILE}" ]]; then
        echo-err "configuration file '${__CONFIG_FILE}' is not readable"
        return 3
    fi
    if [[ -z "${__CONFIG_FILE}" ]]; then
        echo-err "no configuration file specified"
        return 4
    fi
}