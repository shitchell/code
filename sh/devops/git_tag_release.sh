#!/bin/bash
#
# @author	shaun.mitchell@trinoor.com
# @date		2022-07-29
#
# This must be run in a repository.
#
# This script tags a commit with a patch tag. It finds the last patch for the
# passed in major.minor version and increments it by 1. If not commit hash is
# specified, the most recent commit is used. It is designed to work with branch
# names such as 'release/v0.1' by removing anything in the passed in version up
# to and including the last slash.

RELEASE_MAJOR_MINOR="${1}"
COMMIT_HASH="${2}" # optional

# Set the environment variable DEBUG to 1 to enable debug messages
function debug() {
	if [ "${DEBUG}" = 1 ]; then
		while IFS= read -r line; do
			echo "`date +'[%y-%m-%d %H:%M:%S]'` $line" | tee -a /tmp/bash_debug.log >&2
		done <<< "${@}"
	fi
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
		echo "Done"
	else
		echo -e "\033[31mError\033[0m"
	fi
	if [ -n "${output_var}" ]; then
		read -r -d '' ${output_var} << END_OF_COMMAND_OUTPUT
${output}
END_OF_COMMAND_OUTPUT
	fi
	return ${exit_code}
}

# Get the tag list in descending order
function get_tag_list() {
	tag_list=$(git tag -l | sort -rn)
	echo "${tag_list}"
	debug "tag_list:"
	debug "${tag_list}"
}

# Get the most recent tag, optionally for a specific release
function get_last_patch_number() {
    release_version="${1}"
	debug "[get_last] using release_version '${release_version}'"
    patch_list="$(get_tag_list)"
    
    if [ -n "${release_version}" ]; then
    	# Filter only tags for the specified release
	    patch_list=$(
	    	echo "${patch_list}" \
	    	| grep -oP "^${release_version}(\.\d+)+"
	    )
	fi
	
	# Return the first, formatted tag from the list
	echo "${patch_list}" | head -1 | sed 's/.*\.//'
}

# Get the next patch number, optionally for a specific release
function get_next_patch_number() {
	release_version="${1}"
	debug "[get_next] using release_version '${release_version}'"
	last_patch_number=$(get_last_patch_number "${release_version}")
	# If no previous patch number is found, use 0
	if [ -z "${last_patch_number}" ]; then
		echo 0
	else
		echo $((last_patch_number + 1))
	fi
	
}

# Build the next full major.minor.patch tag, optionally for a specific release
function get_next_tag() {
	release_version="${1}"
	debug "[get_next_tag] using branch_name: '${release_version}'"
	# Remove anything up to and including a / for use with branch names
	release_version=$(echo ${release_version} | sed 's_.*/__')
	# Get the next patch number
	next_patch_number=$(get_next_patch_number "${release_version}")
	# Form the tag name
	echo "${release_version}.${next_patch_number}"
}

# Tag the last or a specific commit for a specific release major.minor version
function tag_release_patch() {
	release_version="${1}"
	commit_hash="${2}"
	if [ -z "${last_commit_hash}" ]; then
		# Get the most recent commit that triggered this pipeline
		commit_hash=$(git log -1 --format="%h")
	fi
	# Form the tag name
	tag_name=$(get_next_tag "${release_version}")		
	# Make sure we're up to date to avoid conflicts. Force the prune and tag to
	# ensure that the remote tags are up-to-date with the local tags
	check-command "Updating tags from remote" \
		"git fetch --all --tags --prune" \
		|| exit 1
	check-command "Tagging commit '${commit_hash}' with tag '${tag_name}'" \
		"git tag '${tag_name}' ${commit_hash}" \
		|| exit 1
	check-command "Pushing tag to $(git remote)" \
		"git push $(git remote) '${tag_name}'" \
		git_push_output
	if [ $? -ne 0 ]; then
		echo "${git_push_output}"
		exit 1
	fi
}

function main() {
	# Make sure we're in a git repository
	if git status >/dev/null; then
		tag_release_patch "$@"
	fi
}

[ "${0}" = "${BASH_SOURCE[0]}" ] && main "${RELEASE_MAJOR_MINOR}" "${COMMIT_HASH}"
