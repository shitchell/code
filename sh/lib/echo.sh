# colored output
GREEN="\033[32m"
RED="\033[31m"
BLUE="\033[34m"
PURPLE="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

# echo a command before running it, printing an error message if it exited with
# a non-zero status
echo-run() {
	command="$@"
	echo-command "${command}"
	"$@"
	exit_code="$?"

	if [ $exit_code -ne 0 ]; then
		echo-error "command exited with status ${exit_code}"
	fi
	return $exit_code
}

# echo something to stdout in cyan
echo-comment() {
	echo -e "${CYAN}${@}${RESET}"
}

# echo something to stdout in green
echo-command() {
	echo -e "\$ ${GREEN}${@}${RESET}"
}

# echo something to stdout in red
echo-error() {
	echo -e "${RED}${@}${RESET}"
}

# echo something to stderr in red
echo-stderr() {
	echo -e "${RED}${@}${RESET}" >&2
}

# echo something to stdout in blue
echo-success() {
	echo -e "${BLUE}${@}${RESET}"
}

# usage: check-command message command output_var
# Prints "${message} ... ", runs ${command}, prints "Done" or "Error" based on
# the exit code of the command. Stores the output ${command} in ${output_var}
check-command() {
	message="${1}"
	command="${2}"
	output_var="${3}"
	echo -n "${message} ... "
	output="$(eval ${command} 2>&1)"
	exit_code="$?"
	if [ ${exit_code} -eq 0 ]; then
		echo-success "Done"
	else
		echo-error "Error"
	fi
	# escape any quotes in the output...
	read -r -d '' ${output_var} << END_OF_COMMAND_OUTPUT
${output}
END_OF_COMMAND_OUTPUT
	return ${exit_code}
}
