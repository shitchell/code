include-source 'debug.sh'
include-source 'echo.sh'
include-source 'git.sh'
include-source 'text.sh'

# Patterns for customizations
export OPG_AS_CUSTOMIZATION_PATTERN="AS9-CUS[A-Z]*-[A-Z]{,5}-[0-9]{4}|INC[0-9]{12}"

# Generates a customization pattern that matches common mistakes
function generate-customization-pattern {
	local cust_name="$1"

	# Normalize the name
	cust_name=$(get_cust_name "${cust_name}")

	# Get each piece of the name
	cust_desg=$(echo "${cust_name}" | cut -d '-' -f 2)
	cust_type=$(echo "${cust_name}" | cut -d '-' -f 3)
	cust_nmbr=$(echo "${cust_name}" | cut -d '-' -f 4)

	# Generate a pattern that matches the customization name
	# Zeroes seem to be optional oftentimes
	cust_nmbr=${cust_nmbr//0/0?}
	cust_pattern="AS9?[_-](${cust_desg}?[_-]${cust_type}|${cust_type}[_-]${cust_desg})[_-]${cust_nmbr}\b|${cust_desg}[_-]AS9?[_-]${cust_type}[_-]${cust_nmbr}\b"

	# Replace each alphabetical character with a [Aa] pattern to match either upper or lower case
	cust_pattern=$(case-insensitive-pattern "${cust_pattern}")

	echo "${cust_pattern}"
}

function grep-cust-names() {
	debug "${@@Q}"
	grep --color=never -oiE "${OPG_AS_CUSTOMIZATION_PATTERN}"
}

# Normalizes customization names accounting for common mistakes
function normalize-cust-name() {
	debug "${@@Q}"

	# Receive the branch name as an argument
	derived_branch="$1"

	# Handle instances where there is a branch type prefix, eg "bugfix/AS9-CUS-FI-0033-G"
	derived_branch_base=$(echo "$(basename ${derived_branch})")
	if [ "${derived_branch}" != "${derived_branch_base}" ]; then
		derived_branch="${derived_branch_base}"
	fi

	# Handle instances where the branch name begins with "AS-" instead of "AS9-"
	if [ $(expr match "${derived_branch}" 'AS[-_]') != 0 ]; then
		#if [[ "${derived_branch}" =~ ^AS[-_] ]]; then
		derived_branch=$(echo "${derived_branch}" | sed -E 's/^AS[-_]/AS9-/')
	fi

	# Handle instances where the customisation designation and the customisation type are switched, eg "AS9-FI-CUS-0033"
	# Also, replace any underscores in the customisation name with hyphens, eg "AS9-FI_CUS_0033"
	if [ $(expr match "${derived_branch}" 'AS9-[A-Z]\{2,\}[-_]CUS') != 0 ]; then
		#if [[ "${derived_branch}" =~ ^AS9-[A-Z]{2,}[-_]CUS ]]; then
		cust_desg=$(echo "${derived_branch}" | sed 's/AS9-//')
		cust_type=$(echo "${cust_desg}" | sed 's/[-_]CUS.*//')
		cust_desg=$(echo "${cust_desg}" | sed "s/${cust_type}[-_]//" | sed 's/[-_].*//')
		cust_idnt=$(echo "${derived_branch}" | sed "s/AS9-${cust_type}[-_]${cust_desg}[-_]//")
		derived_branch="AS9-${cust_desg}-${cust_type}-${cust_idnt}"
	fi

	# Handle instances where the numeric suffix has more or less digits than 4, eg "AS9-CUS-AR-0002-2"
	if [ $(expr match "${derived_branch}" 'AS9-CUS[A-Z]*-[A-Z]\{2,\}-[0-9]\+') != 0 ]; then
		#if [[ "${derived_branch}" =~ ^AS9-CUS[A-Z]*-[A-Z]{2,}-[0-9]+ && ! "${derived_branch}" =~ ^AS9-CUS[A-Z]*-[A-Z]{2,}-[0-9]{4} ]]; then
		cust_main=$(echo "${derived_branch}" | grep -Eo "^AS9-CUS[A-Z]*-[A-Z]{2,}-")
		main_len=${#cust_main}
		cust_rest=${derived_branch:main_len}
		cust_nmbr=$(echo "${cust_rest}" | grep -Eo "^[0-9]+")
		if [ ${#cust_nmbr} != 4 ]; then
			cust_num4=$(printf "%.4d" $(echo "${cust_nmbr}" | sed 's/^0*//'))
			cust_rest=$(echo "${cust_rest}" | sed "s/${cust_nmbr}/${cust_num4}/")
			derived_branch="${cust_main}${cust_rest}"
		fi
	fi

	# Handle instances where the branch name has suffixes, eg "AS9-CUS-AP-0048x"
	if [[ $(expr match "${derived_branch}" 'AS9-CUS[A-Z]*-[A-Z]\{2,\}-[0-9]\{4\}') != 0 && $(expr match "${derived_branch}" 'AS9-CUS[A-Z]*-[A-Z]\{2,\}-[0-9]\{4\}$') = 0 ]]; then
		#if [[ "${derived_branch}" =~ ^AS9-CUS[A-Z]*-[A-Z]{2,}-[0-9]{4} && ! "${derived_branch}" =~ ^AS9-CUS[A-Z]*-[A-Z]{2,}-[0-9]{4}$ ]]; then
		branch_part=$(echo "${derived_branch}" | sed -E 's/^AS9-CUS[A-Z]*-[A-Z]{2,}-[0-9]{4}//')
		name_length=${#derived_branch}
		part_length=${#branch_part}
		derived_branch=${derived_branch:0:name_length-part_length}
	fi

	# Does the derived branch match the pattern of a customisation name?
	if [ $(expr match "${derived_branch}" 'AS9-CUS[A-Z]*-[A-Z]\{2,\}-[0-9]\{4\}$') != 0 ]; then
		#if [[ "${derived_branch}" =~ ^AS9-CUS[A-Z]*-[A-Z]{2,}-[0-9]{4}$ ]]; then
		# Yes, return the derived branch to the caller
		echo "${derived_branch}"
	else
		# No, return an empty string
		echo ""
	fi
}

## cherry-picks ################################################################
################################################################################

function get-last-pick() {
	get_last_pick "$@"
}

function trigger-cherry-pick-opg() {
	customization="${1}"
	branch="${2}"

	# Make sure we're up to date
	echo-run git pull

	# Checkout the branch if necessary
	if [ -n "${branch}" ]; then
		echo-run git checkout "${branch}"
	fi

	# Create a new file with the customization name
	echo-run touch "${customization}"

	# Add the file to the index
	echo-run git add "${customization}"

	# Commit the file
	echo-run git commit -m "Cherry-Pick ${customization}"

	# Push the commit to the branch
	if [ -n "${branch}" ]; then
		echo-run git push $(git remote) "${branch}"
	else
		echo-run git push
	fi
}

function trigger-cherry-pick-tri() {
	echo -n
}

# get the last checkin of a customization into the development branch, optionally
# after a specified date
function get-last-checkin {
	local cust_name="${1}"
	local target_branch="${2}"

	# Determine if the name is already in pattern format by checking for a [
	local cust_pattern
	if [[ "${cust_name}" =~ "[" ]]; then
		cust_pattern="${cust_name}"
	else
		cust_pattern=$(generate-customization-pattern "${cust_name}")
	fi

	# since we're prepending origin/ to the branch name, remove it if it's there
	target_branch="${target_branch#origin/}"

	# Find the last Pull request merging in the branch for the customization
	debug "git log -1 --merges 'origin/${target_branch}' -E --grep='^Merged in ${cust_pattern}' --pretty=format:'%at%x09%h%x09%p'"
	last_merge=$(git log -1 --merges "origin/${target_branch}" -E --grep="^Merged in ${cust_pattern}" --pretty=format:"%at%x09%h%x09%p")
	if [ -z "${last_merge}" ]; then
		return 1
	fi
	last_merge_arr=($last_merge)
	last_merge_time=${last_merge_arr[0]}
	last_merge_hash=${last_merge_arr[1]}
	last_merge_tree="${last_merge_arr[2]}..${last_merge_arr[3]}"

	# Get the number of files changed in the merge
	last_merge_objs=$(git diff --name-only "$last_merge_tree" | wc -l)

	echo "${last_merge_time} ${last_merge_hash} ${last_merge_objs}"
}

## customization metadata ######################################################
################################################################################

# Returns the last entry in each customization for the given filepath in the
# format:
#   <timestamp>\t<customization>\t<filepath>
function get-metadata-by-file-from-xml() {
	debug "${@@Q}"

	local filepath="${1}"
	local cust_meta="${2:-${METADATA_FILE}}"

	awk -v filepath="${filepath}" -v name_only="${NAME_ONLY:-0}" \
		'
        # when we hit a customization, store its name in case we find the
        # filepath
        /<customization id=/ {
            cust=gensub(/.*id="(.*?)".*/, "\\1", "g");
            found=0;
        }
        # when we find the filepath, set found and in_object to 1
        $0 ~ "<name>"filepath"</name>" {
            found=1;
            in_object=1
        }
        # after finding the object, store the timestamp...
        {
            if (in_object == 1) {
                if ($0 ~ "<timestamp>") {
                    timestamp=gensub(/.*<timestamp>(.*?)<\/timestamp>.*/, "\\1", "g");
                } else if ($0 ~ "<mode>") {
                    mode=gensub(/.*<mode>(.*?)<\/mode>.*/, "\\1", "g");
                } else if ($0 ~ "<checksum>") {
                    checksum=gensub(/.*<checksum>(.*?)<\/checksum>.*/, "\\1", "g");
                } else if ($0 ~ "</object>") {
                    in_object=0;
                }
            }
        }
        # once we reach the end of the object, set in_object to 0
        {
            if (in_object == 1 && $0 ~ "</object>") {
                in_object=0;
            }
        }
        # if we reach the end of the customization and found the filepath, print
        # the timestamp, customization, and filepath
        {
            if ($0 ~ "</customization>" && found == 1) {
                if (name_only == 1) {
                    print cust;
                } else {
                    print timestamp "\t" checksum "\t" mode "\t" cust "\t" filepath;
                }
                found=0;
            }
        }' \
		"${cust_meta}" |
		uniq
}

# Returns the last entry in each customization for the given checksum in the
# format:
#   <timestamp>\t<customization>\t<filepath>
function get-metadata-by-checksum-from-xml() {
	debug "${@@Q}"

	local checksum="${1}"
	local cust_meta="${2:-${METADATA_FILE}}"

	awk -v checksum="${checksum}" -v name_only="${NAME_ONLY:-0}" \
		'
        # when we hit a customization, store its name in case we find the
        # filepath
        /<customization id=/ {
            cust=gensub(/.*id="(.*?)".*/, "\\1", "g");
            found=0;
        }
        # when we hit a file, store its name in case we find the checksum
        /<name>/ {
            filename=gensub(/.*<name>(.*?)<\/name>.*/, "\\1", "g");
        }
        # when we hit a timestamp, store it in case we find the checksum
        /<timestamp>/ {
            timestamp=gensub(/.*<timestamp>(.*?)<\/timestamp>.*/, "\\1", "g");
        }
        # when we hit a mode, store it in case we find the checksum
        /<mode>/ {
            mode=gensub(/.*<mode>(.*?)<\/mode>.*/, "\\1", "g");
        }
        # when we find the checksum, set found to 1
        $0 ~ "<checksum>"checksum"</checksum>" {
            found=1;
        }
        # if we reach the end of the customization and found the filepath, print
        # the timestamp, customization, and filepath
        {
            if ($0 ~ "</customization>" && found == 1) {
                if (name_only == 1) {
                    print cust;
                } else {
                    print timestamp "\t" checksum "\t" mode "\t" cust "\t" filepath;
                }
                found=0;
            }
        }' \
		"${cust_meta}" |
		uniq
}

# Returns the customization for the given filepath in the format:
#   <commit hash>\t<commit timestamp>\t<customization>\t<filepath>
function get-metadata-by-file-from-git() {
	debug "${@@Q}"
	local filepath="${1}"
	local ref="${2}"

	cust_list=$(
		git log ${ref} -m --pretty="%h:%at:%s" -- "${filepath}" |
			grep --color=never -E "${OPG_AS_CUSTOMIZATION_PATTERN}" |
			awk \
				-v filepath="${filepath}" -F: \
				"{print \$1 \"\t\" \$2 \"\t\" gensub(/.*(${OPG_AS_CUSTOMIZATION_PATTERN}).*/, \"\\\1\", \"g\", \$3) \"\t\" filepath}"
	)

	if [ "${NAME_ONLY}" -eq 1 ]; then
		echo "${cust_list}" | awk '{print $3}' | uniq
	else
		echo "${cust_list}"
	fi
}

# Given a commit hash, try to find an return a customization id from its commit
# message
function get-customization-from-commit-msg() {
	local commit="${1}"
	local commit_message=$(git show -s --pretty=format:%B "${commit}")
	debug "extracting customization from commit_message: ${commit_message}"
	local customization=$(
		echo "${commit_message}" |
			grep --color=never -oE "${OPG_AS_CUSTOMIZATION_PATTERN}" |
			head -1
	)
	debug "customization: ${customization}"
	echo "${customization}"
}

# Returns the metadata from the given git ref in the format:
#    <commit>\t<timestamp>\t<checksum>\t<mode>\t<customization>\t<filepath>
#
# If a customization is provided as the second argument, uses that as the
# customization for every file in the ref. Else, tries to infer the
# customization from the commit message(s)
function get-metadata-from-git-ref() {
	debug "${@@Q}"

	local ref="${1}"
	local override_cust="${2}"

	# determine the ref type
	local ref_type=$(get-ref-type "${ref}")
	debug "ref_type: ${ref_type}"

	# if the ref is a commit, use only that commit
	if [ "${ref_type}" == "commit" ]; then
		# limit our lookup to just this commit
		local limit="-n 1"
		debug "limit: ${limit}"

		if is-merge-commit "${ref}" 2>/dev/null; then
			debug "ref is merge commit"
			# if no override cust is provided, then use the commit message of the
			# merge commit to determine the customization id for all commits
			# included in the merge
			if [ -z "${override_cust}" ]; then
				override_cust=$(get-customization-from-commit-msg "${ref}")
				if [ -z "${override_cust}" ]; then
					override_cust="---"
				fi
				debug "override_cust: ${override_cust}"
			fi
			# use the merge range as the ref
			ref=$(git log -1 --pretty=format:%P "${ref}" | sed 's/ /.. /g')
			debug "ref is updated to: ${ref}"
		else
			debug "ref is not merge commit"
		fi
	fi

	# if the provided ref is a merge commit, we'll need to get the metadata for
	# each of the commits in the merge

	# get a list of all the files and their commits in the ref in the format:
	#   <commit hash>:<filepath>
	local file_commits=$(get-commit-hashes-and-objects "${ref}" "${limit}")
	local file_commit_count=$(echo "${file_commits}" | wc -l)

	debug "file_commits (${file_commit_count}): ${file_commits}"

	# walk through each of the above objects and get the metadata for each one
	debug "walking through each file commit"
	while IFS= read -r line; do
		debug "line: ${line}"
		local commit_hash=$(echo "${line}" | awk -F: '{print $1}')
		local filepath=$(echo "${line}" | awk -F: '{print $2}')
		debug "commit_hash: ${commit_hash} / filepath: ${filepath}"
		local file_metadata=$(get-obj-metadata "${filepath}" "${commit_hash}")
		debug "file_metadata: ${file_metadata}"
		# the above returns metadata in the format:
		# <commit>\t<timestamp>\t<checksum>\t<mode>\t<customization>\t<filepath>
		local obj_timestamp=$(echo "${file_metadata}" | awk -F'\t' '{print $2}')
		local obj_checksum=$(echo "${file_metadata}" | awk -F'\t' '{print $3}')
		local obj_mode=$(echo "${file_metadata}" | awk -F'\t' '{print $4}')
		# use either the override customization or the one inferred from the
		# commit message
		if [ -n "${override_cust}" ]; then
			local obj_cust="${override_cust}"
		else
			local obj_cust=$(echo "${file_metadata}" | awk -F'\t' '{print $5}')
		fi
		# print the metadata
		# <commit>\t<timestamp>\t<checksum>\t<mode>\t<customization>\t<filepath>
		TAB=$'\t'
		echo "${commit_hash}${TAB}${obj_timestamp}${TAB}${obj_checksum}${TAB}${obj_mode}${TAB}${obj_cust}${TAB}${filepath}"
	done <<<"${file_commits}"
}

# Returns the files added under a given customization in the format:
#   <timestamp>\t<checksum>\t<mode>\t<customization>\t<filepath>
function get-metadata-by-cust-from-xml() {
	debug "${@@Q}"

	local cust_name="${1}"
	local cust_meta="${2:-${METADATA_FILE}}"

	awk -v cust="${cust_name}" -v paths_only="${PATHS_ONLY:-0}" \
		'
        # when we hit the specified customization, store its name
        $0 ~ "<customization id=\""cust"\">" {
            found=1;
        }
        # each time we hit a new <object>, reset the object vars
        $0 ~ "<object>" {
            name="";
            mode="";
            timestamp="";
            checksum="";
        }
        # if in_object == 1 and the line includes "<timestamp>", store the
        # timestamp
        $0 ~ "<name>" {
            name=gensub(/.*<name>(.*?)<\/name>.*/, "\\1", "g");
        }
        $0 ~ "<mode>" {
            mode=gensub(/.*<mode>(.*?)<\/mode>.*/, "\\1", "g");
        }
        $0 ~ "<timestamp>" {
            timestamp=gensub(/.*<timestamp>(.*?)<\/timestamp>.*/, "\\1", "g");
        }
        $0 ~ "<checksum>" {
            checksum=gensub(/.*<checksum>(.*?)<\/checksum>.*/, "\\1", "g");
        }
        # once we reach the end of the object, print the timestamp, checksum,
        # mode, customization, and filepath
        $0 ~ "</object>" {
            if (paths_only == 1) {
                print name;
            } else {
                print timestamp "\t" checksum "\t" mode "\t" cust "\t" name;
            }
        }' \
		"${cust_meta}" |
		uniq
}

# append the specified customization into the metadata file if it doesn't exist
function insert-cust-into-xml() {
	local cust_name="${1}"
	local cust_meta="${2:-${METADATA_FILE}}"

	# ensure the customization isn't already in the file
	if ! grep -qF "<customization id=\"${cust_name}\">" "${cust_meta}"; then
		debug "insert customization '${cust_name}' into '${cust_meta}'"
		# insert the customization into the file
		sed -i '/<\/customizations>/i\ \ <customization id="'"${cust_name}"'">' ${cust_meta}
		sed -i '/<\/customizations>/i\ \ \ \ <objects>' ${cust_meta}
		sed -i '/<\/customizations>/i\ \ \ \ </objects>' ${cust_meta}
		sed -i '/<\/customizations>/i\ \ </customization>' ${cust_meta}
	else
		debug "customization '${cust_name}' already exists in '${cust_meta}'"
	fi
}

# add the specified metadata to the metadata file
# usage:
#   insert-metadata-into-xml <filepath> <mode> <timestamp> <checksum> <customization> <metadata file>
function insert-metadata-into-xml() {
	local obj_path="${1}"
	local obj_mode="${2}"
	local obj_timestamp="${3}"
	local obj_checksum="${4}"
	local cust_name="${5}"
	local cust_meta="${6:-${METADATA_FILE}}"

	local cust_range

	# ensure the customization exists in the file
	insert-cust-into-xml "${cust_name}" "${cust_meta}"

	# determine where to insert the metadata
	cust_line_range=$(get_metadata_cust_range "${cust_name}" "${cust_meta}")
	cust_line_range_start=$(echo "${cust_line_range}" | cut -d "," -f 1)
	cust_line_range_end=$(echo "${cust_line_range}" | cut -d "," -f 2)
	obj_line_no=$((cust_line_range_end - 1))
	debug "cust_line_range: ${cust_line_range}"

	# insert the metadata
	sed -i "${obj_line_no}i \ \ \ \ \ \ <object>" ${cust_meta}
	let obj_line_no++
	sed -i "${obj_line_no}i \ \ \ \ \ \ \ \ <name>${obj_path}<\/name>" ${cust_meta}
	let obj_line_no++
	sed -i "${obj_line_no}i \ \ \ \ \ \ \ \ <mode>${obj_mode}<\/mode>" ${cust_meta}
	let obj_line_no++
	sed -i "${obj_line_no}i \ \ \ \ \ \ \ \ <timestamp>${obj_timestamp}<\/timestamp>" ${cust_meta}
	let obj_line_no++
	if [ -n "${obj_checksum}" ] && [[ ! "001000" =~ ^0+$ ]]; then
		sed -i "${obj_line_no}i \ \ \ \ \ \ \ \ <checksum>${obj_checksum}<\/checksum>" ${cust_meta}
		let obj_line_no++
	fi
	sed -i "${obj_line_no}i \ \ \ \ \ \ <\/object>" ${cust_meta}
}

# given the name/path of an object, return metadata about it in the format:
#   <commit>\t<timestamp>\t<checksum>\t<mode>\t<customization>\t<filepath>
# usage:
#   get-obj-metadata <filepath> [<customization> [<customization>]]
# if no customization is specified, the customization will be inferred from the
# commit message
function get-obj-metadata() {
	debug "${@@Q}"
	local filepath="${1}"
	local ref="${2:-$(git-branch-name)}"
	local override_cust="${3}"

	if [ -z "${filepath}" ]; then
		echo-stderr "error: filepath not specified"
		return 1
	fi

	# get the file's relative path to the repo root
	local rel_path=$(git-relpath "${filepath}")

	# get the file's status at the specified ref
	local obj_status=$(git log "${ref}" -m -1 --pretty="%h%x09%at%x09%s" --name-status -- "${rel_path}")

	# extract the file's timestamp and status
	local obj_commit=$(echo "${obj_status}" | head -1 | awk -F'\t' '{print $1}')
	local obj_time=$(echo "${obj_status}" | head -1 | awk -F'\t' '{print $2}')
	local obj_summary=$(echo "${obj_status}" | head -1 | awk -F'\t' '{print $3}')
	local obj_mode=$(echo "${obj_status}" | tail -1 | awk '{print $1}' | git-status-name -)

	# get the file's md5 checksum
	local obj_checksum
	if [ "${obj_mode}" == "delete" ]; then
		obj_checksum=""
	else
		obj_checksum=$(git show "${ref}:${rel_path}" | md5sum - | awk '{print $1}')
	fi

	# get the file's customization
	local obj_cust
	if [ -n "${override_cust}" ]; then
		obj_cust="${override_cust}"
	else
		# try to extract a customization id from the commit message
		obj_cust=$(echo "${obj_summary}" | grep -oE "${OPG_AS_CUSTOMIZATION_PATTERN}" | head -1)
		if [ -z "${obj_cust}" ]; then
			obj_cust="---"
		fi
	fi

	# print the file's metadata
	TAB=$'\t'
	echo "${obj_commit}${TAB}${obj_time}${TAB}${obj_checksum}${TAB}${obj_mode}${TAB}${obj_cust}${TAB}${filepath}"
}

# given the name of a customization and a customization metadata file, remove
# the customization from the metadata file
function remove-cust-from-xml() {
	local cust_name="${1}"
	local cust_meta="${2:-${METADATA_FILE}}"

	# get the range of lines to remove
	local cust_range=$(get_metadata_cust_range "${cust_name}" "${cust_meta}")
	if [ -z "${cust_range}" ]; then
		echo "error: customization ${cust_name} not found" >&2
		return 1
	fi

	# remove the lines
	sed -i "${cust_range}d" "${cust_meta}"
}

# given the name of an object, a customization metadata file, and an optional
# customization, remove every occurence of the object from the metadata file
function remove-obj-from-xml() {
	local obj_path="${1}"
	local cust_meta="${2:-${METADATA_FILE}}"
	local cust_name="${3}"

	# Ensure a customization metadata file was provided
	if [ -z "${cust_meta}" ]; then
		echo "error: customization metadata file not specified" >&2
		return 1
	fi

	# Lookup the line range of the object
	local obj_range=$(get_metadata_obj_range "${obj_path}" "${cust_meta}" "${cust_name}")
	while [ -n "${obj_range}" ]; do
		# Remove the object from the metadata file
		sed -i "${obj_range}d" "${cust_meta}"

		# Lookup the line range of the object
		obj_range=$(get_metadata_obj_range "${obj_path}" "${cust_meta}" "${cust_name}")
	done
}

function get-metadata-cust-range() {
	get_metadata_cust_range "${@}"
}

## opg-as9/docker/scripts/update.sh ############################################
################################################################################

# Get the last valid cherry pick of a customization into a branch, optionally
# before a specified date, where "valid" means that it modified at least one
# non-ignorable file.
function get_last_pick {
	debug "${@@Q}"

	local cust_name="$1"
	local target_branch="$2"
	local before="${3:-$(date +%s)}"
	local get_cherry_pick_trigger
	local usage="usage: $(functionname) <customization name> <target branch> [<before date>]"

	if [ "${LAST_PICK_TRIGGER_TIME}" -eq 0 ] 2>/dev/null; then
		get_cherry_pick_trigger="false"
	else
		get_cherry_pick_trigger="true"
	fi

	if [ -z "${cust_name}" ]; then
		echo "${usage}" >&2
		echo-stderr "No customization name specified"
		return 1
	fi
	if [ -z "${target_branch}" ]; then
		echo "${usage}" >&2
		echo-stderr "No target branch specified"
		return 1
	fi

	# Determine if the name is already in pattern format by checking for a [
	local cust_pattern
	if [[ "${cust_name}" =~ "[" ]]; then
		cust_pattern="${cust_name}"
	else
		cust_pattern=$(generate-customization-pattern "${cust_name}")
	fi

	# Ensure a branch is defined
	if [ -z "${target_branch}" ]; then
		echo "error: get-last-pick: no target branch specified" >&2
		return 1
	fi

	# Generate a list of cherry-picks for the customization into the target branch with each file in that cherry-pick
	# on the same line delimited by a \2 character
	# e.g.:
	#   43169edc8\t1659555795\tCherry-picking for AS9-CUS-SDS-0009\x02AS9-CUS-SDS-009\x02tailored/metadata/runtime/ui/VIEW/FANNS025-FANN-VIEW.xml\n
	#   c0bf3b73f\t1654542635\tCherry-picking for AS9-CUS-SDS-0009\x02AS9-CUS-SDS-0009\n
	#   56b4912d5\t1646009697\tCherry-picking for AS9-CUS-SDS-0009\x02AS9-CUS-SDS-0009\n
	local pick_list=$(git log -15 "origin/${target_branch}" --grep="^Cherry-picking for.*${cust_pattern}" -E --format=$'\1%h%x09%at%x09' --name-only --raw --before="${before}" |
		grep -v '^$' |
		tr '\n' '\2' |
		sed $'s/.*/&\1/' |
		tr '\1' '\n' |
		sed 1d |
		sed $'s/\2$//')

	# Loop through the cherry-picks and find the first one that contains a valid, non-ignorable cherry-pick file
	local found_pick=0
	while IFS= read -r pick; do
		# Extract the hash, timestamp, and pick files
		local last_pick_hash=$(echo "${pick}" | awk -F '\t' '{print $1}')
		local last_pick_time=$(echo "${pick}" | awk -F '\t' '{print $2}' | awk -F $'\2' '{print $1}')
		local last_pick_files=$(echo "${pick}" | awk -F '\t' '{print $3}' | tr '\2' '\n' | sed 1d)
		local last_pick_objs=0
		# Loop through the files and check if any of them are not ignored
		while IFS= read -r file; do
			# Check if the file is one we would pick
			if [ $(opg-as-ignore-object "${file}") = "false" ]; then
				# This is a valid, cherry-pick file
				found_pick=1
				let last_pick_objs++
			fi
		done <<<"${last_pick_files}"
		if [ ${found_pick} -eq 1 ]; then
			break
		fi
	done <<<"${pick_list}"

	if [ ${found_pick} -eq 1 ]; then
		# Return the time, hash, and number of objects now if we aren't looking for the trigger time
		if [ "${get_cherry_pick_trigger}" = "false" ] &&
			[ -n "${last_pick_time}" ] &&
			[ -n "${last_pick_hash}" ]; then
			echo "${last_pick_time}" "${last_pick_hash}" "${last_pick_objs}"
			return 0
		fi
		# There could be a several hour gap between when Maurice Moss' commit is picked and when it was triggered, during which time
		# more code could have been committed. So we need to find the "Merged in" commit that triggered the cherry-pick. This will
		# be the most recent commit before the above commit
		local last_merge=$(git log -1 "origin/${target_branch}" --grep="^Merged in.*${cust_pattern}" -E --pretty="%at%x09%h" --before="${last_pick_time}")
		last_merge=($last_merge)
		last_merge_time=${last_merge[0]}
		last_merge_hash=${last_merge[1]}
	fi

	# Make sure we found a valid result that contains a last_merge_time and last_merge_hash.
	# It's probably enough to just check for found_pick, but we'll be paranoid
	if [ "${found_pick}" -eq 1 ]; then
		if [ -n "${last_merge_time}" ] && [ -n "${last_merge_hash}" ]; then
			echo "${last_merge_time} ${last_merge_hash} ${last_pick_objs}"
			return 0
		else
			echo "error: get-last-pick: found a pick without a prior merge time or hash" >&2
			return 500
		fi
	fi

	return 1
}

# Define a function to accept a customization and metadata file and return the
# range of lines where the customization is defined in the metadata file.
function get_metadata_cust_range {
	local cust_name="${1}"
	local cust_meta="${2}"

	# Ensure a metadata file was specified
	if [ -z "${cust_meta}" ]; then
		echo "error: get-metadata-cust-range: no metadata file specified" >&2
		return 1
	fi

	# Get the line number of the first line of the customization in the metadata file
	awk -v cust_name="${cust_name}" -v found=0 '
        {
             if (gensub(/^\s+/, "", "g", $0) == "<customization id=\""cust_name"\">") {
                found=1;
                start_line = NR;
            } else if (found == 1) {
                if ($0 ~ "</customization>") {
                    end_line = NR;
                    print start_line","end_line;
                    exit 0
                }
            }
        }
        END {
            if (found == 0) {
                exit 1
            }
        }' "${cust_meta}"
}

# Define a function that accepts an object, a metadata file, and an optional customization, then
# returns the line range where the object is found in the metadata file in the format `start_line,end_line`
function get_metadata_obj_range {
	local obj_name="${1}"
	local cust_meta="${2}"
	local cust_name="${3}"

	# Ensure a metadata file was specified
	if [ -z "${cust_meta}" ]; then
		echo "error: get-metadata-obj-range: no metadata file specified" >&2
		return 1
	fi

	# If specified, get the range of the customization. Else, use the entire metadata file
	local range_start range_end
	if [ -n "${cust_name}" ]; then
		IFS=',' read -r range_start range_end <<<$(get_metadata_cust_range "${cust_name}" "${cust_meta}")
		# If the customization was not found, return an error
		if [ -z "${range_start}" ] || [ -z "${range_end}" ]; then
			echo "error: get-metadata-obj-range: customization ${cust_name} not found in '${cust_meta}'" >&2
			return 1
		fi
	else
		range_start=1
		range_end=$(wc -l "${cust_meta}" | awk '{print $1}')
	fi

	# Get the line number of the first line of the customization in the metadata file
	awk -v obj_name="${obj_name}" -v found=0 -v range_start="${range_start}" -v range_end="${range_end}" '
        {
            if (NR >= range_start && NR <= range_end) {
                if ($0 ~ "<object>") {
                    # track the first line where the object starts
                    start_line = NR;
                } else if (gensub(/^\s+/, "", "g", $0) == "<name>"obj_name"</name>") {
                    # we found the object with the given name!
                    found=1;
                } else if (found == 1) {
                    if ($0 ~ "</object>") {
                        # we found the end of the object, so print the range and
                        # exit successfully
                        end_line = NR;
                        print start_line","end_line;
                        exit 0
                    }
                }
            }
        }
        END {
            if (found == 0) {
                exit 1;
            }
        }' "${cust_meta}"
}

# Normalizes a customization name considering common mistakes
function get_cust_name {
	# Receive the branch name as an argument
	derived_branch="$1"

	# Handle instances where there is a branch type prefix, eg "bugfix/AS9-CUS-FI-0033-G"
	derived_branch_base=$(echo "$(basename ${derived_branch})")
	if [ "${derived_branch}" != "${derived_branch_base}" ]; then
		derived_branch="${derived_branch_base}"
	fi

	# Handle instances where the branch name begins with "AS-" instead of "AS9-"
	if [ $(expr match "${derived_branch}" 'AS[-_]') != 0 ]; then
		#if [[ "${derived_branch}" =~ ^AS[-_] ]]; then
		derived_branch=$(echo "${derived_branch}" | sed -E 's/^AS[-_]/AS9-/')
	fi

	# Handle instances where the customisation designation and the customisation type are switched, eg "AS9-FI-CUS-0033"
	# Also, replace any underscores in the customisation name with hyphens, eg "AS9-FI_CUS_0033"
	if [ $(expr match "${derived_branch}" 'AS9-[A-Z]\{2,\}[-_]CUS') != 0 ]; then
		#if [[ "${derived_branch}" =~ ^AS9-[A-Z]{2,}[-_]CUS ]]; then
		cust_desg=$(echo "${derived_branch}" | sed 's/AS9-//')
		cust_type=$(echo "${cust_desg}" | sed 's/[-_]CUS.*//')
		cust_desg=$(echo "${cust_desg}" | sed "s/${cust_type}[-_]//" | sed 's/[-_].*//')
		cust_idnt=$(echo "${derived_branch}" | sed "s/AS9-${cust_type}[-_]${cust_desg}[-_]//")
		derived_branch="AS9-${cust_desg}-${cust_type}-${cust_idnt}"
	fi

	# Handle instances where the numeric suffix has more or less digits than 4, eg "AS9-CUS-AR-0002-2"
	if [ $(expr match "${derived_branch}" 'AS9-CUS[A-Z]*-[A-Z]\{2,\}-[0-9]\+') != 0 ]; then
		#if [[ "${derived_branch}" =~ ^AS9-CUS[A-Z]*-[A-Z]{2,}-[0-9]+ && ! "${derived_branch}" =~ ^AS9-CUS[A-Z]*-[A-Z]{2,}-[0-9]{4} ]]; then
		cust_main=$(echo "${derived_branch}" | grep -Eo "^AS9-CUS[A-Z]*-[A-Z]{2,}-")
		main_len=${#cust_main}
		cust_rest=${derived_branch:main_len}
		cust_nmbr=$(echo "${cust_rest}" | grep -Eo "^[0-9]+")
		if [ ${#cust_nmbr} != 4 ]; then
			cust_num4=$(printf "%.4d" $(echo "${cust_nmbr}" | sed 's/^0*//'))
			cust_rest=$(echo "${cust_rest}" | sed "s/${cust_nmbr}/${cust_num4}/")
			derived_branch="${cust_main}${cust_rest}"
		fi
	fi

	# Handle instances where the branch name has suffixes, eg "AS9-CUS-AP-0048x"
	if [[ $(expr match "${derived_branch}" 'AS9-CUS[A-Z]*-[A-Z]\{2,\}-[0-9]\{4\}') != 0 && $(expr match "${derived_branch}" 'AS9-CUS[A-Z]*-[A-Z]\{2,\}-[0-9]\{4\}$') = 0 ]]; then
		#if [[ "${derived_branch}" =~ ^AS9-CUS[A-Z]*-[A-Z]{2,}-[0-9]{4} && ! "${derived_branch}" =~ ^AS9-CUS[A-Z]*-[A-Z]{2,}-[0-9]{4}$ ]]; then
		branch_part=$(echo "${derived_branch}" | sed -E 's/^AS9-CUS[A-Z]*-[A-Z]{2,}-[0-9]{4}//')
		name_length=${#derived_branch}
		part_length=${#branch_part}
		derived_branch=${derived_branch:0:name_length-part_length}
	fi

	# Does the derived branch match the pattern of a customisation name?
	if [ $(expr match "${derived_branch}" 'AS9-CUS[A-Z]*-[A-Z]\{2,\}-[0-9]\{4\}$') != 0 ]; then
		#if [[ "${derived_branch}" =~ ^AS9-CUS[A-Z]*-[A-Z]{2,}-[0-9]{4}$ ]]; then
		# Yes, return the derived branch to the caller
		echo "${derived_branch}"
	else
		# No, return an empty string
		echo ""
	fi
}

## as_deploy.sh ################################################################
################################################################################

# A function which determines whether or not to ignore a file in the OPG AS
# project
function opg-as-ignore-object() {
	debug "${@@Q}"

	# Receive the object path as an argument
	obj="$1"
	# Easier to pay attention to certain paths rather than ignore them
	retVal=$(echo "${obj}" | grep -E "^(nxa/|tailored/|database/|app_config/|helix/)")
	if [ -n "${retVal}" ]; then
		# We should not ignore this object, return false
		echo "false"
	else
		# Ignore, return true
		echo "true"
	fi
}

# Accept the mode of an object using `git log --name-status` and return a
# string indicating the mode of the object
function opg-as-get-obj-mode {
	local obj_commit="$1"
	local obj_path="$2"
	local object_mode

	object_mode=$(git diff-tree --no-commit-id --name-status -r "${obj_commit}" -- "${obj_path}" | awk '{print $1}' | xargs)
	# Check if we actually have a result
	if [ -z "${object_mode}" ]; then
		# Try another way
		object_mode=$(git log -n 1 "${obj_commit}" --pretty="oneline" --name-status -- "${obj_path}" | grep -vE "^[a-f0-9]{40}" | awk '{print $1}' | xargs)
	fi
	case "${object_mode}" in
	"A")
		object_mode="create"
		;;
	"M")
		object_mode="update"
		;;
	"D")
		object_mode="delete"
		;;
	*)
		object_mode="unknown"
		;;
	esac
	echo "${object_mode}"
}
