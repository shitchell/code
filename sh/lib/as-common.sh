#!/usr/bin/env bash
: '
Asset Suite functions
'

include-source 'git'
include-source 'debug'
include-source 'text'

# ------------------------------------------------------------------------------
# Setup global variables
# ------------------------------------------------------------------------------
# These values will be set, in order of lowest to highest priority, by:
# - a config file (see next section)
# - the environment

# ---- Default values ----------------------------------------------------------

DEFAULT_FEATURE_PATTERN="AS9-[A-Z]{3,5}-[A-Z]{0,5}-[0-9]{0,4}"
DEFAULT_RELEASE_PATTERN="{{feature}} Release"
DEFAULT_MERGE_PATTERN="Merged in {{feature}} .*"
DEFAULT_CHERRY_PICK_PATTERN="Cherry-picking for {{feature}}"

# ---- Save environment values -------------------------------------------------
# Since we will later overwrite the global variable values if/when we load a
# config file, we need to save their environment values to restore them later
ENV_FEATURE_PATTERN="${FEATURE_PATTERN}"
ENV_RELEASE_PATTERN="${RELEASE_PATTERN}"
ENV_MERGE_PATTERN="${MERGE_PATTERN}"
ENV_CHERRY_PICK_PATTERN="${CHERRY_PICK_PATTERN}"

# ---- Load config file --------------------------------------------------------
# The config file name can be set by the $AS_CONFIG_NAME environment variable,
# defaulting to ".as-config.sh".
# The config file will be searched, in order of lowest to highest priority, in:
# - the path specified by $AS_CONFIG
# - ./$AS_CONFIG_NAME
# - {repo-root}/$AS_CONFIG_NAME (if in a git repo)
# - {repo-root}/devops/$AS_CONFIG_NAME
# - $HOME/$AS_CONFIG_NAME
AS_CONFIG_NAME="${AS_CONFIG_NAME:-.as-config.sh}"
if [[ -z "${AS_CONFIG}" ]]; then
    # If AS_CONFIG isn't set, try to find a config file
    if [[ -f "./${AS_CONFIG_NAME}" && -r "./${AS_CONFIG_NAME}" ]]; then
        ## - ./$AS_CONFIG_NAME
        AS_CONFIG="./${AS_CONFIG_NAME}"
    elif git rev-parse --is-inside-work-tree &>/dev/null; then
        # get the repo root
        __repo_root=$(git rev-parse --show-toplevel)

        if [[
            -f "${__repo_root}/${AS_CONFIG_NAME}"
            && -r "${__repo_root}/${AS_CONFIG_NAME}"
        ]]; then
            ## - {repo-root}/$AS_CONFIG_NAME
            AS_CONFIG="${__repo_root}/${AS_CONFIG_NAME}"
        elif [[
            -f "${__repo_root}/devops/${AS_CONFIG_NAME}"
            && -r "${__repo_root}/devops/${AS_CONFIG_NAME}"
        ]]; then
            ## - {repo-root}/devops/$AS_CONFIG_NAME
            AS_CONFIG="${__repo_root}/devops/${AS_CONFIG_NAME}"
        fi
    elif [[
        -f "${HOME}/${AS_CONFIG_NAME}"
        && -r "${HOME}/${AS_CONFIG_NAME}"
    ]]; then
        ## - $HOME/$AS_CONFIG_NAME
        AS_CONFIG="${HOME}/${AS_CONFIG_NAME}"
    fi
fi
if [[ -f "${AS_CONFIG}" && -r "${AS_CONFIG}" ]]; then
    ## We will overwrite the environment variables here, which is why we saved
    ## them off earlier -- so we can put them back, prioritizing environment
    ## values over config values, but still loading the config values where
    ## the environment variables are not set.
    source "${AS_CONFIG}"
fi

# ---- Set the global variables ------------------------------------------------
# Set from (1) the environment, (2) config, or (3) the default value:
#   VAR="${ENV_VALUE:-${CONFIG_VALUE}:-${DEFAULT_VALUE}}"

FEATURE_PATTERN="${ENV_FEATURE_PATTERN:-${FEATURE_PATTERN:-${DEFAULT_FEATURE_PATTERN}}}"
RELEASE_PATTERN="${ENV_RELEASE_PATTERN:-${RELEASE_PATTERN:-${DEFAULT_RELEASE_PATTERN}}}"
MERGE_PATTERN="${ENV_MERGE_PATTERN:-${MERGE_PATTERN:-${DEFAULT_MERGE_PATTERN}}}"
CHERRY_PICK_PATTERN="${ENV_CHERRY_PICK_PATTERN:-${CHERRY_PICK_PATTERN:-${DEFAULT_CHERRY_PICK_PATTERN}}}"


# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------

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

# @description Get the server.mode
function as-server.mode() {
    as-config -i env.properties -K -F server.mode
}

# @description Is the server in development mode?
function as-is-development() {
    [[ "$(as-server.mode)" == "development" ]]
}

# @description Is the server in production mode?
function as-is-production() {
    [[ "$(as-server.mode)" == "production" ]]
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
