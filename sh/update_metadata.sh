#!/bin/bash

###################################################################################################
#                                                                                                 #
#   AS9 DEPLOY REMOTE UPDATE SCRIPT                                                               #
#                                                                                                 #
# =============================================================================================== #
#                                                                                                 #
#   Author        :  Shane Casey                                                                  #
#   Date Created  :  18/05/2021                                                                   #
#   Description   :  Invoked remotely by the AS9 Deploy Docker startup script                     #
#   Changelog     :  18/05/2021 - Initial version                                                 #
#                    15/06/2022 - When cherry-picking, show object index and remaining objects    #
#                               - Only cherry pick files that have been updated since the last    #
#                                 cherry-pick                                                     #
#                                                                                                 #
###################################################################################################

#==================  PROCESS THE RECEIVED ARGUMENTS  ==============================================

# update.sh ${COMMIT} ${SRC_BRANCH} ${BRANCH} ${DEPLOY_MODE} ${CUST_NAME} ${REPO_DIR} "false" "NULL" "NULL" "NULL" "NULL" "NULL"

REPO_DIR="${1:-.}"
CUST_FILE="${2}"
SEARCH_FOR_LAST_PICK_BEFORE="${3}"

if [ -z "${SEARCH_FOR_LAST_PICK_BEFORE}" ]; then
    echo "usage: $(basename "$0") <repo_dir> <customization_file> <search_for_last_pick_before>" 2>&1
    exit 1
fi

CUST_NAMES=`cat ${CUST_FILE}`
CUST_META="customization_metadata/customization_metadata.xml"
DST_BRANCH=release
DEPLOY_MODE=pick
WAIT_BETWEEN_PICKS=3
# COMMIT="${1}"
# SRC_BRANCH="${2}"
# DST_BRANCH="${3}"
# DEPLOY_MODE="${4}"
# CUST_NAME="${5}"
# REPO_DIR="${6}"
# IS_LINKED="${7}"
# AS9_REGION="${8}"
# AS_SOAP_USER="${9}"
# AS_SOAP_PASS="${10}"
# AS_SOAP_UTXT="${11}"
# AS_SOAP_PTXT="${12}"

# create a function that runs git commands using the specified REPO_DIR
function git {
    /usr/bin/git --git-dir=${REPO_DIR}/.git --work-tree=${REPO_DIR} "$@"
}

#==================  THIS SECTION DEFINES THE FUNCTIONS  ==========================================

function Main {
    # loop over the customizations and update the metadata file
    cust_i=1
    cust_total=`echo "${CUST_NAMES}" | wc -l`
    for CUST_NAME in ${CUST_NAMES}; do
        echo "## [$cust_i/$cust_total] Updating metadata for ${CUST_NAME} in ${WAIT_BETWEEN_PICKS} seconds..."
        for i in `seq 1 ${WAIT_BETWEEN_PICKS}`; do
            num_dots=$(( WAIT_BETWEEN_PICKS - i + 1 ))
            printf "%${WAIT_BETWEEN_PICKS}s\r" " "
            printf ".%.0s" `seq 1 ${num_dots}`
            sleep 1
        done
        update_metadata ${CUST_NAME}
        let cust_i++
    done
}

