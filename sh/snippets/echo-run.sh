# colored output
GREEN="\033[32m"
RED="\033[31m"
BLUE="\033[34m"
PURPLE="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

# echo a command before running it
echo-run() {
	command="$@"
	echo -e "${GREEN}${command}${RESET}"
	"$@"
	exit_code="$?"

	if [ $exit_code -ne 0 ]; then
		echo -e "${RED}command exited with status ${exit_code}${RESET}"
	fi
	return $exit_code
}

# echo something in cyan
echo-comment() {
	echo -e "${CYAN}${@}${RESET}"
}

echo-error() {
	echo -e "${RED}${@}${RESET}" >&2
}

echo-success() {
	echo -e "${BLUE}${@}${RESET}"
}

# usage: check-command message command output_var
# Prints "${message} ... ", runs ${command}, prints "Done" or "Error" based on
# the exit code of the command. Stores the output ${command} in ${output_var}
# 
check-command() {
	
}
