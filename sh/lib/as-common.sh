LIB_DIR="${LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}"

# Load dependencies
source "${LIB_DIR}/git.sh"
source "${LIB_DIR}/debug.sh"
source "${LIB_DIR}/text.sh"

## Default values
[[ -z "${FEATURE_PATTERN}" ]] && FEATURE_PATTERN="AS9-[A-Z]{3,5}-[A-Z]{0,5}-[0-9]{0,4}"
[[ -z "${RELEASE_PATTERN}" ]] && RELEASE_PATTERN="{{feature}} Release"
[[ -z "${MERGE_PATTERN}" ]] && MERGE_PATTERN="Merged in {{feature}} .*"
[[ -z "${CHERRY_PICK_PATTERN}" ]] && CHERRY_PICK_PATTERN="Cherry-picking for {{feature}}"

# Load the above values from this project's config file if present
## look, in order, for:
## - an AS_CONFIG environment variable
## - a config file in {repo}/devops
## - a config file in the repo root (assuming we are in a repo)
## - a config file in the current directory
if [[ -z "${AS_CONFIG}" ]]; then
    __AS_CONFIG_VAR="${AS_CONFIG}"
    __AS_CONFIG_DEVOPS=$(
        git rev-parse --is-inside-work-tree &>/dev/null &&
            root=$(git rev-parse --show-toplevel 2>/dev/null) &&
            echo "${root}/devops/.as-config.sh"
    )
    __AS_CONFIG_GIT=$(
        git rev-parse --is-inside-work-tree &>/dev/null &&
            root=$(git rev-parse --show-toplevel 2>/dev/null) &&
            echo "${root}/.as-config.sh"
    )
    __AS_CONFIG_FILE="./.as-config.sh"
    AS_CONFIG="${__AS_CONFIG_VAR:-${__AS_CONFIG_DEVOPS:-${__AS_CONFIG_GIT:-${__AS_CONFIG_FILE}}}}"
fi
if [[ -f "${AS_CONFIG}" && -r "${AS_CONFIG}" ]]; then
    source "${AS_CONFIG}"
fi

# @description Generate a feature release commit message
# @usage generate-release-message <feature-name>
function generate-release-message() {
    local feature_name="${1}"
    if [[ -z "${feature_name}" ]]; then
        echo "usage: generate-release-message <feature-name>"
        return 1
    fi

    local release_message="${RELEASE_PATTERN}"
    release_message="${release_message//\{\{feature\}\}/${feature_name}}"
    echo "${release_message}"
}

# @description Generate a cherry-pick commit message
# @usage generate-cherry-pick-message <feature-name>
function generate-pick-message() {
    local feature_name="${1}"
    if [[ -z "${feature_name}" ]]; then
        echo "usage: generate-pick-message <feature-name>"
        return 1
    fi

    local cherry_pick_message="${CHERRY_PICK_PATTERN}"
    cherry_pick_message="${cherry_pick_message//\{\{feature\}\}/${feature_name}}"
    echo "${cherry_pick_message}"
}

# @description Generate a merge commit message
# @usage generate-merge-message <feature-name>
function generate-merge-message() {
    local feature_name="${1}"
    if [[ -z "${feature_name}" ]]; then
        echo "usage: generate-merge-message <feature-name>"
        return 1
    fi

    local merge_message="${MERGE_PATTERN}"
    merge_message="${merge_message//\{\{feature\}\}/${feature_name}}"
    echo "${merge_message}"
}