# Define the main function
function update_metadata {
    CUST_NAME="${1^^}"
    SRC_BRANCH="${CUST_NAME}"

    # # Define whether we are cherry-picking from the next lower-order branch, or from 'development'
    PICK_SRC="dev"
    # #PICK_SRC="low"

    # Extract the repo name from the full path
    REPO_NM=$(basename ${REPO_DIR})

    # # Switch the local working directory to the root of the repository
    # cd ${REPO_DIR}

    # If we are doing a full deployment, the objects we need will already be in the destination branch
    if [ "${DEPLOY_MODE}" = "pick" ]; then
        # Cherry-pick the changes

        echo ""
        echo "=============================================================================="
        echo "CHERRY-PICKING OBJECTS  : " $(date)
        echo "=============================================================================="
        echo ""

        # Convert the branch name to a regex pattern for matching
        # At this point, if we are cherry-picking from development into test, we need to compile all eligible objects from merges into dev
        # Otherwise, the objects will need to be compiled from non-merge commits into the destination branch
        echo -n "Generating branch-name matching pattern ... "
        if [ "${PICK_SRC}" = "dev" ]; then
            branch_pattern_prefix="^Merged in"
        elif [ "${PICK_SRC}" = "low" ]; then
            case "${DST_BRANCH}" in
            "test")
                branch_pattern_prefix="^Merged in"
                ;;
            "release")
                branch_pattern_prefix="^Cherry-picking for"
                ;;
            esac
        fi

        # Check if this cherry-pick is for documentation
        if [[ "${SRC_BRANCH}" =~ ^[Dd][Oo][Cc][Uu][Mm][Ee][Nn][Tt][Aa][Tt][Ii][Oo][Nn]$ ]]; then
            # It is
            branch_pattern="${branch_pattern_prefix} [Dd][Oo][Cc][Uu][Mm][Ee][Nn][Tt][Aa][Tt][Ii][Oo][Nn]"
            # Also set this as the customisation name - it will be used in the logs and commit message
            CUST_NAME="${SRC_BRANCH}"
        else
            # Handle instances where the branch name may begin with AS instead of AS9, or not at all
            branch_pattern="([Aa][Ss]9?[-_])?"
            # extract the remaining components of the customisation name
            branch_remainder=$(echo "${CUST_NAME}" | sed -E 's/^AS9[-_]//')
            cust_desg=$(echo "${branch_remainder}" | sed -E 's/-.*$//')
            cust_type=$(echo "${branch_remainder}" | sed -E "s/^${cust_desg}-//" | sed -E 's/-.*$//')
            cust_nmbr=$(echo "${branch_remainder}" | sed -E "s/^${cust_desg}-${cust_type}-//")
            # Convert the uppercase strings to case-insensitive regular expressions
            cust_desg_regex=$(either_case "${cust_desg}")
            cust_type_regex=$(either_case "${cust_type}")
            # Handle instances where the customisation designation and customisation type may be switched
            branch_pattern="${branch_pattern}(${cust_desg_regex}[-_]${cust_type_regex}|${cust_type_regex}[-_]${cust_desg_regex})[-_]"
            ## Handle instances where the customisation number has leading zeros
            #cust_nmbr_regex=`leading_zeros "${cust_nmbr}"`
            #branch_pattern="${branch_pattern}${cust_nmbr_regex}"
            cust_pattern="${branch_pattern}${cust_nmbr}"
            cherry_pattern="^Cherry-picking for ${cust_pattern}"
            branch_pattern="${branch_pattern_prefix} ${cust_pattern}"
        fi
        echo "Done"

        ### In the next section we will enable the update script to perform cherry-picking into the release branch from development
        ### In order that this does not pick objects that have been committed to development but not yet ready for release, we need to filter them
        ### Eg if a customisation has been picked into test, but there is additional work going on for it (why?!) we need to ensure that the version
        ### picked into release is NOT newer than what was picked into test. To do that, we need to get the latest version that was picked into test
        ### and store the timestamp of the cherry-pick commit that wrote the picked objects to the test branch

        # List the merge commits that constitute all the changes
        # This will need to be done in the branch layer below the one we are trying to merge to
        OBJ_BRANCH="development"

        # Pull down the latest changes
        git fetch --all

        # Determine the last time the customization was picked into release
        # after_ts="`git log origin/release -2 --merges --grep="${branch_pattern}" -E --pretty=format:%aD | awk NR==2`"
        echo -n "Determining \"last\" cherry pick into release ... "
        last_pick=$(get_last_pick "${CUST_NAME}" "release" "${SEARCH_FOR_LAST_PICK_BEFORE}")
        after_ts=$(echo "${last_pick}" | cut -d ' ' -f 1)
        last_pick_hash=$(echo "${last_pick}" | cut -d ' ' -f 2)
        last_pick_objs=$(echo "${last_pick}" | cut -d ' ' -f 3)
        if [ -n "${last_pick_hash}" ] && [ "${last_pick_objs}" -eq "${last_pick_objs}" ] 2>/dev/null; then
            echo "(${last_pick_hash}) $(date -d@${after_ts})  ${last_pick_objs} files changed"
        else
            echo "None found"
        fi

        # Locate the latest cherry-pick into the test branch for this customisation and capture the timestamp of its commit
        # before_ts="`git log origin/test -1 --merges --grep="${branch_pattern}" -E --pretty=format:%aD`"
        echo -n "Determining last actual cherry pick into release ... "
        last_actual_pick=$(get_last_pick "${CUST_NAME}" "release")
        before_ts=$(echo "${last_actual_pick}" | cut -d ' ' -f 1)
        last_actual_pick_hash=$(echo "${last_actual_pick}" | cut -d ' ' -f 2)
        last_actual_pick_objs=$(echo "${last_actual_pick}" | cut -d ' ' -f 3)
        if [ -n "${last_actual_pick_hash}" ]; then
            echo "(${last_actual_pick_hash}) $(date -d@${before_ts})  ${last_actual_pick_objs} files changed"
        else
            echo "Exiting: branch has never been picked into release. Check your shit."
            echo "Debug info:"
            echo "CUST_NAME: ${CUST_NAME}"
            echo "last_actual_pick: ${last_actual_pick}"
            exit 1
        fi

        # This will be blank if the customisation has not been cherry-picked into test, in which case we cannot promote it to releae
        if [ -n "${before_ts}" ]; then
            [ -n "${after_ts}" ] && after_ts_arg="--since=${after_ts}"
            # Use this timestamp to limit the output of the matching merges in development
            merge_list=$(git log --merges origin/development --grep="${branch_pattern}" -E --pretty=oneline --before="${before_ts}" ${after_ts_arg} --reverse | awk '{print $1}')
            # If this is empty, then there have been no merges for this customisation into dev, in which case we cannot promote to releae
            if [ -n "${merge_list}" ]; then
                object_list=$(get_obj_list "${merge_list}" true)
            else
                object_list=""
            fi
        fi

        # show the list of objects
        echo "Found $(echo "${object_list}" | wc -l) objects to cherry-pick:"
        # print the object list as a hyphentated bullet list
        echo "${object_list}" | sed -e 's/^/  - /'


        # If we are cherry-picking into the "release" branch, we also need to update the customisation meta-data
        # Check if there is a meta-data file available, if there is not create it
		if [ "${DST_BRANCH}" = "release" ]; then
                    # Define the path to the metadata file
                    cust_meta=customization_metadata/customization_metadata_trinoor.xml
                    if [ ! -d "customization_metadata" ]; then
                        # Metadata folder does not exist, create it
                        echo -n "Creating metadata directory ... "
                        mkdir -p customization_metadata && echo "Done"
                    fi
                    if [ ! -f $cust_meta ]; then
                        # Metadata file does not exist, create it
                        echo -n "Creating metadata file ... "
                        (echo '<?xml version="1.0" encoding="UTF-8"?>' > $cust_meta && \
                            echo '<customizations>' >> $cust_meta && \
                            echo '</customizations>' >> $cust_meta) && echo "Done"
                    fi
                    # If this customisation already exists in the metadata file, we will need to replace it.
                    # Therefore, we should remove it from the file altogether and treat this as an append
                    # Update: we will update the metadata file with the new files cherry-picked into the release branch instead of replacing the entire history of the customization
                    # rem_cust_metadata "${CUST_NAME}"
                fi
	        
		# Need to check if the initialisation of some of the objects has been handled - this should only be required for the first cherry-pick
		# Since this is specific to the '21-05-opg-as9' repo, make sure that is what we are using
		if [ "${REPO_NM}" = "21-05-opg-as9" ]; then
			initialisation_commit="75079c6fe7041ff8f4c5a9e7d61d9cd11e2af8e9"
			initialise_branch "${initialisation_commit}"
		fi

        # Check to see if this customisation exists in the metadata file
        cust_line_range=`get_metadata_cust_range "${CUST_NAME}"`
        [ -n "${cust_line_range}" ] && cust_exists=true || cust_exists=false

        # If we are cherry-picking into the "release" branch and the customization doesn't exist in the metadata file, insert a placeholder for it at the end of the file
        if [ "${DST_BRANCH}" = "release" ] && [ "${cust_exists}" = "false" ]; then
            echo "No metadata entry found for ${CUST_NAME}, adding one at the end of the file"
            sed -i '/<\/customizations>/i\ \ <customization id="'"${CUST_NAME}"'">' ${cust_meta}
            sed -i '/<\/customizations>/i\ \ \ \ <objects>' ${cust_meta}
            sed -i '/<\/customizations>/i\ \ \ \ </objects>' ${cust_meta}
            sed -i '/<\/customizations>/i\ \ </customization>' ${cust_meta}
        fi
                
		# This list consists of a commit hash followed by the object reference on each line, iterate through them
		echo "Cherry-picking objects committed under '${CUST_NAME}'"
		if [ -n "${object_list}" ]; then
            [ -n "${after_ts}" ] && after_ts_human="`date -d@${after_ts} '+%Y-%m-%d %H:%M:%S'`"
            [ -n "${before_ts}" ] && before_ts_human="`date -d@${before_ts} '+%Y-%m-%d %H:%M:%S'`"
            if [[ -n "${after_ts}" && -n "${before_ts}" ]]; then
                echo -n " since ${after_ts_human} and before ${before_ts_human}"
            elif [[ -n "${after_ts}" ]]; then
                echo -b " since ${after_ts_human}"
            elif [[ -n "${before_ts}" ]]; then
                echo -n " before ${before_ts_human}"
            fi
			echo ":"
			echo ""
            # Track our position in the list of objects
            obj_pos=0
            obj_count=`echo "${object_list}" | wc -l`
			echo "${object_list}" | while read obj_ref; do
                let obj_pos++
				# Extract the commit hash from this reference
				obj_ref_hash=`echo "${obj_ref}" | awk '{print $1}' | xargs`
				# Now, extract the path to the object
				obj_ref_path=`echo "${obj_ref}" | sed "s/${obj_ref_hash}//" | xargs`
				# Use these to restore the object
				echo "[${obj_pos}/${obj_count}] ${obj_ref_path} :"
                    check_object ${obj_ref_hash} "${CUST_NAME}" "${obj_ref_path}" "${OBJ_BRANCH}"
				if [ $? = 0 ]; then
					echo "OK"
				else
					echo "ERROR"
				fi
			done
		else
			echo " ... No objects found"
		fi
		echo ""

        echo DONE
        # # Now, we should have staged changes against the destination branch, commit them
        # echo "Committing changes to '${DST_BRANCH}':"
        # # git commit -m "Cherry-picking for ${CUST_NAME}"
        # echo ""
        # And finally, push the changes
        # echo "Pushing the changes to 'origin':"
        # git push
        # echo ""

        # # Now we should have a commit hash for the push we just did
        # COMMIT=$(git log -n 1 --format="%H" | xargs)
        # echo -n "Changes under ${COMMIT}: "
        # # Use the revision range to build a list of the objects that have been modified in the merge
        # change_log=$(git log -n 1 ${COMMIT} --pretty=oneline --name-only --reverse)
        # num_changes=$(echo "${change_log}" | wc -l)
        # echo -n "${num_changes} change"
        # if [ "${num_changes}" = 1 ]; then
        #     echo ""
        # else
        #     echo "s"
        # fi

        # echo ""
        # echo "=============================================================================="
        # echo "CHERRY-PICKING SUMMARY  : " $(date)
        # echo "=============================================================================="
        # echo ""

        # # List all the files that were added or modified (not deleted) in alphabetical order
        # cherry_pick_summary_objects=$(cat ${PICK_LIST} | grep -vE "^FIRST_LINE$" | sort | uniq)
        # echo "${cherry_pick_summary_objects}"

        # # Count the files
        # num_files_summary=$(echo "${cherry_pick_summary_objects}" | wc -l)

        # echo ""
        # echo "TOTAL # of files added/modified:  ${num_files_summary}"
        # echo ""
    fi
}

# Define a function that receives a commit hash, and uses this to get a commit range for the changes in that merge commit
function get_range {
    merge_commit="$1"
    rev_range=$(git log -n 1 ${merge_commit} | grep -E ^Merge: | sed 's/^Merge://' | xargs)
    if [ -n "${rev_range}" ]; then
        rev_range=$(echo "${rev_range}" | sed 's/ /../')
        echo "${rev_range}"
    else
        echo ""
    fi
}

# Define a function to determine whether to ignore an object
function ignore_object {
    # Receive the object path as an argument
    obj="$1"
    # Easier to pay attention to certain paths rather than ignore them
    retVal=$(echo "${obj}" | grep -E "^(nxa/|tailored/|database/|app_config/)")
    if [ -n "${retVal}" ]; then
        # We should not ignore this object, return false
        echo "false"
    else
        # Ignore, return true
        echo "true"
    fi
}

