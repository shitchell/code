: '
This module contains functions for debugging bash scripts.

TODO:
    - [ ] We recently implemented a breaking change to make debug_labels
          inherit a debug_level. This should consider whether or not a
          debug_level was manually specified and, if so, use that level.
    - [ ] We should consider adding a DEBUG_COLOR environment variable to
          enable or disable color output for debug messages.
    - [ ] We should consider a DEBUG_FORMAT environment variable to allow
          users to customize the format of debug messages.
    - [ ] Fix the debug examples to be on separate lines OR change the docs
          library to interpret examples on separate lines.
'

function debug() (
    # shellcheck disable=SC2016
    :  'Print debug information if either $DEBUG or $DEBUG_LOG are set

        `debug` calls are typically used to display a message. They can
        optionally be empty (i.e. `debug`) to simply return a 0 or 1 indicating
        whether debugging is enabled, e.g.: `if debug; then ...; fi`. If a
        message is provided, it will be printed conditionally based on its log
        level (default: 1) and the value of the $DEBUG environment variable.

        If the first argument to `debug` is an integer, it is treated as the log
        level for that debug statement. This is used in conjunction with the
        $DEBUG environment variable to determine if the message should be
        printed. If the $DEBUG level is less than the debug statement log
        level, the message will not be printed. If a `debug` statement does not
        specify a log level, it defaults to 1.

        For simplicity, the $DEBUG environment variable can be set to "true",
        "all", or "*" to enable all debug messages. If $DEBUG is set to an
        integer, then only debug messages with a log level less than or equal to
        that integer will be printed.

        The first argument can also be one of the following strings to indicate
        a specific category of debug message:
            - "error" (prints in red)
            - "warn" (prints in yellow)
            - "info" (prints in cyan)
            - "success" (prints in green)

        The $DEBUG_LOG environment variable can also be set to enable debugging.
        When it is set, all debug messages will be written to the file specified
        by $DEBUG_LOG. If $DEBUG_LOG is set and $DEBUG is not, then $DEBUG will
        default to 1.

        If $DEBUG is set to an integer, it is treated as the maximum debug level
        to be printed.

        Each line of the debug output is prefixed with a timestamp, the path to
        the script, the function name (if applicable), and line number where the
        debug statement was called from. If multiple messages are passed as
        multiple arguments to the `debug` statement, they will be printed on
        separate lines. If a single debug message includes multiple lines of
        output, each line will include the same prefix.

        @usage
            [<level>] [<label>] [<message>]

        @optarg level
            The log level of the debug message. Must be an integer.
            Default: 1

        @optarg label
            The category of the debug message. If provided, it should be one of
            the following strings: "error", "warn", "info", or "success". If
            provided, the message will be printed in a specific color.

        @optarg message
            The debug message to print.

        @example
            DEBUG=1   debug "foo bar"         # will print
            DEBUG=1   debug 2 "foo bar"       # will not print
            DEBUG=2   debug 1 "foo bar"       # will print
            DEBUG=all debug "foo bar"         # will print
            DEBUG=all debug 2 "foo bar"       # will print
            DEBUG=1   debug error "foo bar"   # will print in red
            DEBUG=1   debug 2 error "foo bar" # will not print
            DEBUG=2   debug 2 error "foo bar" # will print in red
        
        @stderr
            A timestamped debug message.

        @return 0
            Debugging is enabled
        
        @return 1
            Debugging is not enabled
        '
    local debug_file  # the file to write messages to
    local debug_level  # the debug level of this message
    local debug_label  # the label for this debug message (error, warn, info, success)
    local timestamp  # the timestamp of this message
    local function_name  # the name of the calling function
    local script_name  # the name of the calling script
    local line_number  # the line number of the debug call in the calling script
    local line_loc  # the script, function, and line number of the debug call
    local text_color  # the color to use for the debug message

    ## Ensure stdin is never tampered with or damaged
    exec 0</dev/null # close stdin

    # if DEBUG and DEBUG_LOG are not set, return
    if [[ -z "${DEBUG}" && -z "${DEBUG_LOG}" ]]; then
        return 1
    fi

    # if DEBUG_LOG is set, then use that as the log file, else use /dev/stderr
    if [[ -n "${DEBUG_LOG}" ]]; then
        if [[ -z "${DEBUG}" ]]; then
            # if DEBUG is not set, default to 1
            DEBUG=1
        fi
        debug_file="${DEBUG_LOG}"
        # Point file descriptor 3 to the debug file
        exec 3>>"${debug_file}"
    else
        # Point file descriptor 3 to stderr
        exec 3>&2
    fi

    # determine if the first arg is an integer
    if [[ "${1}" =~ ^[0-9]+$ ]]; then
        # if it is, then use it as this debug message's debug level
        debug_level=${1}
        shift
    else
        case "${1}" in
            scs | success)
                debug_level=0
                debug_label="success"
                shift
                ;;
            err | error)
                debug_level=0
                debug_label="error"
                shift
                ;;
            wrn | warn)
                debug_level=10
                debug_label="warn"
                shift
                ;;
            inf | info)
                debug_level=20
                debug_label="info"
                shift
                ;;
            dbg | debug)
                debug_level=30
                debug_label="debug"
                shift
                ;;
            *)
                debug_level=1
                debug_label=""
                ;;
        esac
    fi

    # print the debug message if:
    #   - DEBUG is set to "true", "all", or "*", or
    #   - DEBUG is set to an integer and >= the debug level, or
    #   - DEBUG_LOG is set (if DEBUG is not set, default to 1)
    if [[
        "${DEBUG}" =~ ^"true"|"all"|"*"$ \
        || ("${DEBUG}" =~ ^[0-9]+$ && "${DEBUG}" -ge ${debug_level})
    ]]; then
        # if no arguments at all are provided, simply return 0 to indicate that
        # the debug message would have been printed
        if [[ -z "${1}" ]]; then
            return 0
        fi

        # create a timestamp
        timestamp=$(date +"%Y-%m-%d %H:%M:%S")

        # get the calling function name
        if [[ -n "${DEBUG_FUNCTION_NAME}" ]]; then
            function_name="${DEBUG_FUNCTION_NAME}"
        else
            function_name=${FUNCNAME[$((DEBUG_SOURCE_LEVEL + 1))]}
        fi

        # get the calling script name
        if [[ -n "${DEBUG_SCRIPT_NAME}" ]]; then
            script_name="${DEBUG_SCRIPT_NAME}"
        else
            script_name=$(basename "${BASH_SOURCE[$((DEBUG_SOURCE_LEVEL - 1))]}")
        fi

        # get the calling line number
        if [[ -n "${DEBUG_LINE_NUMBER}" ]]; then
            line_number="${DEBUG_LINE_NUMBER}"
        else
            line_number=${BASH_LINENO[0]}
        fi

        # handle color and some formatting
        if [[ "${DEBUG_COLOR}" =~ ^"false"|"0"$ ]]; then
            # timestamp
            timestamp="[${timestamp}]"

            # line description
            [[ -n "${script_name}" ]] && line_loc+="${script_name}"
            [[ -n "${function_name}" ]] && line_loc+=":${function_name}()"
            [[ -n "${line_number}" ]] && line_loc+=":${line_number}"

            # handle specific categories of debug messages
            if [[ "${debug_label}" =~ ^("error"|"warn"|"info"|"success")$ ]]; then
                text_color=""
            fi
            text_color_end=""
        else
            # timestamp
            timestamp=$'\033[36m['"${timestamp}"$']\033[0m'

            # line description
            [[ -n "${script_name}" ]] && line_loc+=$'\033[35m'"${script_name}"$'\033[0m'
            [[ -n "${function_name}" ]] && line_loc+=$'\033[35;1m:'"${function_name}"$'()\033[0m'
            [[ -n "${line_number}" ]] && line_loc+=$'\033[32m:'"${line_number}"$'\033[0m'

            # handle specific categories of debug messages
            if [[ -n "${debug_label}" ]]; then
                case "${debug_label}" in
                    err | error)
                        text_color=$'\033[31;1m'
                        ;;
                    wrn | warn)
                        text_color=$'\033[33;1m'
                        ;;
                    inf | info)
                        text_color=$'\033[36;1m'
                        ;;
                    scs | success)
                        text_color=$'\033[32;1m'
                        ;;
                esac
                text_color_end=$'\033[0m'
            fi
        fi

        # print all the things
        printf "%s\n" "${@}" \
            | awk \
                -v timestamp="${timestamp}" \
                -v line_loc="${line_loc}" \
                -v log_level="${debug_level}" \
                -v text_color="${text_color}" \
                -v text_color_end="${text_color_end}" \
                '{
                    # TODO: determine if we want log_level included
                    # This print statement prints the log level
                    printf("%s %s -- [%02d] %s%s%s\n",
                           timestamp, line_loc, log_level,
                           text_color, $0, text_color_end);

                    # TODO: determine if we want log_level included
                    # This print statement does not print the log level
                    # printf("%s %s -- %s%s%s\n",
                    #        timestamp, line_loc,
                    #        text_color, $0, text_color_end);

                }' \
            >&3
            # >>"${debug_file}"
            # | dd of="${debug_file}" conv=notrunc oflag=append status=none
            # ^^^ this is a hack to avoid redirect errors where `debug` consumes
            # and obliterates the output of the command it is called from
    else
        return 1
    fi
)

