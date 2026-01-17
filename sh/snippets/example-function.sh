function my-function() {
  : 'This is a brief help summary

     This is a more extensive help message with some
     extra details

     @usage
       [-h/--help] [-d/--delimeter <delimiter>] <some_arg> [<args> ...]

     @option -h/--help
       Show this help message and exit

     @option -d/--delimeter
       Use this string as a delimiter when concatenating arguments

     @arg some_arg
       An argument to pass

     @arg* args
       Other args to pass

     @stdout
       All args concatenated using the specified delimiter

     @return 1
       No arguments were passed or required argument missing
  '

  # Initialize local variables with the required syntax.
  local __args=()
  local __delimiter=""
  local __some_arg=""
  local __result=""

  # Check if no arguments were provided.
  if [[ "$#" -eq 0 ]]; then
    echo "Error: No arguments passed."
    return 1
  fi

  # Process each argument.
  while [[ "$#" -gt 0 ]]; do
    case "${1}" in
      -h|--help)
        echo "$0 - usage: [-h/--help] [-d/--delimeter <delimiter>] <some_arg> [<args> ...]"
        return 0
        ;;
      -d|--delimeter)
        shift
        if [[ -z "${1}" ]]; then
          echo "Error: Missing argument for -d/--delimeter option."
          return 1
        fi
        __delimiter="${1}"
        ;;
      *)
        if [[ -z "${__some_arg}" ]]; then
          __some_arg="${1}"
        else
          __args+=("${1}")
        fi
        ;;
    esac
    shift
  done

  # Check that the required <some_arg> was provided.
  if [[ -z "${__some_arg}" ]]; then
    echo "Error: Missing required argument <some_arg>."
    return 1
  fi

  # If additional args exist and no delimiter was specified, use a default space.
  if [[ -z "${__delimiter}" && ${#__args[@]} -gt 0 ]]; then
    __delimiter=" "
  fi

  # Concatenate the first argument and any additional arguments using the delimiter.
  __result="${__some_arg}"
  for __element in "${__args[@]}"; do
    __result+="${__delimiter}${__element}"
  done

  echo "${__result}"
}