# @description Reduce a branch flow file to single lines
# @usage _normalize_branch_flow <branch-flow-file>
# @usage echo "${branch_flow}" | _normalize_branch_flow
function _normalize_branch_flow() {
    local branch_flow_file="${1:-/dev/stdin}"

    cat "${branch_flow_file}" \
        | sed -e 's/;/\n/g;s/\]/]\n/g' \
        | awk '{
            if ($0 ~ /->/) {
                # If the line contains a "->", remove space around it and quotes
                # around the branches
                source_branch = $0
                gsub(/\s+->\s+.*/, "", source_branch)
                gsub(/^\s*/, "", source_branch)
                gsub(/"/, "", source_branch)

                target_branch = $0
                gsub(/.*->\s+/, "", target_branch)
                gsub(/\s+.*$/, "", target_branch)
                gsub(/"/, "", target_branch)

                eol = $0
                gsub(/.*->\s+[^ ;]+/, "", eol)
                gsub(/^\s*/, "", eol)
                gsub(/\s*$/, "", eol)

                $0 = source_branch " -> " target_branch " " eol
            } else {
                # Just remove leading/trailing whitespace
                gsub(/^\s*/, "", $0)
                gsub(/\s*$/, "", $0)
            }
            if ($0 == "") {
                next
            } else if ($0 ~ /\[/ && $0 !~ /]/) {
                in_multiline = 1
                printf "%s", $0
            } else if ($0 ~ /]/ && in_multiline) {
                in_multiline = 0
                print $0
            } else if (in_multiline) {
                printf "%s", $0
            } else {
                print $0
            }
        }'
}

# @description Convert a branch flow file to a digraph file
# @usage branch-flow-to-digraph <branch-flow-file>
function branch-flow-to-digraph() {
    local branch_flow_file="${1}"
    local flow_content
    local line_regex="([^ ]+) -> ([^ ]+)( +)?(.*)?"

    if [[ "${branch_flow_file}" == "-" ]]; then
        branch_flow_file="/dev/stdin"
    fi

    if [[ -z "${branch_flow_file}" ]]; then
        echo "usage: branch-flow-to-digraph <branch-flow-file>"
        return 1
    fi

    flow_content=$(
        _normalize_branch_flow "${branch_flow_file}" \
            | sed -E 's/^([[:space:]]*)\*([[:space:]]+)/\1node\2/'
    )

    echo "digraph G {"
    echo "  node [shape=box, fontname=Arial];"
    while read -r line; do
        # If the line contains a "->", then it's a branch flow line, so
        # extract the source and target branches and quote them
        if [[ "${line}" =~ ${line_regex} ]]; then
            source_branch="${BASH_REMATCH[1]}"
            target_branch="${BASH_REMATCH[2]}"
            eol="${BASH_REMATCH[4]}"
            printf '  "%s" -> "%s"' "${source_branch}" "${target_branch}"
            [[ -n "${eol}" ]] && printf ' %s' "${eol}"
            echo
        else
            # Otherwise, just print the line
            echo "  ${line}"
        fi
    done <<< "${flow_content}"
    echo "}"
}

# @description Convert a branch flow file to an image (requires graphviz)
# @usage branch-flow-to-image <branch-flow-file> <image-file>
function branch-flow-to-image() {
    local branch_flow_file="${1}"
    local image_file="${2:-/dev/stdout}"
    local extension digraph

    if [[ -z "${branch_flow_file}" || -z "${image_file}" ]]; then
        echo "usage: branch-flow-to-image <branch-flow-file> <image-file>"
        return 1
    fi

    extension="${image_file##*.}"
    [[ "${extension}" == "${image_file}" ]] && extension="svg"
    digraph=$(
        branch-flow-to-digraph "${branch_flow_file}" \
            | sed -E 's/cherrypick="?true"?/cherrypick="true", style="dashed"/g' \
            | grep -Fv ' -> "*"'
    )

    echo "${branch_flow_file} -> ${image_file}"
    echo "${digraph}" | dot -T"${extension}" -o "${image_file}"
}

# @description Get the parent branches for a given branch
# @usage get-parent-branches [-f <flow-file>] <branch-name>
function get-parent-branches() {
    local branch_name
    local flow_file="./branches.gv"

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -f | --flow-file)
                flow_file="${2}"
                shift 2
                ;;
            -*)
                echo "error: unknown option: ${1}" >&2
                return 1
                ;;
            *)
                [[ -z "${branch_name}" ]] && branch_name="${1}"
                shift
                ;;
        esac
    done

    debug "get-parent-branches: branch_name=${branch_name} flow_file=${flow_file}"

    if [[ -z "${branch_name}" ]]; then
        echo "usage: get-parent-branch <branch-name> [-f <flow-file>]"
        return 1
    fi

    local branch_flow=$(cat "${flow_file}")
    local parent_branch=$(
        echo "${branch_flow}" \
            | grep -E "[ \t]*->[ \t]*${branch_name}" \
            | sed -E 's/[ \t]*->[ \t]*.*//'
    )
    echo "${parent_branch}"
}

