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
        run-available-function music song.mp3
'

include-source 'debug'
include-source 'exit-codes'

function run-available() {
    :  "Run the first available function given a category

        Given a category, search for all functions that match and run the first
        whose name matches a command available on the system. Functions should
        follow the format 'ra_<category>_[<priority>_]<name>'. For example, if
        the category is 'music', the functions should be named
        'ra_music_<command>'. When the function runs, it will find all available
        functions starting with the 'ra_music_' prefix, extract the command
        name, and check if that command is available on the system. If it is,
        the function will be run. Functions can optionally include a priority
        to determine the order in which they are checked. The priority should be
        an integer followed by an underscore, e.g. 'ra_music_10_play' will be
        checked before 'ra_music_20_pause'. Whether a priority is given or not,
        the functions will be checked in alphabetical order.

        If a function returns ${E_CONTINUE}, the next function will be checked.
        If no functions are found for the category, the function will return
        ${E_FUNCTION_NOT_FOUND}. If no commands are found for the functions, the
        function will return ${E_COMMAND_NOT_FOUND}.

        @usage
            <category> [options]

        @optarg options
            Any options to pass to the function

        @arg <category>
            The category of functions to search for

        @stdout
            The output of the function that was run

        @return ${E_FUNCTION_NOT_FOUND}
            If no functions are found for the category

        @return ${E_COMMAND_NOT_FOUND}
            If no commands are found for the functions

        @return
            The return code of the function that was run
        "
    local category="${1}"
    local options=( "${@:2}" )
    local prefix functions=() function_name command
    local -i exit_code

    # Set up a trap to return an error on ^C
    trap "return 1" INT

    # Set the prefix
    prefix="ra_${category}_"
    debug "searching for functions with prefix: ${prefix}"

    # Find all available functions for the category
    readarray -t functions < <(compgen -A function | grep "^${prefix}")

    # Check if any functions were found
    if [[ ${#functions[@]} -eq 0 ]]; then
        echo "error: no functions found for category: ${category}" >&2
        return "${E_FUNCTION_NOT_FOUND}"
    fi

    # Loop over the functions
    for function_name in "${functions[@]}"; do
        # Extract the command name
        command="${function_name#"${prefix}"}"
        if [[ "${command}" =~ ^[0-9]+_ ]]; then
            command="${command#*_}"
        fi
        debug "  => checking for command: ${command}"

        # Check if the command is available
        if command -v "${command}" &>/dev/null; then
            # Run the function
            debug "  => running function: ${function_name} ${options[*]}"
            ${function_name} "${options[@]}"
            exit_code=${?}
            debug "  => function returned: ${exit_code} (E_CONTINUE=${E_CONTINUE})"
            if ((exit_code == E_CONTINUE)); then
                continue
            fi
            return ${exit_code}
        fi
    done

    echo "error: no commands found for functions" >&2
    return "${E_COMMAND_NOT_FOUND}"
}

ra_set-volume_amixer() {
    local volume="${1}"

    # Set the volume using amixer
    amixer -q set Master "${volume}%"
}

ra_set-volume_pactl() {
    local volume="${1}"
    local sink

    # Set the volume using pactl
    ## find the default sink
    sink=$(pactl info | awk '/Default Sink:/ {print $3}')
    ## set the volume
    pactl set-sink-volume "${sink}" "${volume}%"
}

ra_set-volume_osascript() {
    local volume="${1}"

    # Set the volume using osascript
    osascript -e "set volume output volume ${volume}"
}

ra_get-volume_amixer() {
    # Get the volume using amixer
    amixer get Master | awk -F'[][]' '/%/ {gsub(/%/, ""); print $2; exit}'
}

ra_get-volume_pactl() {
    echo "warning: pactl not implemented" >&2
    return "${E_CONTINUE}"
}

ra_get-volume_osascript() {
    # Get the volume using osascript
    osascript -e 'output volume of (get volume settings)'
}

ra_audio-player_mpv() {
    local alarm="${1}"
    local -i volume="${2:-100}"

    # Play the file using mpv, silencing all output except the status line
    mpv --volume="${volume}" --msg-level=all=no,statusline=v -- "${alarm}" \
        || return ${?}
    echo  # add a newline after the status line
}

ra_audio-player_mplayer() {
    local alarm="${1}"
    local -i volume="${2:-100}"

    # Play the file using mplayer
    mplayer -volume "${volume}" -really-quiet -- "${alarm}"
}

ra_audio-player_vlc() {
    local alarm="${1}"

    # Play the file using vlc
    vlc --intf dummy --play-and-exit -- "${alarm}"

}

ra_audio-player_powerplay() {
    local alarm="${1}"

    # Play the file using powerplay
    powerplay "${alarm}"
}

ra_audio-player_aplay() {
    local alarm="${1}"

    # Validate that the alarm is a wav file
    if [[ "${alarm}" != *.wav ]]; then
        debug "error: aplay only supports wav files, returning ${E_CONTINUE}"
        return "${E_CONTINUE}"
    fi

    # Play the file using aplay
    aplay "${alarm}"
}

ra_failsafe-audio_speaker-test() {
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

ra_failsafe-audio_osaudio() {
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

ra_failsafe-audio_aplay() {
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