# @description Print a string with non-printable characters escaped
# @usage print-escaped <string>
function print-escaped() (
    :  '
        Print a string with non-printable characters escaped

        This function takes a string as input and prints it to stdout with
        non-printable characters escaped. The escape sequences used are:
            - \a: alert (bell)
            - \b: backspace
            - \f: form feed
            - \n: newline
            - \r: carriage return
            - \t: horizontal tab
            - \v: vertical tab
            - \xHH: hexadecimal representation of the character

        @usage
            <string>

        @arg <string>
            The string to print with non-printable characters escaped

        @stdout
            The input string with non-printable characters escaped
        '
    local string="${1}"
    awk '
        BEGIN {
            # Create a character map for non-printable characters
            for (n=0; n<256; n++) ord[sprintf("%c",n)] = n;
        }
        function escape(c) {
            # Check for common escape characters
            if (c == "\a") return "\\a";
            if (c == "\b") return "\\b";
            if (c == "\f") return "\\f";
            if (c == "\n") return "\\n";
            if (c == "\r") return "\\r";
            if (c == "\t") return "\\t";
            if (c == "\v") return "\\v";
            return sprintf("\\x%02x", ord[c]);
        }
        NR > 1 { print escape("\n"); }
        {
            for (i = 1; i <= length; i++) {
                c = substr($0, i, 1);
                if (c ~ /[^[:print:]]/) {
                    printf escape(c);
                } else {
                    printf "%s", c;
                }
            }
        }
    ' <<< "${string}"
)