# @description Get branch settings from a branch flow file
# @usage get-branch-option [-eESiVpP] [-s <source-branch>] [-t <target-branch>] [-o <option>] [-f <flow-file>]
function get-branch-option() {
    local line_regex="([^ ]+) -> ([^ ]+)( +)?(.*)?"

    # Default values
    local source_branch_name=""
    local target_branch_name=""
    local do_value_only=false
    local do_pretty=false
    local do_show_all_matches=false # don't uniquify results
    local option_name=""
    local flow_file="./branches.gv"

    # Parse options
    do_value_only_specified=false
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -s | --source-branch)
                source_branch_name="${2}"
                shift 2
                ;;
            -t | --target-branch)
                target_branch_name="${2}"
                shift 2
                ;;
            -o | --option)
                option_name="${2}"
                shift 2
                ;;
            -f | --flow-file)
                flow_file="${2}"
                shift 2
                ;;
            -S | --strict)
                do_strict=true
                shift
                ;;
            --no-strict)
                do_strict=false
                shift
                ;;
            -p | --pretty)
                do_pretty=true
                shift
                ;;
            -P | --no-pretty)
                do_pretty=false
                shift
                ;;
            -V | --value-only)
                do_value_only=true
                do_strict=true
                do_value_only_specified=true
                shift
                ;;
            -k | --show-keys)
                do_value_only=false
                do_value_only_specified=true
                shift
                ;;
            *)
                echo "usage: get-branch-option [-s <source-branch>] [-t <target-branch>] [-o <option>] [-f <flow-file>]"
                return 1
                ;;
        esac
    done

    debug-vars source_branch_name target_branch_name option_name flow_file \
        do_regex do_strict do_pretty do_value_only do_value_only_specified

    if ${do_value_only} && ! ${do_strict}; then
        echo "error: --value-only must be used with --strict"
    fi

    if [[ -n "${option_name}" ]] && ! ${do_value_only_specified}; then
        do_value_only=true
    fi

    if [[ "${flow_file}" == "-" ]]; then
        flow_file="/dev/stdin"
    fi

    # Read the branch flow file, attempting to account for multiline options
    local flow_content=$(_normalize_branch_flow "${flow_file}")

    local line_source_branch line_target_branch line_options
    readarray -t matching_options < <(
        while read -r line; do
            debug "processing line: ${line}"
            if [[ "${line}" =~ ${line_regex} ]]; then
                line_source_branch="${BASH_REMATCH[1]}"
                line_target_branch="${BASH_REMATCH[2]}"
                line_options="${BASH_REMATCH[4]}"
            else
                debug "line does not match regex, skipping"
                continue
            fi

            # Use glob matching
            if [[ ${source_branch_name} == ${line_source_branch} ]]; then
                debug "source branch matches"
            else
                debug "source branch does not match"
                continue
            fi

            if [[ ${target_branch_name} == ${line_target_branch} ]]; then
                debug "target branch matches"
            else
                debug "target branch does not match"
                continue
            fi

            # Parse the options, trimming leading/trailing whitespace and brackets,
            # and replacing commas with newlines
            line_options=$(
                echo "${line_options}" \
                    | sed -E 's/^ *\[//;s/\] *$//' \
                    | sed -Ee :1 -e 's/^(([^",]|"[^"]*")*),/\1\n/;t1' \
                    | sed 's/^ *//;s/ *$//'
            )
            debug "all options for source/target branch: ${line_options}"

            if [[ -n "${option_name}" ]]; then
                # Filter only the options matching the given option name
                line_options=$(
                    awk -F '=' -v option="${option_name}" '
                        $1 == option {
                            print $0
                        }
                    ' <<< "${line_options}")
                debug "filtered options for source/target branch: ${line_options}"
            fi
            [[ -n "${line_options}" ]] && echo "${line_options}"
        done <<< "${flow_content}" \
            | awk -F '=' '
                # For each option, store only the last value
                {
                    options[$1] = $0
                }
                END {
                    for (option in options) {
                        print options[option]
                    }
                }
            '
    )
    debug "parsed matching options: ${matching_options[@]}"

    # If value-only mode is enabled, only the value should be returned
    if ${do_value_only}; then
        debug "do_value_only=${do_value_only}, stripping option names"
        readarray -t matching_options < <(
            printf '%s\n' "${matching_options[@]}" | sed -E 's/^[^=]+=//'
        )
        debug "updated matching options: ${matching_options[@]}"
    fi

    local opt val
    for matching_option in "${matching_options[@]}"; do
        debug "parsing option: ${matching_option}"
        val="${matching_option#*=}"
        opt="${matching_option%%=*}"
        if ${do_pretty}; then
            debug "prettifying value"
            val="${val#\"}"
            val="${val%\"}"
            # Replace escaped characters
            val=$(printf '%b' "${val}" | sed 's/\\"/"/g')
        fi
        if ${do_value_only}; then
            echo "${val}"
        else
            echo "${opt}=${val}"
        fi
    done

}

