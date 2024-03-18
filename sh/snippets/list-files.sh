#!/usr/bin/env bash
#
# List all files in a directory

include-source 'debug.sh'
include-source 'echo.sh'

# Default options
DIRECTORY="${PWD}"
DO_PRINT_STDOUT=true

# Parse the options
while [[ $# -gt 0 ]]; do
	case "${1}" in
		-h|--help)
			echo "Usage: $(basename "${0}") [DIRECTORY]"
			echo "List all files in a directory"
			echo
			echo "Options:"
			echo "  -h, --help  Display this help message"
			exit 0
			;;
		-s | --silent)
			DO_PRINT_STDOUT=false
			;;
		-v | --verbose)
			DO_PRINT_STDOUT=true
			;;
		-*)
			echo "error: invalid option: ${1}" >&2
			exit 1
			;;
		*)
			DIRECTORY=$(realpath "${1:-${PWD}}" 2>/dev/null)
			;;
	esac
	shift
done

if ! [[ -d "${DIRECTORY}" ]]; then
    echo "error: invalid directory: ${DIRECTORY}" >&2
    exit 1
fi

# Set up a function for logging
function always_log_sometimes_print() {
	local data="${1}"
	local log_file="${2}"

	# If $data is "-", read from stdin
	if [[ "${data}" == "-" ]]; then
		data=$(cat)
	fi

	# Always log the message
	echo "${data}" >> "${log_file}"

	# Print the message if the option is set
	${DO_PRINT_STDOUT} && echo "${data}"
}

# Using bashisms
function _list_files_bash_globstar_nohidden() {
	local directory="${1:-${DIRECTORY}}"
	local files=()

	shopt -s globstar
	for f in "${directory}/"**/**; do
		[[ -f "${f}" ]] && files+=( "${f}" )
	done

	printf '%s\n' "${files[@]}"
}

function _list_files_bash_globstar_all() {
	local directory="${1:-${DIRECTORY}}"
	declare -A files

	shopt -s globstar
	for f in \
		"${directory}/"**/** \
		"${directory}"/**/.** \
	; do
		debug "f: ${f}"
		[[ "${f}" == *"/.." || "${f}" == *"/." ]] && continue
		[[ -f "${f}" ]] && files["${f}"]=1
	done

	printf '%s\n' "${!files[@]}"
}

function _list_files_bash_recursive_walk() {
	local directory="${1:-${DIRECTORY}}"
	local files=()

	recursive_walk() {
		local dir="${1}"
		for f in "${dir}"/* "${dir}"/.*; do
			# Skip the current and parent directories
			[[ "${f}" == "${dir}/." || "${f}" == "${dir}/.." ]] && continue

			if [[ -d "${f}" ]]; then
				# If it's a directory, call the function recursively
				debug "descending into ${f}"
				recursive_walk "${f}"
			elif [[ -f "${f}" ]]; then
				# If it's a file, add it to the list
				files+=( "${f}" )
			fi
		done
	}

	recursive_walk "${DIRECTORY}"
	printf '%s\n' "${files[@]}"
}

# Using find
function _list_files_find() {
	local directory="${1:-${DIRECTORY}}"
	find -L "${directory}" -type f
}

# If a temporary log directory does not exist, create it
LOG_DIR="/tmp/list-files"
[[ -d "${LOG_DIR}" ]] || mkdir -p "${LOG_DIR}"
# Purge it
rm -f "${LOG_DIR}"/*

# Run the tests
is_first=true
tests=(
	# _list_files_bash_globstar
	# _list_files_bash_recursive_walk
	_list_files_bash_globstar_nohidden
	_list_files_bash_globstar_all
	_list_files_find
)
for function in "${tests[@]}"; do
	${is_first} && is_first=false || echo
	echo-formatted -n "##" -B "Testing" -- -g "${function}" -- "..."
	${DO_PRINT_STDOUT} && echo
	time "${function}" "${DIRECTORY}" \
		| sort \
		| always_log_sometimes_print - "${LOG_DIR}/${function}.log"
done
