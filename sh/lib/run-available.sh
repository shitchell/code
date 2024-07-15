: '
    Run available functions. This script provides a function to run the first
    available function given a category as well as functions for several
    categories.

    The functions should follow the format "ra_<category>_[<priority>_]<name>".
    For example, if the category is "music", the functions should be named
    "ra_music_<command>". When the function runs, it will find all available
    functions starting with the "ra_music_" prefix, extract the command name,
    and check if that command is available on the system. If it is, the function
    will be run. Functions can optionally include a priority to determine the
    order in which they are checked. The priority should be an integer followed
    by an underscore, e.g. "ra_music_10_mplayer" will be checked before
    "ra_music_20_vlc". Whether a priority is given or not, the functions will be
    checked in alphabetical order.

    Example:
        # Define functions for the "music" category
        ra_music_10_mplayer() {
            mplayer --volume=50 "$@"
        }
        ra_music_20_vlc() {
            vlc "$@"
        }
        ra_music_30_mpv() {
            mpv --volume=50 "$@"
        }

        # Run the function
        run-available music song.mp3
'

include-source 'debug'
include-source 'exit-codes'

# Ensure exit codes are set
export E_CONTINUE="${E_CONTINUE:-127}"
export E_FUNCTION_NOT_FOUND="${E_FUNCTION_NOT_FOUND:-128}"
export E_COMMAND_NOT_FOUND="${E_COMMAND_NOT_FOUND:-129}"