# @description Get the timestamp, hash, and number of committed files for the last cherry-pick or release for a feature into a branch
# @usage get-last-promotion <feature> [--branch <branch>] [--before <date>] [--after <date>]
function get-last-promotion() {
    local branch feature before_ts after_ts
    local git_args=()
    local remote
    local release_message pick_message merge_message promotion_pattern
    local promotion_list
    local found_promotion=false
    local use_trigger_ts=true trigger_ts_found=false

    # parse args
    while [[ $# -gt 0 ]]; do
        debug "processing arg: ${1}"
        case "${1}" in
            -r | --branch)
                shift 1
                branch="${1}"
                ;;
            -b | --before | --until)
                shift 1
                before_ts="${1}"
                ;;
            -a | --after | --since)
                shift 1
                after_ts="${1}"
                ;;
            --use-trigger-timestamp)
                use_trigger_ts=true
                ;;
            --no-use-trigger-timestamp)
                use_trigger_ts=false
                ;;
            *)
                if [[ -z "${feature}" ]]; then
                    feature="${1}"
                elif [[ -z "${branch}" ]]; then
                    branch="${1}"
                else
                    debug error "unknown argument: ${1}"
                    return 1
                fi
                ;;
        esac
        shift
    done

    [[ -z "${branch}" ]] && branch="$(git rev-parse --abbrev-ref HEAD)"
    [[ -z "${feature}" ]] && echo "fatal: no feature given" >&2 && return 1

    # Set up the git args for the log command
    [[ -n "${before_ts}" ]] && git_args+=("--before=${before_ts}")
    [[ -n "${after_ts}" ]] && git_args+=("--after=${after_ts}")

    remote=$(git config --get "branch.${branch}.remote" || git remote)
    release_message="$(generate-release-message "${feature}")"
    pick_message="$(generate-pick-message "${feature}")"
    merge_message="$(generate-merge-message "${feature}")"
    promotion_pattern="^${release_message}|${pick_message}|${merge_message}$"

    debug-vars branch feature remote before_ts after_ts git_args \
        use_trigger_ts release_message pick_message merge_message \
        promotion_pattern

    # - Search for all promotions (releases and picks) for the feature into the
    #   branch
	# Generate a list of cherry-picks for the customization into the target branch with each file in that cherry-pick
	# on the same line delimited by a \x1e (Record Separator) character
	# e.g.:
	#   43169edc8\t1659555795\tCherry-picking for AS9-CUS-SDS-0009\x1eAS9-CUS-SDS-009\x1etailored/metadata/runtime/ui/VIEW/FANNS025-FANN-VIEW.xml\n
	#   c0bf3b73f\t1654542635\tCherry-picking for AS9-CUS-SDS-0009\x1eAS9-CUS-SDS-0009\n
	#   56b4912d5\t1646009697\tCherry-picking for AS9-CUS-SDS-0009\x1eAS9-CUS-SDS-0009\n
    readarray -t promotion_list < <(
        git log "${remote}/${branch}" \
            -n 15 -m \
            -E --grep="${promotion_pattern}" \
            --format=$'\1%h%x09%at%x09%s%x09' \
            --name-only \
            --raw \
            "${git_args[@]}" \
                | grep -v '^$' \
                | tr '\n' $'\x1e' \
                | sed $'s/.*/&\1/' \
                | tr '\1' '\n' \
                | sed 1d \
                | sed $'s/\x1e$//'
    )

    local last_promo_hash last_promo_time last_promo_mesg last_promo_files
    local last_promo_objs last_promo_type
	for promotion in "${promotion_list[@]}"; do
		# Extract the hash, timestamp, and pick files
		last_promo_hash=$(echo "${promotion}" | awk -F '\t' '{print $1}')
		last_promo_time=$(echo "${promotion}" | awk -F '\t' '{print $2}' | awk -F $'\x1e' '{print $1}')
        last_promo_mesg=$(echo "${promotion}" | awk -F '\t' '{print $3}')
		readarray -t last_promo_files < <(
            echo "${promotion}" | awk -F '\t' '{print $4}' | tr $'\x1e' '\n' | sed 1d
        )
		last_promo_objs=0
        debug "Determining promotion type for: ${last_promo_mesg}"
        debug-vars last_promo_mesg pick_message release_message merge_message
        last_promo_type=$(
            if [[ "${last_promo_mesg}" =~ ${pick_message} ]]; then
                echo "pick"
            elif [[ "${last_promo_mesg}" =~ ${release_message} ]]; then
                echo "release"
            elif [[ "${last_promo_mesg}" =~ ${merge_message} ]]; then
                echo "merge"
            else
                echo "unknown"
            fi
        )
        debug "last_promo_type: ${last_promo_type}"
        debug "Found ${last_promo_type} \"${last_promo_mesg}\" at ${last_promo_time} (${last_promo_hash})"
		# Loop through the files and check if any of them are not ignored
		for file in "${last_promo_files[@]}"; do
			# Check if the file is one we would pick
			if ! ignore-object -q "${file}"; then
				# This is a valid, cherry-pick file
				found_promotion=true
				let last_promo_objs++
			fi
		done
		if ${found_promotion}; then
            debug "Promotion found: ${last_promo_mesg} (${last_promo_hash})"
            break
        fi
	done

    # Update the timestamp for merges (use the timestamp of the merge commit)
    # and cherry-picks (use the timestamp of the cherry-pick trigger commit)
    local merge_commit promotion_hash promotion_files
    if ${found_promotion}; then
        # If this commit was merged into the target branch, then use the merge
        # commit's timestamp
        merge_commit=$(find-merge "${last_promo_hash}" "${remote}/${branch}" 2>/dev/null)
        if [[ -n "${merge_commit}" ]]; then
            last_promo_time=$(git log -1 --format=%at "${merge_commit}")
            debug "Using merge commit timestamp: ${merge_commit} (${last_promo_time})"
        elif [[ "${last_promo_type}" == "pick" ]] && ${use_trigger_ts}; then
            # If we're using the trigger timestamp, find the most recent commit
            # prior to the cherry-pick whose only commit object is a file with the
            # name of our feature
            debug "Searching for cherry-pick trigger timestamp"
            readarray -t promotion_list < <(
                git log "origin/${branch}" \
                    -n 15 -m \
                    --before "${last_promo_time}" \
                    --format=$'\1%h%x09%at%x09' \
                    --name-only \
                    --raw \
                        | grep -v '^$' \
                        | tr '\n' $'\x1e' \
                        | sed $'s/.*/&\1/' \
                        | tr '\1' '\n' \
                        | sed 1d \
                        | sed $'s/\x1e$//'
            )
            for promotion in "${promotion_list[@]}"; do
                # Check to see if the commit only contains the feature file
                promotion_hash=$(echo "${promotion}" | awk -F $'\t' '{print $1}')
                promotion_files=$(echo "${promotion}" | awk -F $'\t' '{print $3}' | tr -d $'\x1e')
                debug "Checking commit ${promotion_hash} for feature ${feature} -- ${promotion_files}"
                if [[ "${promotion_files}" == "${feature}" ]]; then
                    # This is the commit we want
                    last_promo_time=$(echo "${promotion}" | awk -F $'\t' '{print $2}')
                    debug "Using trigger timestamp: ${last_promo_time}"
                    trigger_ts_found=true
                    break
                fi
            done
            ! ${trigger_ts_found} && debug "Trigger timestamp not found, using cherry-pick timestamp ${last_promo_time}"
        fi
    else
        # No promotion found, so return an error
        debug error "No promotion found for feature '${feature}' on branch '${branch}'"
        return 1
    fi

    # Print information about the last promotion
    echo "${last_promo_time}" "${last_promo_hash}" "${last_promo_objs}"
}