# Define a function that receives a commit range, and builds a list of the objects that have been modified in that range
function get_objects {
    commit_range="$1"
    include_hash="$2"
    is_merge="$3"

    # NOTES: regarding the object renames ... when git log lists objects using the --name-only switch any renamed objects will show the new
    # name. When the --name-status switch is used, the lines for renamed objects will begin with an R followed by a number. This number is
    # the percentage similarity between old and new files (ie if no content was changed in the commit, just the file name, then it will be
    # 'R100'). Then the old name of the file, and then the new name.
    # If we enumerate both outputs, we can accurately extract the new name from the --name-only output and use it to filter down to only the
    # old name in the --name-status output. Then, if we add BOTH of these to the change log, the pipeline should accurately detect that the
    # object with the old name needs to be removed

    # Need to reverse the chronological order so that any changes are made in the same order as they were committed
    if [ ${include_hash} = true ]; then
        if [ "${is_merge}" = "true" ]; then
            change_log=$(git log --pretty=oneline --name-only --reverse --no-renames ${commit_range})
            # chng_log_r=`git log --pretty=oneline --name-status --reverse ${commit_range}`
        else
            change_log=$(git log -n 1 ${commit_range} --pretty=oneline --name-only --reverse --no-renames)
            # chng_log_r=`git log -n 1 ${commit_range} --pretty=oneline --name-status --reverse`
        fi
    else
        if [ "${is_merge}" = "true" ]; then
            change_log=$(git log --pretty=oneline --name-only --reverse --no-renames ${commit_range} | grep -vE "^[a-f0-9]{40}")
            # chng_log_r=`git log --pretty=oneline --name-status --reverse ${commit_range} | grep -vE "^[a-f0-9]{40}"`
        else
            change_log=$(git log -n 1 ${commit_range} --pretty=oneline --name-only --reverse --no-renames | grep -vE "^[a-f0-9]{40}")
            # chng_log_r=`git log -n 1 ${commit_range} --pretty=oneline --name-status --reverse | grep -vE "^[a-f0-9]{40}"`
        fi
    fi
    # # Check if there are any renames detected in the logs
    # retVal=`echo "${chng_log_r}" | grep -vE "^[a-f0-9]{40}" | grep -E "^R[0-9]"`
    # if [ -n "${retVal}" ]; then
    #     # There ARE renames
    #     echo "${chng_log_r}" | while read line; do
    #         # Allow any commit hashes to pass unhindered
    #         if [ -n "$(echo "${line}" | grep -E "^[a-f0-9]{40}")" ]; then
    #             echo "${line}"
    #         else
    #             # This line references a file, check if it is a rename
    #             if [ -n "$(echo "${line}" | grep -E "^R[0-9]")" ]; then
    #                 # This IS a rename, separate the old and new
    #                 separate_renames "${line}" "${change_log}"
    #             else
    #                 # Treat this line as a normal add, modify or delete
    #                 echo "${line}" | sed -E "s/^[AMD] *//" | xargs
    #             fi
    #         fi
    #     done
    # else
    #     # No renames, simply return the normal list
    #     echo "${change_log}"
    # fi
    echo "${change_log}"
}

# Define a function that receives a renamed object and a full list, and outputs the old and new
function separate_renames {
    rename_log_entry="$1"
    change_log="$2"
    # Iterate through the (--name-only) change log looking for a line that matches the end of the rename log entry
    echo "${change_log}" | while read log_entry; do
        if [ -n "$(echo "${rename_log_entry}" | grep -E "${log_entry}$")" ]; then
            # We've found the line we are interested in
            # Output the old name first
            echo "${rename_log_entry:0:$((${#rename_log_entry} - ${#log_entry}))}" | sed -E "s/^R[0-9]+//" | xargs
            # Now output the new name
            echo "${log_entry}"
            # No need to keep searching
            break
        fi
    done
}

# Define a function that receives a list of merge commits, and iterates them to build a list of the modified objects
function get_obj_list {
    merge_list="$1"
    is_merge="$2"
    echo "${merge_list}" | while read branch_commit; do
        if [ ${is_merge} = true ]; then
            # Process the commit as a range of commits forming a merge
            commit_range=$(get_range "${branch_commit}")
            # We want the actual commit hashes for each object too, so that we know where to check the repo out to when accessing them
            obj_list_part=$(get_objects "${commit_range}" "true" "true")
        else
            # Process the commit as a direct commit
            obj_list_part=$(get_objects "${branch_commit}" "true" "false")
        fi
        # Iterate through the partial list to extract the commit hashes and pre-pend them to the object reference
        echo "${obj_list_part}" | while read line; do
            # Check if the current line is a commit hash
            if [[ "${line}" =~ ^[a-f0-9]{40} ]]; then
                cur_hash=$(echo "${line}" | awk '{print $1}')
            else
                echo "${cur_hash} ${line}"
            fi
        done
    done
}

# Define a function that receives a list of initial commits and their objects, and outputs a list of objects prepended by their commit
function get_obj_list_init {
    init_list="$1"
    # Iterate through the list
    echo "${init_list}" | while read init_obj; do
        if [[ "${init_obj}" =~ ^[a-f0-9]{40} ]]; then
            cur_hash=$(echo "${init_obj}" | awk '{print $1}')
        else
            echo "${cur_hash} ${init_obj}"
        fi
    done
}

# Define a function that reverts changes to an object
function revert_objects {
    merge_commit="$1"
    objs="$2"
    # To do this we will need to determine the merge commit into the destination branch prior to the commit with the changes
    # Then we checkout the object to that commit. This will result in one of two things:
    #  1) an error saying that the path spec didn't match any files known to git. This means that the object did not exist so we can delete it
    #  2) a message saying that the object has been checked out

    prior_merge=$(git log -n 2 ${merge_commit} --merges --format="%H" | grep -v ${merge_commit} | xargs)
    echo "${objs}" | while read obj; do
        echo -n "Reverting '${obj}' ... "
        restore_object ${prior_merge} "${obj}"
        if [ $? = 0 ]; then
            echo "Done"
        else
            echo "ERROR"
        fi
    done
}

# Define a function that receives a commit hash and an object reference, and returns the mode (create/update/delete)
# This operation is branch agnostic
function get_obj_mode {
    obj_commit="$1"
    obj_path="$2"
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
    esac
    echo "${object_mode}"
}

# Define a function that receives a commit hash, object reference and source branch, and restores that object to the version in the commit
function check_object {
    obj_commit="$1"
    cust_name="$2"
    obj_path="$3"
    obj_branch="$4"
    
    # Generate a glob pattern for branch matching
    branch_glob="[${obj_branch:0:1}]${obj_branch:1}"
    
    # Is the object being deleted, created or modified?
    echo -n "   - Determining the object mode ... "
    obj_mode=`get_obj_mode "${obj_commit}" "${obj_path}"`
    echo "'${obj_mode}'"
    
    # Switch to the branch where the object is being picked from
    # BRANCH SWITCHING IS TIME-INTENSIVE AND NO LONGER REQUIRED IF WE SUPPLY A BRANCH GLOB TO THE GIT LOG COMMAND
    #echo -n "   - "
    #switch_branch "${obj_branch}"
    
    # Generate a list of the commits in which this object appears
    echo -n "   - Listing the commits where the object appears ... "
    obj_appears_in=`git log --format="%H" --branches="${branch_glob}" --follow -- "${obj_path}"`
    echo "Done"
    
    # Switch the branch back to the destination
    # BRANCH SWITCHING IS TIME-INTENSIVE AND NO LONGER REQUIRED IF WE SUPPLY A BRANCH GLOB TO THE GIT LOG COMMAND
    #echo -n "   - "
    #switch_branch "${DST_BRANCH}"
    
    # Get the timestamp for the deployment commit
    echo -n "   - Getting the timestamp for the commit ... "
    deploy_ts=`git log -n 1 "${obj_commit}" --format="%at"`
    echo "${deploy_ts}"
    
    # If we are cherry-picking into the "release" branch, add the object's metadata
    if [ "${DST_BRANCH}" = "release" ]; then
        # Ensure that this object is deployable
        if [ `ignore_object "${obj_path}"` = "false" ]; then
            # To calculate an MD5 checksum, we need to enumerate the object's content
            md5_checksum=`git show "${obj_commit}":"${obj_path}" 2> /dev/null | md5sum`
            # If the object reference was for a delete, then the checksum will match a zero-byte string
            if [ "$(echo -n "" | md5sum)" = "${md5_checksum}" ]; then
                # Empty file, so the mode must be "delete"
                obj_mode="delete"
                md5_checksum=""
            else
                # Strip the trailing "-" from the checksum
                md5_checksum=`echo "${md5_checksum}" | awk '{print $1}'`
            fi
            # Append this object's metadata to the end of its customization's <objects> list
            cust_line_range=`get_metadata_cust_range "${cust_name}"`
            cust_line_range_start=`echo "${cust_line_range}" | cut -d "," -f 1`
            cust_line_range_end=`echo "${cust_line_range}" | cut -d "," -f 2`
            obj_line_no=$(( cust_line_range_end - 1 ))

            # sed -i '/<\/customizations>/i\ \ \ \ \ \ <object>' ${cust_meta}
            # sed -i '/<\/customizations>/i\ \ \ \ \ \ \ \ <name>'"${obj_path}"'<\/name>' ${cust_meta}
            # sed -i '/<\/customizations>/i\ \ \ \ \ \ \ \ <mode>'"${obj_mode}"'<\/mode>' ${cust_meta}
            # sed -i '/<\/customizations>/i\ \ \ \ \ \ \ \ <timestamp>'"${deploy_ts}"'<\/timestamp>' ${cust_meta}
            # if [ -n "${md5_checksum}" ]; then
            #     sed -i '/<\/customizations>/i\ \ \ \ \ \ \ \ <checksum>'"${md5_checksum}"'<\/checksum>' ${cust_meta}
            # fi
            # sed -i '/<\/customizations>/i\ \ \ \ \ \ <\/object>' ${cust_meta}

            sed -i "${obj_line_no}i \ \ \ \ \ \ <object>" ${cust_meta}
            let obj_line_no++
            sed -i "${obj_line_no}i \ \ \ \ \ \ \ \ <name>${obj_path}<\/name>" ${cust_meta}
            let obj_line_no++
            sed -i "${obj_line_no}i \ \ \ \ \ \ \ \ <mode>${obj_mode}<\/mode>" ${cust_meta}
            let obj_line_no++
            sed -i "${obj_line_no}i \ \ \ \ \ \ \ \ <timestamp>${deploy_ts}<\/timestamp>" ${cust_meta}
            let obj_line_no++
            if [ -n "${md5_checksum}" ]; then
                sed -i "${obj_line_no}i \ \ \ \ \ \ \ \ <checksum>${md5_checksum}<\/checksum>" ${cust_meta}
                let obj_line_no++
            fi
            sed -i "${obj_line_no}i \ \ \ \ \ \ <\/object>" ${cust_meta}
        fi
    fi
}