function run-available() {
    :  "Run the first available function given a category

        Given a category, search for all functions, commands, or aliases
        (runnables) available. Names should follow the format
        'ra_<category>_[<priority>_]<command>'. For example, if the category is
        'music', the runnable should be named 'ra_music_<command>'. When this
        function is run, it will find all available runnables starting with the
        'ra_music_' prefix, extract the command name, and check if that command
        is available on the system. If it is, the function will be run.

        Runnable names can optionally include a priority to determine the order
        in which they are checked. The priority should be an integer followed by
        an underscore, e.g. 'ra_music_10_mpv' will be checked before
        'ra_music_20_mplayer'. Whether a priority is given or not, the functions
        will be checked in alphabetical order.

        The list of runnables can be filtered using the '--exclude' option. This
        option takes a glob pattern to exclude from the list of available
        runnables, e.g. '--exclude ra_music_mp*' would exclude
        'ra_music_mplayer' and 'ra_music_mpv'.

        The list of available runnables can be optionally built from aliases,
        functions, or commands using the '--(no-)aliases', '--(no-)functions',
        and '--(no-)commands' options. By default, commands are excluded for
        performance reasons (i.e.: --functions --aliases --no-commands).

        If a runnable returns ${E_CONTINUE}, the next runnable will be checked.
        If no runnables are found for the category, this function will return
        ${E_FUNCTION_NOT_FOUND}. If no commands are found for the functions, the
        function will return ${E_COMMAND_NOT_FOUND}.

        @usage
            [--(no-)functions] [--(no-)commands] [--(no-)aliases]
            [--(no-)continue] [--continue-on-error]
            [--exclude <command>] [--list]
            <category> [--] [options]

        @option --functions
            Include functions in the list of available commands

        @option --no-functions
            Exclude functions from the list of available commands

        @option --commands
            Include commands in the list of available commands

        @option --no-commands
            Exclude commands from the list of available commands

        @option --aliases
            Include aliases in the list of available commands

        @option --no-aliases
            Exclude aliases from the list of available commands

        @option --continue
            Continue to the next runnable if a runnable returns ${E_CONTINUE}

        @option --continue-on-error
            Continue to the next runnable if a runnable returns a non-zero exit
            code

        @option --no-continue
            Never continue to the next runnable based on exit code

        @option --exclude <command>
            A glob pattern to exclude from the list of available commands, e.g.:
            'ra_music_mp*' would exclude 'ra_music_mplayer' and 'ra_music_mpv'

        @option --list
            List all available functions for the category

        @arg <category>
            The category of functions to search for

        @optarg --
            All arguments after this will be passed to the function

        @optarg options
            Any options to pass to the function

        @stdout
            The output of the function that was run

        @return ${E_FUNCTION_NOT_FOUND}
            If no functions are found for the category

        @return ${E_COMMAND_NOT_FOUND}
            If functions are found, but their commands are not in the PATH

        @return
            The return code of the function that was run
    "
    # Default values
    local category=""
    local options=()
    local do_list=false
    local do_functions=true do_commands=false do_aliases=true
    local do_continue=true
    local do_continue_on_error=false
    local compgen_args=()
    local exclude=()
    local prefix candidates=() runnables=()
    local runnable_category runnable_name runnable_priority runnable_command
    local -i exit_code

    # Parse the arguments
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            --functions)
                do_functions=true
                ;;
            --no-functions)
                do_functions=false
                ;;
            --commands)
                do_commands=true
                ;;
            --no-commands)
                do_commands=false
                ;;
            --aliases)
                do_aliases=true
                ;;
            --no-aliases)
                do_aliases=false
                ;;
            --continue)
                do_continue=true
                ;;
            --continue-on-error)
                do_continue=true
                do_continue_on_error=true
                ;;
            --no-continue)
                do_continue=false
                do_continue_on_error=false
                ;;
            --exclude)
                exclude+=( "${2}" )
                shift 1
                ;;
            --list)
                do_list=true
                ;;
            --)
                # All arguments after this will be passed to the function
                options+=( "${@:2}" )
                break
                ;;
            *)
                # Set the category or options
                if [[ -z "${category}" ]]; then
                    category="${1}"
                else
                    options+=( "${1}" )
                fi
                ;;
        esac
        shift
    done

    debug-vars category options do_list do_functions do_commands do_aliases \
        exclude

    # Require a category if we're not listing functions
    if ! ${do_list}; then
        if [[ -z "${category}" ]]; then
            echo "error: category is required" >&2
            return "${E_MISSING_ARGUMENT}"
        fi
    fi

    # Set up a trap to return an error on ^C
    trap "return 1" INT

    # Set the prefix
    prefix="ra_"
    [[ -n "${category}" ]] && prefix+="${category}_"
    debug "searching for runnables..."

    # Find all available functions for the category
    ${do_functions} && compgen_args+=( -A function )
    ${do_commands} && compgen_args+=( -c )
    ${do_aliases} && compgen_args+=( -a )
    debug-vars compgen_args prefix
    readarray -t runnables < <(
        compgen "${compgen_args[@]}" | grep "^${prefix}" | sort -u
    )
    debug-vars runnables

    # Check if any functions were found
    if [[ ${#runnables[@]} -eq 0 ]]; then
        echo "error: no runnable found for category: ${category}" >&2
        return "${E_FUNCTION_NOT_FOUND}"
    fi

    # Collect the candidate runnables -- not excluded and commands in $PATH
    for runnable_name in "${runnables[@]}"; do
        debug "checking runnable: ${runnable_name}"
        # Extract the runnable details
        if [[ "${runnable_name}" =~ ^ra_([^_]+)_([0-9]+_)?(.+)$ ]]; then
            runnable_category="${BASH_REMATCH[1]}"
            runnable_priority="${BASH_REMATCH[2]}"
            runnable_command="${BASH_REMATCH[3]}"
        else
            continue
        fi
        debug "  => category: ${runnable_category}"
        debug "  => priority: ${runnable_priority}"
        debug "  => command: ${runnable_command}"

        # Check if the command is excluded
        for exclude_pattern in "${exclude[@]}"; do
            if [[ "${runnable_command}" == ${exclude_pattern} ]]; then
                debug "  => excluding command: ${runnable_command}"
                continue 2
            fi
        done

        # Check if the command is available
        if command -v "${runnable_command}" &>/dev/null; then
            debug "  => found command: ${runnable_command}"
            candidates+=( "${runnable_name}" )
        else
            debug "  => command not found: ${runnable_command}"
        fi
    done

    # Check if any candidates were found
    if [[ ${#candidates[@]} -eq 0 ]]; then
        echo "error: no candidate runnables found" >&2
        return "${E_COMMAND_NOT_FOUND}"
    fi

    debug-vars candidates

    # If listing, print the candidates and return
    if ${do_list}; then
        printf "%s\n" "${candidates[@]}"
        return
    fi

    # Loop over the candidates and run them until one returns a non-E_CONTINUE
    for runnable_name in "${candidates[@]}"; do
        debug "running function: ${runnable_name}"
        "${runnable_name}" "${options[@]}"
        exit_code=$?

        # Determine if we should continue based on the exit code
        if ${do_continue} || ${do_continue_on_error}; then
            if [[ ${exit_code} -eq ${E_CONTINUE} ]]; then
                debug "continuing based on exit code: ${exit_code}"
                continue
            elif ${do_continue_on_error} && [[ ${exit_code} -ne 0 ]]; then
                debug "continuing based on exit code: ${exit_code}"
                echo "continuing to next runnable..."
                continue
            fi
        else
            # If we're not continuing, return the exit code
            return ${exit_code}
        fi
    done
}

function ra_set-volume_amixer() {
    local volume="${1}"

    # Set the volume using amixer
    amixer -q set Master "${volume}%"
}

function ra_set-volume_pactl() {
    local volume="${1}"
    local sink

    # Set the volume using pactl
    ## find the default sink
    sink=$(pactl info | awk '/Default Sink:/ {print $3}')
    ## set the volume
    pactl set-sink-volume "${sink}" "${volume}%"
}

function ra_set-volume_osascript() {
    local volume="${1}"

    # Set the volume using osascript
    osascript -e "set volume output volume ${volume}"
}

function ra_get-volume_amixer() {
    # Get the volume using amixer
    amixer get Master | awk -F'[][]' '/%/ {gsub(/%/, ""); print $2; exit}'
}

function ra_get-volume_pactl() {
    echo "warning: pactl not implemented" >&2
    return "${E_CONTINUE}"
}

function ra_get-volume_osascript() {
    # Get the volume using osascript
    osascript -e 'output volume of (get volume settings)'
}

function ra_audio-player_mpv() {
    local alarm="${1}"
    local -i volume="${2:-100}"

    # Play the file using mpv, silencing all output except the status line
    mpv --volume="${volume}" --msg-level=all=no,statusline=v -- "${alarm}" \
        || return ${?}
    echo  # add a newline after the status line
}

function ra_audio-player_mplayer() {
    local alarm="${1}"
    local -i volume="${2:-100}"

    # Play the file using mplayer
    mplayer -volume "${volume}" -really-quiet -- "${alarm}"
}

function ra_audio-player_vlc() {
    local alarm="${1}"

    # Play the file using vlc
    vlc --intf dummy --play-and-exit -- "${alarm}"

}

function ra_audio-player_powerplay() {
    local alarm="${1}"

    # Only run in a windows bash environment with `psrun` available
    ( __check_windows_bash && __check_psrun ) || return "${E_CONTINUE}"

    # Play the file using powerplay
    powerplay "${alarm}"
}

function ra_audio-player_aplay() {
    local alarm="${1}"

    # Validate that the alarm is a wav file
    if [[ "${alarm}" != *.wav ]]; then
        debug "error: aplay only supports wav files, returning ${E_CONTINUE}"
        return "${E_CONTINUE}"
    fi

    # Play the file using aplay
    aplay "${alarm}"
}

function ra_failsafe-audio_speaker-test() {
    local pid
    local -i duration="${1:-10}"
    speaker-test -t sine -f 1000 -l 1 &
    pid=$!

    # Set up a trap to kill the process in case of ^C
    trap "kill -9 ${pid} 2>/dev/null" INT

    # Wait for the specified duration
    sleep "${duration}"

    # Kill the speaker-test process
    kill -9 "${pid}" 2>/dev/null
}

function ra_failsafe-audio_osaudio() {
    local pid
    local -i duration="${1:-10}"
    while :; do osascript -e "beep"; sleep 0.5; done &
    pid=$!

    # Set up a trap to kill the process in case of ^C
    trap "kill -9 ${pid} 2>/dev/null" INT

    # Wait for the specified duration
    sleep "${duration}"

    # Kill the speaker-test process
    kill -9 "${pid}" 2>/dev/null
}

function ra_failsafe-audio_aplay() {
    local pid wav_file wav_files
    local -i duration="${1:-10}"

    # Check that a wav file is available
    shopt -s nullglob
    wav_files=( /usr/share/sounds/alsa/*.wav )
    if [[ ${#wav_files[@]} -eq 0 ]]; then
        debug "error: no wav files found, returning ${E_CONTINUE}"
        return "${E_CONTINUE}"
    fi
    wav_file="${wav_files[RANDOM % ${#wav_files[@]}]}"

    while :; do aplay "${wav_file}"; done &
    pid=$!

    # Set up a trap to kill the process in case of ^C
    trap "kill -9 ${pid} 2>/dev/null" INT

    # Wait for the specified duration
    sleep "${duration}"

    # Kill the speaker-test process
    kill -9 "${pid}" 2>/dev/null
}

# Check if the environment is WSL, Git Bash, or both
function __check_git_bash() {
    local uname=$(uname -a)
    [[ "${uname}" == MINGW* ]] && return 0
}
function __check_wsl() {
    local uname=$(uname -a)
    [[ "${uname}" == *[Mm]icrosoft* ]] && return 0
}
function __check_windows_bash() {
    __check_git_bash || __check_wsl
}
function __check_psrun() {
    command -v psrun &>/dev/null
}