# @description Determine whether a file should generally be handled by devops
# @usage ignore-object [--quiet] <object>
function ignore-object() {
	local obj obj_basedir
    local do_ignore=false
    local do_quiet=false

    # parse args
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -q | --quiet)
                do_quiet=true
                ;;
            *)
                if [[ -z "${obj}" ]]; then
                    obj="${1}"
                else
                    debug error "unknown argument: ${1}"
                    return 1
                fi
                ;;
        esac
        shift
    done

    debug info "checking if '${obj}' should be ignored (quiet=${do_quiet})"

    # Determine if the object should be ignored
    obj_basedir="${obj%%/*}"
    debug info "object base directory: ${obj_basedir}"
    case "${obj_basedir}" in
        nxa | tailored | database | app_config | helix)
            do_ignore=false
            ;;
        *)
            do_ignore=true
            ;;
    esac

    # Print and return the result
    if ${do_ignore}; then
        ! ${do_quiet} && echo "true"
        return 0
    else
        ! ${do_quiet} && echo "false"
        return 1
    fi   
}

# @description Return AssetSuite configuration settings
# @usage as-config <property name/pattern>
# @example as-config server.mode
# @example as-config "server\..*"
function as-config() {
    # Help text
    local usage="[-d|--assetsuite-dir <dir>] [-n|--num-results <num>] [-i|--include <REGEXP>] [-x|--exclude <REGEXP>] [-s|--sort] [-S|--no-sort] [-k|--show-keys] [-K|--no-show-keys] [-f|--show-filenames] [-F|--no-show-filenames] [-c|--columns] [-C|--no-columns] <property name/REGEXP>"

    # Default values
    local key="$"
    local num_results=""
    local do_sort=false
    local do_show_filenames=true
    local do_show_linenumbers=true
    local do_show_keys=true
    local do_show_columns=true
    local properties_includes=""
    local properties_excludes=""
    local grep_args=()
    local as_dir="${ASSETSUITE_DIR:-/abb/assetsuite}"
    local return_str=""
    local properties_files=() properties_files_unfiltered=()

    # If no arguments provided, print help text
    if [[ ${#} -le 0 ]]; then
        echo "usage: as-config ${usage}"
        return 0
    fi

    # Process arguments
    while [ ${#} -gt 0 ]; do
        debug "processing arg: $1"
        case "${1}" in
            -h | --help)
                echo "usage: as-config ${usage}"
                return 0
                ;;
            -h  |  --help)
                echo "usage: as-config ${usage}"
                return 0
                ;;
            -d | --assetsuite-dir)
                as_dir="$2"
                shift 2
                ;;
            -n | --num-results)
                # Check if the value is a number
                if [[ ! "${2}" =~ ^[0-9]+$ ]]; then
                    echo "ERROR: The value '${2}' is not a number" >&2
                    return 1
                fi
                num_results="${2}"
                shift 2
                ;;
            -i | --include)
                properties_includes="${2}"
                shift 2
                ;;
            -x | --exclude)
                properties_excludes="${2}"
                shift 2
                ;;
            -s | --sort)
                do_sort=true
                shift
                ;;
            -S | --no-sort)
                do_sort=false
                shift
                ;;
            -k | --show-keys)
                do_show_keys=true
                shift
                ;;
            -K | --no-show-keys)
                do_show_keys=false
                shift
                ;;
            -f | --show-filenames)
                do_show_filenames=true
                shift
                ;;
            -F | --no-show-filenames)
                do_show_filenames=false
                shift
                ;;
            -l | --show-linenumbers)
                do_show_linenumbers=true
                shift
                ;;
            -L | --no-show-linenumbers)
                do_show_linenumbers=false
                shift
                ;;
            -c | --columns)
                do_show_columns=true
                shift
                ;;
            -C | --no-columns)
                do_show_columns=false
                shift
                ;;
            *)
                key="$1"
                shift
                ;;
        esac
    done

    # If filenames aren't being shown, ensure line numbers aren't either
    ! ${do_show_filenames} && do_show_linenumbers=false

    debug-vars \
        key num_results do_sort do_show_keys do_show_columns do_show_filenames \
        do_show_linenumbers as_dir properties_includes properties_excludes

    # Check if the AssetSuite directory exists
    if [[ ! -d "${as_dir}" ]]; then
        echo "ERROR: the AssetSuite directory '${as_dir}' does not exist" >&2
        return 1
    fi

    # Find all properties files, filtering based on the include/exclude patterns
    debug "finding properties files"
    readarray -t properties_files < <(
        find "${as_dir}" -type f -name '*.properties' 2>/dev/null \
            | ([[ -n "${properties_includes}" ]] && command grep -E "${properties_includes}" || cat) \
            | ([[ -n "${properties_excludes}" ]] && command grep -vE "${properties_excludes}" || cat)
    )
    debug "found ${#properties_files[@]} properties files"

    # Ensure we found properties files
    if [[ ${#properties_files[@]} -le 0 ]]; then
        echo "error: no properties files found under '${as_dir}'" >&2
        return 1
    fi

    # Get the key value(s)
    debug "searching for key pattern '${key}'"
    readarray -t results < <(
        awk -v key="${key}" -v debug="${DEBUG}" \
            -v do_filenames="${do_show_filenames}" \
            -v do_linenums="${do_show_linenumbers}" '
        function dbg(msg) {
            if (debug == 1 || debug == "true") {
                print "awk debug: " msg > "/dev/stderr";
            }
        }
        BEGIN {
            # Add a leading ^ and trailing $ to the key if not present
            if (key !~ "^\\^") {
                key = "^" key;
            }
            if (key !~ "\\$$") {
                key = key "$";
            }
        }
        {
            # Save the line for printing later
            line = $0;
            # Skip lines starting with #
            if ($0 ~ /^ *#/) {
                next;
            }
            # Remove any comments from the line
            gsub(/ *#.*$/, "", $0);
            # Trim the value from the line and remove whitespace from the key
            gsub(/ *=.*/, "", $0);
            gsub(/^ */, "", $0);
            if ($0 ~ key) {
                if (do_filenames) {
                    if (do_linenums) {
                        print FILENAME ":" FNR ":" line;
                    } else {
                        print FILENAME ":" line;
                    }
                } else {
                    print line;
                }
            }
        }' "${properties_files[@]}"
    )
    debug "found ${#results[@]} results"

    # If no results were found, return an error
    if [[ ${#results[@]} -le 0 ]]; then
        echo "error: no results found for '${key}'" >&2
        return 1
    fi
    debug "sample results[0]: ${results[0]}"

    # Strip leading/trailing whitespace from the keys and values
    debug "stripping leading/trailing whitespace"
    if ${do_show_filenames} && ${do_show_linenumbers}; then
        # Skip the first 2 colons
        readarray -t results < <(
            printf '%s\n' "${results[@]}" \
                | sed -E 's/^([^:]+:[0-9]+:) *([^= ]+) *= *(.*) *$/\1\2=\3/'
        )
    elif ${do_show_filenames} && ! ${do_show_linenumbers}; then
        # Skip the first colon
        readarray -t results < <(
            printf '%s\n' "${results[@]}" \
                | sed -E 's/^([^:]*:) *([^= ]+) *= *(.*) *$/\1\2=\3/'
        )
    else
        # Don't skip any colons
        readarray -t results < <(
            printf '%s\n' "${results[@]}" \
                | sed -E 's/^ *([^= ]+) *= *(.*) *$/\1=\2/'
        )
    fi
    debug "sample results[0]: ${results[0]}"

    # Sort the array if requested
    if ${do_sort}; then
        debug "sorting results"
        readarray -t results < <(printf '%s\n' "${results[@]}" | sort)
        debug "sample results[0]: ${results[0]}"
        debug "\${#results[@]}: ${#results[@]}"
    fi

    # Reduce the array size if requested
    if [[ -n "${num_results}" && ${num_results} -lt ${#results[@]} ]]; then
        debug "reducing results to ${num_results} results"
        readarray -t results < <(
            printf '%s\n' "${results[@]}" | head -n "${num_results}"
        )
        debug "sample results[0]: ${results[0]}"
        debug "\${#results[@]}: ${#results[@]}"
    fi

    # Remove key names if do_show_keys=false
    if ! ${do_show_keys}; then
        debug "removing key names..."
        if ${do_show_filenames}; then
            if ${do_show_linenumbers}; then
                debug "...with filenames and line numbers"
                # Remove everything from the second : to the next =
                readarray -t results < <(
                    printf '%s\n' "${results[@]}" \
                        | sed -E 's/^([^:]+:[0-9]+:)[^=]*=/\1/'
                )
            else
                debug "...with filenames but no line numbers"
                readarray -t results < <(
                    printf '%s\n' "${results[@]}" \
                        | sed -E 's/^([^:]*:)[^=]*=/\1/'
                )
            fi
        else
            debug "...with no filenames"
            readarray -t results < <(
                printf '%s\n' "${results[@]}" | sed -E 's/^[^=]*=//'
            )
        fi
        debug "sample results[0]: ${results[0]}"
        debug "\${#results[@]}: ${#results[@]}"
    fi

    # Set up the return string
    return_str=$(printf '%s\n' "${results[@]}")

    # Columnize the results if do_show_columns=true
    if ${do_show_columns}; then
        debug "columnizing output"

        if ${do_show_filenames}; then
            if ! ${do_show_linenumbers}; then
                # If filenames are being shown but line numbers are not, replace
                # the first colon with a FS character
                debug "replacing first colon with FS character"
                return_str=$(sed -E 's/:/\x1f/' <<< "${return_str}")
            else
                # If line numbers *are* being shown, then replace the second
                # colon with a FS character
                debug "replacing second colon with FS character"
                return_str=$(sed -E 's/:/\x1f/2' <<< "${return_str}")
            fi
            debug "sample return_str[0]: ${return_str%%$'\n'*}"
        fi
        # If key names are being shown, replace the first equals sign with a FS
        # character
        if ${do_show_keys}; then
            debug "replacing first equals sign with FS character"
            return_str=$(sed -E 's/=/\x1f/' <<< "${return_str}")
            debug "sample return_str[0]: ${return_str%%$'\n'*}"
        fi

        return_str=$(column -t -s $'\x1f' <<< "${return_str}")
        debug "columnized output"
        debug "sample return_str[0]: ${return_str%%$'\n'*}"
    fi

    # Print the results
    echo "${return_str}"
}

# @description Run a command as the Asset Suite user
# @usage asrun <command>
function asrun() {
    local cmd_name="${1}"
    local as_user="${AS_USER:-asuser}"
    local cmd_args=( "${@:2}" )
    local cmd_str="${cmd_name}"
    [[ ${#cmd_args[@]} -gt 0 ]] && cmd_str+=$(printf ' %q' "${cmd_args[@]}")
    debug-vars cmd_name cmd_args cmd_str

    sudo -u "${AS_USER}" bash -c "${cmd_str}"
}

# @description Run a script in /abb/assetsuite/ as the Asset Suite user
# @usage asrun-script <script> [<args>...]
function asrun-script() (
    cd "/abb/assetsuite" || return ${?}

    local filepath="${1##*/}"
    local args=( "${@:2}" )

    asrun "./${filepath}" "${args[@]}"
)

# @description Run an /abb/assetsuite command as the Asset Suite user
# @usage assetsuite <subcommand> [<args>...]
function assetsuite() {
    asrun-script "./assetsuite ${@}"
}
