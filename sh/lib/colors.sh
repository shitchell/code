#!/usr/bin/env bash
:  '
Color variables using ANSI escape codes and functions to set them up.

Variables are set using ANSI-C escape sequences so that they can be used in any
context, including `echo` commands without needing to use the `-e` flag.

When the lib is sourced, it can optionally set up the color variables. The
options are:
- `--auto`: Set up colors only if stdout is a TTY
- `--setup-colors`: Always set up colors
- `--no-auto` or `--no-setup-colors`: Do not set up colors (but still load the
  functions)

The default is `--auto`.
'

# Determine if FD 1 (stdout) is a terminal (used for auto-loading)
[ -t 1 ] && __IS_TTY=true || __IS_TTY=false

function setup-colors() {
    export C_BLACK=$'\033[30m'
    export C_RED=$'\033[31m'
    export C_GREEN=$'\033[32m'
    export C_YELLOW=$'\033[33m'
    export C_BLUE=$'\033[34m'
    export C_MAGENTA=$'\033[35m'
    export C_CYAN=$'\033[36m'
    export C_WHITE=$'\033[37m'
    export C_RGB=$'\033[38;2;%d;%d;%dm'
    export C_DEFAULT_FG=$'\033[39m'
    export C_BLACK_BG=$'\033[40m'
    export C_RED_BG=$'\033[41m'
    export C_GREEN_BG=$'\033[42m'
    export C_YELLOW_BG=$'\033[43m'
    export C_BLUE_BG=$'\033[44m'
    export C_MAGENTA_BG=$'\033[45m'
    export C_CYAN_BG=$'\033[46m'
    export C_WHITE_BG=$'\033[47m'
    export C_RGB_BG=$'\033[48;2;%d;%d;%dm'
    export C_DEFAULT_BG=$'\033[49m'
    export S_RESET=$'\033[0m'
    export S_BOLD=$'\033[1m'
    export S_DIM=$'\033[2m'
    export S_ITALIC=$'\033[3m'  # not widely supported, is sometimes "inverse"
    export S_UNDERLINE=$'\033[4m'
    export S_BLINK=$'\033[5m'  # slow blink
    export S_BLINK_FAST=$'\033[6m'  # fast blink
    export S_REVERSE=$'\033[7m'
    export S_HIDDEN=$'\033[8m'  # not widely supported
    export S_STRIKETHROUGH=$'\033[9m'  # not widely supported
    export S_DEFAULT=$'\033[10m'
}

function unset-colors() {
    unset \
        C_BLACK C_RED C_GREEN C_YELLOW C_BLUE C_MAGENTA C_CYAN C_WHITE \
        C_RGB C_DEFAULT_FG C_BLACK_BG C_RED_BG C_GREEN_BG C_YELLOW_BG \
        C_BLUE_BG C_MAGENTA_BG C_CYAN_BG C_WHITE_BG C_RGB_BG C_DEFAULT_BG \
        S_RESET S_BOLD S_DIM S_ITALIC S_UNDERLINE S_BLINK S_BLINK_FAST \
        S_REVERSE S_HIDDEN S_STRIKETHROUGH S_DEFAULT
}


## run on source ###############################################################

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # When sourcing the script, allow some options to be passed in
    __load_colors="auto" # "auto", "true", "always", "yes", "false", "never", "no"

    # Parse the arguments
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            --auto)
                __load_colors=auto
                ;;
            --setup-colors)
                __load_colors=true
                ;;
            --no-auto | --no-setup-colors)
                __load_colors=false
                ;;
            *)
                echo "$(basename "${BASH_SOURCE[0]}"): unknown option: ${1}" >&2
                return 1
                ;;
        esac
        shift 1
    done

    # Set up the colors
    case "${__load_colors}" in
        auto)
            # In the default "auto" mode, only set up colors if stdout is a TTY
            if ${__IS_TTY}; then
                setup-colors
            fi
            ;;
        true | always | yes)
            setup-colors
            ;;
        false | never | no)
            unset-colors
            ;;
    esac

    ## Export Functions ########################################################
    ############################################################################

    export -f setup-colors
    export -f unset-colors
fi