# Define a function that receives a commit hash and object reference, and restores that object to the version in the commit
function restore_object {
    obj_commit="$1"
    obj_path="$2"
    retVal=$(git checkout ${obj_commit} "${obj_path}" 2>/dev/stdout)
    if [[ $? = 1 && "${retVal}" =~ "error: pathspec " && "${retVal}" =~ " did not match any file(s) known to git" ]]; then
        # This object did not exist at the prior merge commit, delete it and stage the change in git
        rm -f "${obj_path}" &&
            retVal=$(git rm -f -q "${obj_path}" 2>/dev/stdout)
        # Remove the object from the pick list
        echo -e "$(cat ${PICK_LIST} | grep -vE "^${obj_path}$")" >${PICK_LIST}
        return 0
    else
        # The object is either being created or modified and will be staged as part of this action
        # Add it to the pick list
        echo "${obj_path}" >>${PICK_LIST}
        return 0
    fi
}

# Define a function that will initialise the current branch with early objects
# It will receive a commit that is to be considered the last commit prior to the customisation branching model being fully implemented.
# Thus, ALL objects (in the non-ignored paths) need to be part of the baseline for the destination branch. This will only need to be applied once
# in the destination branch. Since some actions in the early commits delete and rename files or partial file paths, and some future commits do
# the same, we cannot simply put back every file that is not present from these early commits. The approach here is to first test for each file,
# and if NONE of them exist in the destination branch, then the destination branch is considered to require initialisation.
function initialise_branch {
    init_commit="$1"
    initialisation_list=$(git log "${init_commit}" --pretty="oneline" --name-only --reverse)
    initialisation_list=$(get_obj_list_init "${initialisation_list}")
    # Iterate the initial objects, checking for them as we go
    echo "${initialisation_list}" | while read obj_init; do
        # Extract the commit hash from this reference
        obj_init_hash=$(echo "${obj_init}" | awk '{print $1}' | xargs)
        # Now, extract the path to the object
        obj_init_path=$(echo "${obj_init}" | sed "s/${obj_init_hash}//" | xargs)
        # Use these to check if the object exists
        if [ $(ignore_object "${obj_init_path}") = "false" ]; then
            # There are some other specific ignore cases
            if [[ "${obj_init_path}" != "tailored/extensions/trinoor/TrinoorUtils.groovy" &&
                "${obj_init_path}" != "tailored/extensions/UIExtensions/groovyscripts/systemadministration/timg091/Timg091PreDisplay.groovy" &&
                "${obj_init_path}" != "tailored/extensions/UIExtensions/groovyscripts/systemadministration/timg091/Timg091Validate.groovy" ]]; then
                # OK, check for the object now
                if [ -f "${obj_init_path}" ]; then
                    # Since we have found at least one occurrence of an initial file, flip the boolean
                    #~~ it seems we could use a variable instead of a file to store the boolean? and that we should break out of this loop once we find this one file
                    echo "true" >${INIT_DONE}
                fi
            fi
        fi
    done
    # Check if we detected any of these files
    if [ $(cat ${INIT_DONE}) = false ]; then
        # No files were detected, so we need to initialise the branch
        echo "Initialising '${DST_BRANCH}' with early objects:"
        echo ""
        echo "${initialisation_list}" | while read obj_init; do
            # Extract the commit hash from this reference
            obj_init_hash=$(echo "${obj_init}" | awk '{print $1}' | xargs)
            # Now, extract the path to the object
            obj_init_path=$(echo "${obj_init}" | sed "s/${obj_init_hash}//" | xargs)
            # Deploy the object
            if [ $(ignore_object "${obj_init_path}") = "false" ]; then
                echo -n "   - ${obj_init_path} ... "
                restore_object "${obj_init_hash}" "${obj_init_path}"
                if [ $? = 0 ]; then
                    echo "OK"
                else
                    echo "ERROR"
                fi
            fi
        done
        echo ""
    fi
}

# Define a function to determine the current branch
function get_branch {
    echo `git rev-parse --abbrev-ref HEAD`
}

# Define a function to switch branch
function switch_branch {
    # Receive the branch to switch to as an argument
    SWITCH_TO="$1"
    echo -n "Switching branch ... "
    # Check the current branch
    cur_branch=$(get_branch)
    if [ "${cur_branch}" = "${SWITCH_TO}" ]; then
        echo "Already on '${SWITCH_TO}'"
    else
        # Need to switch the branch
        retVal=$(git checkout "${SWITCH_TO}" 2>/dev/stdout)
        if [ $? = 0 ]; then
            echo "${retVal}"
        else
            echo "Error"
        fi
    fi
}

# Define a function that receives a file name, and returns the location where the file should be staged
function get_doc_location {
    # Receive the document file name as an argument
    file_name="$1"
    # First, determine the root location based on the file name
    if [ -n "$(echo "${file_name}" | tr [A-Z] [a-z] | grep design)" ]; then
        doc_path="documents/Designs/"
    elif [ -n "$(echo "${file_name}" | tr [A-Z] [a-z] | grep test)" ]; then
        doc_path="tests/"
    fi
    # Next, if the customisation name is of the form: "AS9-CUSxx...", where xx is = "FA", "JC" or "NX":
    if [ $(expr match "${CUST_NAME}" 'AS9-CUSFA-') != 0 ]; then
        doc_path="${doc_path}FA/"
    elif [ $(expr match "${CUST_NAME}" 'AS9-CUSJC-') != 0 ]; then
        doc_path="${doc_path}JCL/"
    elif [ $(expr match "${CUST_NAME}" 'AS9-CUSNX-') != 0 ]; then
        doc_path="${doc_path}NXA/"
    else
        # The 3rd part will define the part of the path name
        path_part=$(echo "${CUST_NAME}" | sed -e 's/^AS9-CUS-//' | sed -e 's/-.*//')
        doc_path="${doc_path}${path_part}/"
    fi
    # Add the full customisation name to the path
    doc_path="${doc_path}${CUST_NAME}/"
    # Finally, add the file name to the path ...
    #doc_path="${doc_path}${file_name}"
    # ... and return it to the caller
    echo "${doc_path}"
}