# @description Print the values of a list of variables given their names
# @usage debug-vars <var1> <var2> ...
# @example foo=bar bar=baz debug-vars "foo" "bar"
function debug-vars() {
    :  '
        Print the values of a list of variables given their names

        This function takes a list of variable names as input and prints the
        values of those variables to stdout. If a variable is an array, the
        entire array is printed. If a variable is a reference, the value of the
        reference is printed. If a variable is an associative array, the entire
        associative array is printed. If a variable is unset, "<unset>" is
        printed. If a variable is not found, "<not found>" is printed.

        @usage
            [-v/--verbosity <level>] <varname1> <varname2> ...

        @option -v/--verbosity <level>
            Control the verbosity of the output. 1: print only the value of the
            variable, 2: print the type of the variable and its length, 3: print
            the expanded type of the variable. Default: 1.

        @arg+
            The names of the variables to print
        
        @example
            foo=bar bar=baz debug-vars "foo" "bar"

        @stderr
            The names and values of the specified variable names
        '
    local verbosity=${DEBUG_VERBOSITY:-1}
    local var_names=()
    local var_char var_name var_type var_value var_length is_set
    local display_type display_value
    local debug_message declare_str
    declare -n __ref

    while [[ ${#} -gt 0 ]]; do
        # debug "processing argument: ${1}"
        case "${1}" in
            --*)
                case "${1}" in
                    --verbosity=*)
                        verbosity="${1#*=}"
                        ;;
                    --verbosity)
                        ((verbosity++))
                        shift
                        ;;
                    --)
                        shift
                        [[ ${#} -gt 0 ]] && var_names+=("${@}")
                        break
                        ;;
                    *)
                        debug "invalid option: ${1}"
                        return 1
                        ;;
                esac
                ;;
            -*)
                local short_opts="${1#-}" arg_char
                for ((i = 0; i < ${#short_opts}; i++)); do
                    arg_char="${short_opts:i:1}"
                    case "${arg_char}" in
                        $'\n') break ;;
                        v)
                            ((verbosity++))
                            ;;
                        *)
                            debug "invalid option: -${arg_char}"
                            return 1
                            ;;
                    esac
                done
                ;;
            *)
                var_names+=("${1}")
                ;;
        esac
        shift 1
    done

    debug_message=$(
        for var_name in "${var_names[@]}"; do
            # debug "processing variable: ${var_name}"
            var_length="" var_info="" display_value=""
            declare_str=$(declare -p "${var_name}" 2>/dev/null)
            # Determine if the variable is set
            [[ "${declare_str}" =~ "=" ]] && is_set=true || is_set=false
            if [[ -z "${declare_str}" ]]; then
                # debug "variable not found: ${var_name}"
                # echo -e "${var_name}\x1e== <not found>"
                display_value="<not found>"
            else
                declare_str="${declare_str#declare -}"
                var_type="${declare_str%% *}"
                if ! ${is_set}; then
                    display_value="<unset>"
                elif [[ "${var_type}" =~ [Aan] ]]; then
                    # debug "getting array value"
                    var_value=$(
                        awk '
                            NR == 1 {
                                gsub(/^[^=]+=/, "");
                                value=$0;
                            }
                            NR > 1 {
                                value=value "\n" $0;
                            }
                            END {
                                # Remove the first and last quote
                                print substr(value, 1, length(value));
                            }
                        ' <<< "${declare_str}"
                    )
                    display_value="${var_value}"
                    if [[ "${var_type}" =~ "n" ]]; then
                        # If it's a reference, remove the first and last quote
                        var_value="${var_value#\"}"
                        var_value="${var_value%\"}"
                        display_value="${var_value}"
                    elif [[ "${var_type}" == "A" ]]; then
                        # If it's an associative array, remove the buggy space
                        # before the last parenthesis
                        display_value="${display_value% )})"
                    fi
                else
                    # debug "getting value"
                    var_value="${!var_name}"
                    display_value=$(print-escaped "${var_value}")
                fi
                if ((verbosity > 1)); then
                    display_type="${var_type}"
                    if ${is_set}; then
                        if [[ "${var_type}" =~ [aA] ]]; then
                            var_length=${#__ref[@]}
                        else
                            var_length=${#var_value}
                        fi
                    fi
                    if ((verbosity > 2)); then
                        # Expand the var_type to a more human-readable form
                        local expanded_type="" var_char
                        # while read -r -N 1 var_char; do
                        for ((i = 0; i < ${#var_type}; i++)); do
                            var_char="${var_type:i:1}"
                            case "${var_char}" in
                                $'\n') break ;;
                                a) expanded_type+=",arr" ;;
                                A) expanded_type+=",map" ;;
                                i) expanded_type+=",int" ;;
                                l) expanded_type+=",lower" ;;
                                n) expanded_type+=",ref" ;;
                                r) expanded_type+=",ro" ;;
                                t) expanded_type+=",trace" ;;
                                u) expanded_type+=",upper" ;;
                                x) expanded_type+=",export" ;;
                                -) expanded_type+=",str" ;;
                                *) expanded_type+=",unknown" ;;
                            esac
                        done
                        display_type="${expanded_type#,}"
                    fi
                    var_info=" (${display_type}${var_length:+:${var_length}})"
                else
                    var_info=""
                fi
                if [[ "${var_type}" =~ "-" ]] && ${is_set}; then
                    if [[ "${display_value}" =~ "\\" ]]; then
                        display_value="\$'${display_value//\'/\'}'"
                    else
                        display_value="\"${display_value//\"/\\\"}\""
                    fi
                fi
            fi
            printf "\033[1m%s\033[0m%s\x1e== %s\n" \
                "${var_name}" "${var_info}" "${display_value}" \
                | sed '2,$s/^/ \x1e.. /'
        done | column -t -s $'\x1e'
    )
    DEBUG_FUNCTION_NAME="${FUNCNAME[1]}" \
    DEBUG_SCRIPT_NAME="${BASH_SOURCE[1]##*/}" \
    DEBUG_LINE_NUMBER="${BASH_LINENO[0]}" \
        debug "${debug_message}"
}

# print debug information, test version
function _debug() {
    local debug_file
    local debug_level
    local timestamp

    # if DEBUG and DEBUG_LOG are not set, return
    if [[ -z "${DEBUG}" && -z "${DEBUG_LOG}" ]]; then
        return
    fi

    # if DEBUG_LOG is set, then use that as the log file, else use /dev/stderr
    if [[ -n "${DEBUG_LOG}" ]]; then
        if [[ -z "${DEBUG}" ]]; then
            # if DEBUG is not set, default to 1
            DEBUG=1
        fi
        debug_file="${DEBUG_LOG}"
        # Point file descriptor 3 to the debug file
        exec 3>>"${DEBUG_LOG}"
    else
        # duplicate stderr to fd 3
        # debug_file="/dev/stderr"
        exec 3>&2
    fi

    # determine if the first arg is an integer
    if [[ "${1}" =~ ^[0-9]+$ ]]; then
        # if it is, then use it as this debug message's debug level
        debug_level=${1}
        shift
    else
        debug_level=1
    fi

    # print the debug message if:
    #   - DEBUG is set to "true", "all", or "*", or
    #   - DEBUG is set to an integer and >= the debug level, or
    #   - DEBUG_LOG is set (if DEBUG is not set, default to 1)
    if [[
        "${DEBUG}" =~ ^"true"|"all"|"*"$ \
        || ("${DEBUG}" =~ ^[0-9]+$ && "${DEBUG}" -ge ${debug_level})
    ]]; then
        timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
        printf "%s\n" "${@}" \
            | awk \
                -v timestamp="${timestamp}" \
                -v funcname="${FUNCNAME[1]}" \
                -v lineno="${BASH_LINENO[0]}" \
                'BEGIN {
                    if (funcname) {
                        funcname = funcname "()";
                    }
                }
                {
                    print "\033[36m" "[" timestamp "]" "\033[0m " \
                        "\033[35;1m" funcname "\033[0m" \
                        "\033[32m:" lineno "\033[0m" \
                        " -- " $0;
                }' \
            >&3
            # | dd of="${debug_file}" conv=notrunc oflag=append status=none
        # for arg in "${@}"; do
        #     printf "\e[36m[%s]\e[0m \e[1;35m%s:%s\e[0m -- %s\n" \
        #         "${timestamp}" "${FUNCNAME[1]}" "${BASH_LINENO[0]}" "${arg}" \
        #         | dd of="${DEBUG_LOG:-/dev/stderr}" conv=notrunc oflag=append status=none
        # done
    fi
}

# @description Print debug information if $DEBUG or $DEBUG_LOG are set
# @usage _mini_debug <message>
function _mini_debug() {
    local prefix timestamp
    if [[ "${DEBUG}" == "1" || "${DEBUG}" == "true" || -n "${DEBUG_LOG}" ]]; then
        [[ -n "${DEBUG_LOG}" ]] && exec 3>>"${DEBUG_LOG}" || exec 3>&2
        timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
        prefix="\033[36m[${timestamp}]\033[0m "
        prefix+="\033[35m$(basename "${BASH_SOURCE[-1]}")"
        [[ "${FUNCNAME[1]}" != "main" ]] && prefix+="\033[1m:${FUNCNAME[1]}()\033[0m"
        prefix+="\033[32m:${BASH_LINENO[0]}\033[0m -- "
        printf "%s\n" "${@}" \
            | awk -v prefix="${prefix}" '{print prefix $0}' \
            >&3
            # | dd of="${DEBUG_LOG:-/dev/stderr}" conv=notrunc oflag=append status=none
    fi
}

# Temporarily turn on xtrace and run the given command
function run-verbose() {
    set -x
    "${@}"
    set +x
}