# Define a function to handle the changes
function update_object {
    # Receive the object path as an argument
    obj="$1"
    # Determine the object path and name
    if [[ "${obj}" =~ "app_config/" ]]; then
        obj_full="${AS_PTH2}${obj}"
    else
        obj_full="${AS_PATH}${obj}"
    fi
    obj_path=$(dirname "${obj_full}")
    obj_name=$(basename "${obj_full}")
    # Increment the object count
    echo $(($(cat ${num_objects}) + 1)) >${num_objects}
    # Initialise a boolean to track whether or not to report this object
    blnReportObj=false
    # Also initialise string variables to contain the report elements
    strActionText=""
    strActionSymb=""
    strResultText=""
    strResultSymb=""
    # Determine if we need to exclude the object based on path
    if [ $(ignore_object "${obj}") = "false" ]; then
        # Determine if the object has been added/modified or deleted
        if [ -f "${REPO_DIR}/$obj" ]; then
            # Object exists in repo, therefore change is either addition or modification
            # Check if it already exists on server
            if [ -f "${obj_full}" ]; then
                # It does, so we need to update it
                blnReportObj=true
                strActionText="Updated"
                strActionSymb='<b><font size="4" color="green">&#x270d; </font></b>'
                sudo su asuser -c 'cp -f '${REPO_DIR}'/"'"${obj}"'" "'"${obj_path}"'"/ 2> /dev/null'
                # Check for any errors
                if [ $? != 0 ]; then
                    # The most likely source of errors here is if the ownership or permissions on the existing file do not match 'asuser' and '664'
                    fix_object_perms "${obj_full}"
                    fix_parent_perms "${obj_full}"
                    # Try again
                    sudo su asuser -c 'cp -f '${REPO_DIR}'/"'"${obj}"'" "'"${obj_path}"'"/'
                    if [ $? = 0 ]; then
                        strResultText="Success"
                        strResultSymb='<b><font color="green">&#10003; </font></b>'
                        sed -i "s/STATUS PASS: .*$/STATUS PASS: true/" ${MAIL_HEAD}
                    else
                        strResultText="Failed"
                        strResultSymb='<b><font color="red">&#10007; </font></b>'
                        sed -i "s/STATUS FAIL: .*$/STATUS FAIL: true/" ${MAIL_HEAD}
                    fi
                else
                    strResultText="Success"
                    strResultSymb='<b><font color="green">&#10003; </font></b>'
                    sed -i "s/STATUS PASS: .*$/STATUS PASS: true/" ${MAIL_HEAD}
                fi
                # Set permissions
                if [[ "${obj}" =~ ^app_config/FTP_SCRIPTS/.*\.sh$ ]]; then
                    # Enable the FTP script to be executed
                    sudo su asuser -c 'chmod 755 "'"${obj_full}"'"' &&
                        echo "UPDATED:  ${obj}"
                else
                    sudo su asuser -c 'chmod 664 "'"${obj_full}"'"' &&
                        echo "UPDATED:  ${obj}"
                fi
                # Increment the count of updated objects
                echo $(($(cat ${num_updated}) + 1)) >${num_updated}
                # If this relates to a NextAxiom service, increment that count also
                [[ "${obj}" =~ ^nxa/ ]] && echo $(($(cat ${num_nxa_obj}) + 1)) >${num_nxa_obj}
                # If this relates to a tailored menu, increment that count also
                [[ "${obj}" =~ ^tailored/metadata/runtime/ui/config/MENU/ ]] && echo $(($(cat ${num_mnu_obj}) + 1)) >${num_mnu_obj}
                # If this relates to a batch config, increment that count also
                [[ "${obj}" =~ ^tailored/metadata/runtime/batchconfig/ ]] && echo $(($(cat ${num_bat_obj}) + 1)) >${num_bat_obj}
                # If this relates to a batch extension, increment the batch config count
                [[ "${obj}" =~ ^tailored/extensions/BatchExtensions/ ]] && echo $(($(cat ${num_bat_obj}) + 1)) >${num_bat_obj}
                # If this relates to a resource bundle, increment that count also
                [[ "${obj}" =~ ^tailored/resource_bundles/ ]] && echo $(($(cat ${num_rbs_obj}) + 1)) >${num_rbs_obj}
                # If this relates to a metadata image, increment that count also
                [[ "${obj}" =~ ^tailored/metadata/images/ ]] && echo $(($(cat ${num_img_obj}) + 1)) >${num_img_obj}
                # If this is the 'opg.properties' file, increment that count also
                [[ "${obj}" =~ ^app_config/properties/opg.properties$ ]] && echo $(($(cat ${num_prp_obj}) + 1)) >${num_prp_obj}
            else
                # No, so need to create it - check directory first
                if [ ! -d "${obj_path}" ]; then
                    # Need to create the directory
                    sudo su asuser -c 'mkdir -p "'"${obj_path}"'" -m 775' &&
                        echo "CREATED:  $(dirname ${obj})/"
                fi
                # Only copy file if it is NOT a .gitignore
                if [ "${obj_name}" != ".gitignore" ]; then
                    blnReportObj=true
                    strActionText="Created"
                    strActionSymb='<b><font size="4" color="blue">+</font></b>'
                    sudo su asuser -c 'cp '${REPO_DIR}'/"'"${obj}"'" "'"${obj_path}"'"/ 2> /dev/null'
                    # Check for any errors
                    if [ $? != 0 ]; then
                        # The most likely source of errors here is if the ownership or permissions on the parent folder do not match 'asuser' and '775'
                        fix_parent_perms "${obj_full}"
                        # Try again
                        sudo su asuser -c 'cp '${REPO_DIR}'/"'"${obj}"'" "'"${obj_path}"'"/'
                        if [ $? = 0 ]; then
                            strResultText="Success"
                            strResultSymb='<b><font color="green">&#10003; </font></b>'
                            sed -i "s/STATUS PASS: .*$/STATUS PASS: true/" ${MAIL_HEAD}
                        else
                            strResultText="Failed"
                            strResultSymb='<b><font color="red">&#10007; </font></b>'
                            sed -i "s/STATUS FAIL: .*$/STATUS FAIL: true/" ${MAIL_HEAD}
                        fi
                    else
                        strResultText="Success"
                        strResultSymb='<b><font color="green">&#10003; </font></b>'
                        sed -i "s/STATUS PASS: .*$/STATUS PASS: true/" ${MAIL_HEAD}
                    fi
                    # Set permissions
                    if [[ "${obj}" =~ ^app_config/FTP_SCRIPTS/.*\.sh$ ]]; then
                        # Enable the FTP script to be executed
                        sudo su asuser -c 'chmod 755 "'"${obj_full}"'"' &&
                            echo "CREATED:  ${obj}"
                    else
                        sudo su asuser -c 'chmod 664 "'"${obj_full}"'"' &&
                            echo "CREATED:  ${obj}"
                    fi
                    # Increment the count of created objects
                    echo $(($(cat ${num_created}) + 1)) >${num_created}
                    # If this relates to a NextAxiom service, increment that count also
                    [[ "${obj}" =~ ^nxa/ ]] && echo $(($(cat ${num_nxa_obj}) + 1)) >${num_nxa_obj}
                    # If this relates to a tailored menu, increment that count also
                    [[ "${obj}" =~ ^tailored/metadata/runtime/ui/config/MENU/ ]] && echo $(($(cat ${num_mnu_obj}) + 1)) >${num_mnu_obj}
                    # If this relates to a batch config, increment that count also
                    [[ "${obj}" =~ ^tailored/metadata/runtime/batchconfig/ ]] && echo $(($(cat ${num_bat_obj}) + 1)) >${num_bat_obj}
                    # If this relates to a batch extension, increment the batch config count
                    [[ "${obj}" =~ ^tailored/extensions/BatchExtensions/ ]] && echo $(($(cat ${num_bat_obj}) + 1)) >${num_bat_obj}
                    # If this relates to a resource bundle, increment that count also
                    [[ "${obj}" =~ ^tailored/resource_bundles/ ]] && echo $(($(cat ${num_rbs_obj}) + 1)) >${num_rbs_obj}
                    # If this relates to a metadata image, increment that count also
                    [[ "${obj}" =~ ^tailored/metadata/images/ ]] && echo $(($(cat ${num_img_obj}) + 1)) >${num_img_obj}
                    # If this is the 'opg.properties' file, increment that count also
                    [[ "${obj}" =~ ^app_config/properties/opg.properties$ ]] && echo $(($(cat ${num_prp_obj}) + 1)) >${num_prp_obj}
                else
                    # Increment the count of ignored objects
                    echo $(($(cat ${num_ignored}) + 1)) >${num_ignored}
                fi
            fi
        else
            # Object appears to have been deleted, remove it from the target location
            if [ -f "${obj_full}" ]; then
                blnReportObj=true
                strActionText="Deleted"
                strActionSymb='<b><font size="3" color="red">&#x229d; </font></b>'
                sudo rm -f "${obj_full}"
                if [ $? = 0 ]; then
                    strResultText="Success"
                    strResultSymb='<b><font color="green">&#10003; </font></b>'
                    sed -i "s/STATUS PASS: .*$/STATUS PASS: true/" ${MAIL_HEAD}
                else
                    strResultText="Failed"
                    strResultSymb='<b>font color="red">&#10007; </font></b>'
                    sed -i "s/STATUS FAIL: .*$/STATUS FAIL: true/" ${MAIL_HEAD}
                fi
                echo "DELETED:  ${obj}"
                # Increment the count of deleted objects
                echo $(($(cat ${num_deleted}) + 1)) >${num_deleted}
                # If this relates to a NextAxiom service, increment that count also
                [[ "${obj}" =~ ^nxa/ ]] && echo $(($(cat ${num_nxa_obj}) + 1)) >${num_nxa_obj}
                # If this relates to a tailored menu, increment that count also
                [[ "${obj}" =~ ^tailored/metadata/runtime/ui/config/MENU/ ]] && echo $(($(cat ${num_mnu_obj}) + 1)) >${num_mnu_obj}
                # If this relates to a batch config, increment that count also
                [[ "${obj}" =~ ^tailored/metadata/runtime/batchconfig/ ]] && echo $(($(cat ${num_bat_obj}) + 1)) >${num_bat_obj}
                # If this relates to a batch extension, increment the batch config count
                [[ "${obj}" =~ ^tailored/extensions/BatchExtensions/ ]] && echo $(($(cat ${num_bat_obj}) + 1)) >${num_bat_obj}
                # If this relates to a resource bundle, increment that count also
                [[ "${obj}" =~ ^tailored/resource_bundles/ ]] && echo $(($(cat ${num_rbs_obj}) + 1)) >${num_rbs_obj}
                # If this relates to a metadata image, increment that count also
                [[ "${obj}" =~ ^tailored/metadata/images/ ]] && echo $(($(cat ${num_img_obj}) + 1)) >${num_img_obj}
                # If this is the 'opg.properties' file, increment that count also
                [[ "${obj}" =~ ^app_config/properties/opg.properties$ ]] && echo $(($(cat ${num_prp_obj}) + 1)) >${num_prp_obj}
            fi
        fi
    else
        # Increment the count of ignored objects
        echo "IGNORED:  ${obj}"
        #num_ignored=$((num_ignored+1))
        echo $(($(cat ${num_ignored}) + 1)) >${num_ignored}
    fi
    # Check the status of the object reportability
    if [ ${blnReportObj} = true ]; then
        # Check if this is the first time we are processing a reportable result
        if [ "$(cat ${MAIL_SEND})" = "false" ]; then
            # Begin construction of the table
            echo '<table id="results" style="border-collapse:collapse;border-left:2px solid #CCCCCC;border-top:2px solid #CCCCCC;border-bottom:5px outset #F4F4F4;border-right:5px outset #F4F4F4;">' >>${MAIL_BODY}
            echo '<tr style="border-bottom:2px solid #DDDDDD;">' >>${MAIL_BODY}
            echo '<th style="padding:'${strPad}';" onclick="sortTable(0)">Action</th>' >>${MAIL_BODY}
            echo '<th style="padding:'${strPad}';" onclick="sortTable(1)">Object</th>' >>${MAIL_BODY}
            echo '<th style="padding:'${strPad}';" onClick="sortTable(2)">Result</th>' >>${MAIL_BODY}
            echo "</tr>" >>${MAIL_BODY}
            # Initialise a boolean variable to indicate whether the current row is odd (TRUE) or even (FALSE)
            blnOddRow=true
            # Flip the report boolean so this only runs once
            echo "true" >${MAIL_SEND}
        fi

        # Determine the background colour for this row and flip the boolean
        if [ ${blnOddRow} = true ]; then
            rowColour="#F1F1F1"
            blnOddRow=false
        else
            rowColour="#FFFFFF"
            blnOddRow=true
        fi
        # Add a new row to the email results table
        echo '<tr style="background-color:'${rowColour}'";border-bottom:1px solid #DDDDDD;">' >>${MAIL_BODY}
        # Add the action
        echo '<td style="padding:'${strPad}';" title="'${strActionText}'"><span>'${strActionSymb}'</span></td>' >>${MAIL_BODY}
        # Add the object
        echo '<td style="padding:'${strPad}';" title="'"${obj_full}"'"><span>'"${obj_name}"'</span></td>' >>${MAIL_BODY}
        # Add the result
        echo '<td style="padding:'${strPad}';" title="'${strResultText}'"><span>'${strResultSymb}'</span></td>' >>${MAIL_BODY}
        # Close the row
        echo "</tr>" >>${MAIL_BODY}
    fi
}

# Define a function to receive a permissions string and return a numeric value representing the permission combination
function get_perm {
    perm="$1"
    case "${perm}" in
    "---")
        echo "0"
        ;;
    "--x")
        echo "1"
        ;;
    "-w-")
        echo "2"
        ;;
    "-wx")
        echo "3"
        ;;
    "r--")
        echo "4"
        ;;
    "r-x")
        echo "5"
        ;;
    "rw-")
        echo "6"
        ;;
    "rwx")
        echo "7"
        ;;
    esac
}

# Define a function that receives a string and returns a regular expression handling case insensitivity
function either_case {
    # Receive the input string as an argument
    u_case_string="$1"
    # Initialise an output string
    no_case_string=""
    # Calculate the number of characters in the input string
    num_chars=${#u_case_string}
    # Subtract 1 to get the index of the last character
    last_char=$((num_chars - 1))
    for char in $(eval echo {0..$last_char}); do
        no_case_string="${no_case_string}[${u_case_string:char:1}"$(eval echo ${u_case_string:char:1} | tr [A-Z] [a-z])"]"
    done
    # Return the output to the caller
    echo "${no_case_string}"
}

# Define a function that receives a numeric sequence string and returns a regular expression handling leading zeros
function leading_zeros {
    # Receive the input string as an argument
    numeric_string="$1"
    # Initialise an output string
    zero_corrected=""
    # Determine if there are leading zeros
    zeros_in_front=$(echo "${numeric_string}" | grep -Eo "^0*")
    num_zeros=${#zeros_in_front}
    [[ ${num_zeros} > 0 ]] &&
        zero_corrected="[0]{0,${num_zeros}}"$(echo "${numeric_string}" | sed "s/${zeros_in_front}//") ||
        zero_corrected="${numeric_string}"
    # Return the output to the caller
    echo "${zero_corrected}"
}

# Define a function to handle changes to the 'opg.properties' file
function update_properties_file {
    # Receive the action as an argument
    prop_update_action="$1"
    # Initialise boolean variables to track the parameter updation statuses (assume FALSE until TRUE)
    soap_url_update=false
    soap_user_update=false
    soap_pass_update=false
    soap_utxt_update=false
    soap_ptxt_update=false
    soap_parm_update=false
    # Check the action
    if [ "${prop_update_action}" = "check" ]; then
        echo "Checking 'opg.properties' parameters:"
        # Read in the current values of the SOAP parameters
        soap_url=$(cat "${AS_PTH2}app_config/properties/opg.properties" | grep -E ^soapconnection.soapendpointurl= | sed -E 's/^soapconnection.soapendpointurl=//')
        soap_user=$(cat "${AS_PTH2}app_config/properties/opg.properties" | grep -E ^soapconnection.userID= | sed -E 's/^soapconnection.userID=//')
        soap_pass=$(cat "${AS_PTH2}app_config/properties/opg.properties" | grep -E ^soapconnection.passwd= | sed -E 's/^soapconnection.passwd=//')
        soap_utxt=$(cat "${AS_PTH2}app_config/properties/opg.properties" | grep -E ^soapconnection.userIDText= | sed -E 's/^soapconnection.userIDText=//')
        soap_ptxt=$(cat "${AS_PTH2}app_config/properties/opg.properties" | grep -E ^soapconnection.passwdText= | sed -E 's/^soapconnection.passwdText=//')
        # Compare the parameter values with our pipeline parameters
        echo -n "   - SOAP Endpoint URL ... "
        if [ "${soap_url}" = "http://${AS9_REGION}:8080/as/fa/NextAxiomServer" ]; then
            echo "OK"
        else
            echo "Needs update"
            soap_url_update=true
            soap_parm_update=true
        fi
        echo -n "   - SOAP User ID ... "
        if [ "${soap_user}" = "${AS_SOAP_USER}" ]; then
            echo "OK"
        else
            echo "Needs update"
            soap_user_update=true
            soap_parm_update=true
        fi
        echo -n "   - SOAP Password ... "
        if [ "${soap_pass}" = "${AS_SOAP_PASS}" ]; then
            echo "OK"
        else
            echo "Needs update"
            soap_pass_update=true
            soap_parm_update=true
        fi
        echo -n "   - SOAP User ID Text ... "
        if [ "${soap_utxt}" = "${AS_SOAP_UTXT}" ]; then
            echo "OK"
        else
            echo "Needs update"
            soap_utxt_update=true
            soap_parm_update=true
        fi
        echo -n "   - SOAP Password Text ... "
        if [ "${soap_ptxt}" = "${AS_SOAP_PTXT}" ]; then
            echo "OK"
        else
            echo "Needs update"
            soap_ptxt_update=true
            soap_parm_update=true
        fi
    fi
    if [[ "${prop_update_action}" = "update" || "${soap_parm_update}" = "true" ]]; then
        # Either the opg.properties file has been updated via a merged pull request, or one of the SOAP parameters in this file
        # has not matched the secured pipeline parameters
        echo "Updating 'opg.properties' parameters:"
        if [[ "${prop_update_action}" = "update" || "${soap_url_update}" = "true" ]]; then
            echo -n "   - SOAP Endpoint URL ... "
            sudo su asuser -c 'sed -i "s/^soapconnection.soapendpointurl=.*$/soapconnection.soapendpointurl=http:\/\/'${AS9_REGION}':8080\/as\/fa\/NextAxiomServer/" "'"${AS_PTH2}"'app_config/properties/opg.properties"' && echo "Done" || echo "Error"
        fi
        if [[ "${prop_update_action}" = "update" || "${soap_user_update}" = "true" ]]; then
            echo -n "   - SOAP User ID ... "
            sudo su asuser -c 'sed -i "s/^soapconnection.userID=.*$/soapconnection.userID='"$(echo ${AS_SOAP_USER} | sed 's/\//\\\//g')"'/" "'"${AS_PTH2}"'app_config/properties/opg.properties"' && echo "Done" || echo "Error"
        fi
        if [[ "${prop_update_action}" = "update" || "${soap_pass_update}" = "true" ]]; then
            echo -n "   - SOAP Password ... "
            sudo su asuser -c 'sed -i "s/^soapconnection.passwd=.*$/soapconnection.passwd='"$(echo ${AS_SOAP_PASS} | sed 's/\//\\\//g')"'/" "'"${AS_PTH2}"'app_config/properties/opg.properties"' && echo "Done" || echo "Error"
        fi
        if [[ "${prop_update_action}" = "update" || "${soap_utxt_update}" = "true" ]]; then
            echo -n "   - SOAP User ID Text ... "
            sudo su asuser -c 'sed -i "s/^soapconnection.userIDText=.*$/soapconnection.userIDText='"$(echo ${AS_SOAP_UTXT} | sed 's/\//\\\//g')"'/" "'"${AS_PTH2}"'app_config/properties/opg.properties"' && echo "Done" || echo "Error"
        fi
        if [[ "${prop_update_action}" = "update" || "${soap_ptxt_update}" = "true" ]]; then
            echo -n "   - SOAP Password Text ... "
            sudo su asuser -c 'sed -i "s/^soapconnection.passwdText=.*$/soapconnection.passwdText='"$(echo ${AS_SOAP_PTXT} | sed 's/\//\\\//g')"'/" "'"${AS_PTH2}"'app_config/properties/opg.properties"' && echo "Done" || echo "Error"
        fi
    fi
    # If any of the individual SOAP parameters have been updated at this point because they don't match, increment the counter
    if [ "${soap_parm_update}" = "true" ]; then
        echo $(($(cat ${num_prp_obj}) + 1)) >${num_prp_obj}
    fi
}

# Define a function to check that there is an 'rdcs' directory present for each NextAxiom service
function check_rdcs {
    echo -n "Checking 'rdcs' directories for each NxA service"
    blnRDCS=false
    # Define the path to the NextAxiom service accounts
    NXA_SVC_ROOT="${AS_PATH}nxa/SREData/MetaDataMgr/FileMgr/accounts/"
    # Test for this path
    if [ -d "${NXA_SVC_ROOT}" ]; then
        # Capture the current path
        PRE_NXA_DIR=$(pwd)
        # Switch to the root path
        cd "${NXA_SVC_ROOT}"
        for nxa_path in $(ls -d */); do
            # Check if there is an "rdcs" directory present
            checkPath=$(ls "${nxa_path}" | grep ^rdcs$)
            if [ -z "${checkPath}" ]; then
                # There is at least one rdcs folder to create
                if [ ${blnRDCS} = "false" ]; then
                    # Flip the boolean
                    blnRDCS=true
                    echo ":"
                fi
                echo -n "   - Creating '${NXA_SVC_ROOT}${nxa_path}rdcs' ... "
                # Read the permissions on the parent folder
                dir_perms=$(getfacl "${nxa_path}")
                # Start with the user permissions
                u_perm=$(echo "${dir_perms}" | grep ^user | sed 's/^user:://')
                u_perm=$(get_perm "${u_perm}")
                # Add the group permissions
                g_perm=$(echo "${dir_perms}" | grep ^group | sed 's/^group:://')
                g_perm=$(get_perm "${g_perm}")
                # Finish with the other permissions
                o_perm=$(echo "${dir_perms}" | grep ^other | sed 's/^other:://')
                o_perm=$(get_perm "${o_perm}")
                # Compile these
                perms="${u_perm}${g_perm}${o_perm}"
                # Create the path and test it
                sudo su - asuser -c "mkdir -p --mode=${perms} ${NXA_SVC_ROOT}${nxa_path}rdcs" && echo "Done"
            fi
        done
        # If nothing was done ...
        if [ ${blnRDCS} = "false" ]; then
            echo " ... Done"
        fi
        # Switch back to the original directory
        cd "${PRE_NXA_DIR}"
        unset -v PRE_NXA_DIR
    else
        echo "NO services present"
    fi
    echo ""
}

# Define a function to check for and correct permission issues on an object
function fix_object_perms {
    # Receive the object path as an argument
    tmpObj="$1"
    retVal=$(sudo su asuser -c 'ls -al "'"${tmpObj}"'"')
    ownVal=$(echo "${retVal}" | awk '{print $3,$4}')
    prmVal=$(echo "${retVal}" | awk '{print $1}')
    # Check the ownership
    if [ "${ownVal}" != "asuser asuser" ]; then
        # The owner must be changed before we can proceed
        sudo chown asuser:asuser "${tmpObj}"
    fi
    # Check the permissions
    if [ "${prmVal}" != "-rw-rw-r--." ]; then
        # Update the permissions also
        sudo chmod 664 "${tmpObj}"
    fi
}

# Define a function to check for and correct permission issues on an object's parent directory
function fix_parent_perms {
    # Receive the object path as an argument
    tmpObj="$1"
    # Get the object's parent directory
    parDir=$(dirname "${tmpObj}")
    retVal=$(sudo su asuser -c 'ls -al "'"${parDir}"'" | grep " \.$"')
    ownVal=$(echo "${retVal}" | awk '{print $3,$4}')
    prmVal=$(echo "${retVal}" | awk '{print $1}')
    # Check the ownership
    if [ "${ownVal}" != "asuser asuser" ]; then
        # The owner must be changed before we can proceed
        sudo chown asuser:asuser "${parDir}"
    fi
    # Check the permissions
    if [ "${prmVal}" != "drwxrwxr-x." ]; then
        # Update the permissions also
        sudo chmod 775 "${parDir}"
    fi
}

# Define a function that receives a customisation name, and removes all metadata for that customisation
function rem_cust_metadata {
    cust_to_rem="$1"
    # First, check if there is any metadata for this customisation in the metadata file
    retVal=$(cat "${cust_meta}" | grep -E '^ +<customization id="'${cust_to_rem}'">$')
    if [ -n "${retVal}" ]; then
        # The customisation IS present in the metadata, remove it
        new_cust_metadata=$(rem_cust_from_metadata "${cust_to_rem}")
        # Rewrite the metadata file with the new version
        if [ -n "${new_cust_metadata}" ]; then
            echo "${new_cust_metadata}" >$cust_meta
        fi
    fi
}

# Define a function that receives a customisation name, and processes the removal returning a multiline string
function rem_cust_from_metadata {
    cust_to_rem="$1"
    # Define a boolean variable to track the customisation block
    blnInCust=false
    cat "${cust_meta}" | while read; do
        # Check if we are in a customisation block
        if [ "${blnInCust}" = "true" ]; then
            # We are in the block, the only thing that will get us out is if the line is: "  </customization>"
            if [ "${REPLY}" = "  </customization>" ]; then
                # Flip the tracking boolean
                blnInCust=false
            fi
        else
            # We are not in the block but this might be the first line, check it
            if [ "${REPLY}" = '  <customization id="'${cust_to_rem}'">' ]; then
                # Set the tracking boolean and ignore this line
                blnInCust=true
            else
                echo "${REPLY}"
            fi
        fi
    done
}

function complete_email_table {
    # Close the table
    echo "</table>" >>${MAIL_BODY}
    # Add the script that will containt the 'sortTable' function
    echo '<script type="text/javascript">' >>${MAIL_BODY}
    echo 'function sortTable(n) {' >>${MAIL_BODY}
    echo '  var table, rows, switching, i, x, y, shouldSwitch, dir, switchcount = 0;' >>${MAIL_BODY}
    echo '  table = document.getElementById("results");' >>${MAIL_BODY}
    echo '  switching = true;' >>${MAIL_BODY}
    echo '  dir = "asc";' >>${MAIL_BODY}
    echo '  while (switching) {' >>${MAIL_BODY}
    echo '    switching = false;' >>${MAIL_BODY}
    echo '    rows = table.rows;' >>${MAIL_BODY}
    echo '    for (i = 1; i < (rows.length - 1); i++) {' >>${MAIL_BODY}
    echo '      shouldSwitch = false;' >>${MAIL_BODY}
    echo '      x = rows[i].getElementsByTagName("td")[n];' >>${MAIL_BODY}
    echo '      y = rows[i + 1].getElementsByTagName("td")[n];' >>${MAIL_BODY}
    echo '      if (dir == "asc") {' >>${MAIL_BODY}
    echo '        if (x.innerHTML.toLowerCase() > y.innerHTML.toLowerCase()) {' >>${MAIL_BODY}
    echo '          shouldSwitch = true;' >>${MAIL_BODY}
    echo '          break;' >>${MAIL_BODY}
    echo '        }' >>${MAIL_BODY}
    echo '      } else if (dir == "desc") {' >>${MAIL_BODY}
    echo '        if (x.innerHTML.toLowerCase() < y.innerHTML.toLowerCase()) {' >>${MAIL_BODY}
    echo '          shouldSwitch = true;' >>${MAIL_BODY}
    echo '          break;' >>${MAIL_BODY}
    echo '        }' >>${MAIL_BODY}
    echo '      }' >>${MAIL_BODY}
    echo '    }' >>${MAIL_BODY}
    echo '    if (shouldSwitch) {' >>${MAIL_BODY}
    echo '      rows[i].parentNode.insertBefore(rows[i + 1], rows[i]);' >>${MAIL_BODY}
    echo '      switching = true;' >>${MAIL_BODY}
    echo '      switchcount++;' >>${MAIL_BODY}
    echo '    } else {' >>${MAIL_BODY}
    echo '      if (switchcount == 0 && dir == "asc") {' >>${MAIL_BODY}
    echo '        dir = "desc";' >>${MAIL_BODY}
    echo '        switching = true;' >>${MAIL_BODY}
    echo '      }' >>${MAIL_BODY}
    echo '    }' >>${MAIL_BODY}
    echo '  }' >>${MAIL_BODY}
    echo '}' >>${MAIL_BODY}
    echo '</script>' >>${MAIL_BODY}
    # Finalise the HTML block
    echo "</div></p></body></html>" >>${MAIL_BODY}
}

# Define a function to get the last cherry pick of a customization into a branch
function get_last_pick {
    cust_pattern="$1"
    target_branch="$2"
    search_before="$3"

    # Determine the minimum number of objects to have been changed for a valid "successful" cherry-pick
    # For release, we need more than 2 objects to be changed, for test we need more than 1, and we'll default to 1
    min_files_changed=1
    if [ "${target_branch}" = "release" ]; then
        min_files_changed=2
    fi

    # For the purpose of updating, see if we need to search for the last pick before a certain timestamp
    if [ -n "${search_before}" ]; then
        # create a --before option using the timestamp
        before_opt="--before=\"${search_before}\""
    fi

    # Find the last Maurice Moss "Cherry-picking for" commit that changed more than 1 (for test) object or more than 2 (for release)
    # Limit the search to 10 results for efficiency's sake. It's unlikely that there will be 10 consecutive invalid cherry-picks
    # This will return a list of commits in the form of:
    #  epoch_time   commit_hash file_changes
    last_pick=$(git log -10 ${before_opt} --shortstat "origin/${target_branch}" --grep="^Cherry-picking for ${cust_pattern}" --pretty="%at%x09%h" |
        sed ':a;N;$!ba;s/\n\n /\t/g' |
        awk -F ' ' '{if ($3 > '${min_files_changed}') {print $1 " " $2 " " $3}}' |
        head -1)
    last_pick=($last_pick)
    last_pick_time=${last_pick[0]}
    last_pick_hash=${last_pick[1]}
    last_pick_objs=${last_pick[2]}

    # There could be a several hour gap between when Maurice Moss' commit is picked and when it was triggered, during which time
    # more code could have been committed. so we need to find the "Merged in" commit that triggered the cherry-pick. This will
    # be the most recent commit before the above commit
    last_merge=$(git log -1 "origin/${target_branch}" --grep="^Merged in ${cust_pattern}" --pretty="%at%x09%h" --before="${last_pick_time}")
    last_merge=($last_merge)
    last_merge_time=${last_merge[0]}
    last_merge_hash=${last_merge[1]}

    # Make sure we found a valid result that contains a last_merge_time, a last_merge_hash, and an integer number of objects greater than the minimum
    if [ -n "${last_merge_time}" ] && [ -n "${last_merge_hash}" ] && [ -n "${last_pick_objs}" ] && [ "${last_pick_objs}" -gt "${min_files_changed}" ]; then
        echo "${last_merge_time} ${last_merge_hash} ${last_pick_objs}"
    fi

    return 1
}

# Define a function to accept a customization and return the line range where it is found in the metadata file in the format `start_line,end_line`
function get_metadata_cust_range {
    cust_name="${1}"

    # Get the line number of the first line of the customization in the metadata file
    cust_start_line=`awk '/<customization id="'"${cust_name}"'">/ { print NR }' "${cust_meta}"`

    # Get the first </customization> tag after the customization if it exists
    if [ "${cust_start_line}" -eq "${cust_start_line}" ] 2>/dev/null; then
        cust_end_line=`awk '/<\/customization>/ { if (NR > '$cust_start_line') { print NR ; exit } }' ${cust_meta}`
        echo "${cust_start_line},${cust_end_line}"
        return 0
    fi

    # If we get here, the customization was not found in the metadata file
    return 1
}

# Define a function that accepts a customization and an object and returns the line range where the object is found in the metadata file in the format `start_line,end_line`
function get_metadata_object_range {
    cust_name="${1}"
    obj_name="${2}"

    # Get the customization range
    cust_range=`get_metadata_cust_range "${cust_name}"`
    cust_range_start=`echo "${cust_range}" | cut -d',' -f1`
    cust_range_end=`echo "${cust_range}" | cut -d',' -f2`

    if [ -n "$cust_range" ]; then
        # Get the line number of the first line of the object in the metadata file inside the customization range
        obj_line_name="        <name>${obj_name}</name>"
        obj_line_name=`awk -v obj_name="${obj_line_name}" '$0 == obj_name { if (NR > '$cust_range_start' && NR < '$cust_range_end') { print NR ; exit } }' "${cust_meta}"`
        if [ "${obj_line_name}" -eq "${obj_line_name}" ] 2>/dev/null; then
            # We found the object, so go ahead and set the line numbers
            obj_line_start=$(( obj_line_name - 1 ))
            # obj_line_mode=$(( obj_line_start + 2 ))
            # obj_line_ts=$(( obj_line_start + 3 ))
            # obj_line_checksum=$(( obj_line_start + 4 ))
            obj_line_end=$(( obj_line_start + 5 ))
            echo "${obj_line_start},${obj_line_end}"
            return 0
        fi
    fi

    # If we get here, the object was not found in the metadata file
    return 1
}

#==================  SCRIPT EXECUTION BEGINS  =====================================================

# Call the main routine
Main
