#!/usr/bin/env bash
#
# Generate a CSV file which reports whether each branch has been merged into the
# "core" branches of a repository.
#
# The generated CSV file will follow the format:
#   branch,core-1,core-2,...
#   "feature/foo",TRUE,FALSE,... (merged into core-1 but not core-2)
#   "feature/bar",FALSE,FALSE,... (not yet merged into any core branches)
#
# Options:
#   -h/--help              show a brief usage message
#   -C/--repo <path>       path to the repo
#   -c/--core              a comma or space delimited list of "core" branches
#   -f/--fetch             perform a fetch --all before running the report
#   -F/--no-fetch          do not perform a fetch
#   -r/--remote <remote>   the remote to use, e.g.: origin
#   -p/--prefix <prefix>   the full prefix for remote branches, e.g.:
#                          refs/remotes/origin/
#   --debug                enable debug mode
#   FILE                   the CSV file to write to
#
# The `--remote` option should generally not be necessary unless you have
# multiple remotes configured in your repo. If you don't know what this means,
# you almost certainly don't have multiple remotes configured.
#
# The `--prefix` option is similar with even less chance you'll need it. This
# script will look at all refspecs for the configured REMOTE, try to find one
# that includes `/heads`, and then use that to find remote branches. If you're
# just using the default refspec, you should be fine. If you're using a
# non-standard refspec, you should probably still be fine. Only specify this
# option if (1) you are using a non-standard refspec and (2) the automated
# detection is failing.
#
# If you don't want to generate a CSV file, you can specify `/dev/null` for the
# CSV file :)
#
# As a minor suggestion, if you think you might use this with some frequency and
# don't want to specify the core branches every time, you can create an alias in
# your bashrc by:
#   1. Adding this script to a `bin/` folder on your PATH
#   2. Creating an alias in your .bashrc such as:
#      `alias my-repo-report="branch-promotion-csv.sh --repo /path/to/repo --core dev,test,main`


# ---- Configurable Parameters -------------------------------------------------

REPO_PATH="."
CORE_BRANCHES=(dev test uat qa prod master)
CSV_FILE_DEFAULT=$(date +"branch-statuses_%Y%m%d-%H%m%s.csv")
DO_FETCH=true
REMOTE_BRANCH_PREFIX=""
REMOTE=$(git remote)
SCRIPT_PATH="${0}"


# ---- Parse arguments ---------------------------------------------------------

SCRIPT_OPTIONS=(
    "[-h/--help]" "[-C/--repo <path>]" "[-c/--core <branches>]" "[-f/--fetch]"
    "[-F/--no-fetch]" "[-r/--remote <remove>]" "[-p/--prefix <prefix>]"
    "[--debug]" "[<file>]"

)

function usage() {
    # Print usage, wrapping at 80 columns
    local -- prefix="usage: $(basename "${1}")"
    local -- options=( "${@:2}" )
    local -- line="" _line=""

    line="${prefix}"
    for option in "${options[@]}"; do
        _line="${line} ${option}"
        if [[ ${#_line} -gt 80 ]]; then
            # Once we hit 80 columns, print the line and reset
            echo "${line}"
            line=""
            for ((i=0; i<${#prefix}; i++)); do line+=" "; done
            line+=" ${option}"
        else
            line="${_line}"
        fi
    done

    # Print the last line if set
    [[ -n "${line}" ]] && echo "${line}"
}

while [[ ${#} -gt 0 ]]; do
    case ${1} in
        -h)
            usage "${SCRIPT_PATH}" "${SCRIPT_OPTIONS[@]}"
            exit 0
            ;;
        --help)
            usage "${SCRIPT_PATH}" "${SCRIPT_OPTIONS[@]}"
            echo
            # Show the header of this file, skipping the shebang
            line_no=0
            while read -r line; do
                if ((line_no >= 2)); then
                    # Stop once we hit a non-comment line
                    [[ "${line}" != "#"* ]] && break
                    # Remove the leading '# '
                    line="${line#\#}"
                    line="${line# }"
                    echo "${line}"
                fi
                let line_no++
            done < "${SCRIPT_PATH}"
            exit 0
            ;;
        -C | --repo)
            REPO_PATH="${2}"
            shift 2
            ;;
        -c | --core)
            # e.g.: --core dev,test,uat
            # e.g.: --core "dev test uat"
            IFS=', ' read -r -a CORE_BRANCHES <<< "${2}"
            shift 2
            ;;
        -f | --fetch)
            # e.g.: --fetch
            DO_FETCH=true
            shift 1
            ;;
        -F | --no-fetch)
            # e.g.: --no-fetch
            DO_FETCH=false
            shift 1
            ;;
        -p | --prefix)
            # e.g.: --prefix refs/remotes/origin/
            REMOTE_BRANCH_PREFIX="${2}"
            shift 2
            ;;
        -r | --remote)
            # e.g.: --remote origin
            REMOTE="${2}"
            shift 2
            ;;
        --debug)
            # e.g.: --debug
            DEBUG=true
            shift 1
            ;;
        -*)
            echo "fatal: unknown option: ${1}" >&2
            exit 1
            ;;
        *)
            # e.g.: ./branch-statuses.csv
            if [[ -z "${CSV_FILE}" ]]; then
                CSV_FILE="${1}"
            else
                echo "fatal: too many arguments: ${@}" >&2
                exit 1
            fi
            shift 1
            ;;
    esac
done

[[ -z "${CSV_FILE}" ]] && CSV_FILE="${CSV_FILE_DEFAULT}"


# --- git function -------------------------------------------------------------

# Set up a `git` function which makes use of REPO_PATH for all `git` calls
GIT=$(which git)
function git() {
    "${GIT}" -C "${REPO_PATH}" "${@}"
}


# ---- helpful functions -------------------------------------------------------

function debug() (
    local prefix timestamp
    if [[ "${DEBUG}" == "1" || "${DEBUG}" == "true" || -n "${DEBUG_LOG}" ]]; then
        if [[ ${#} -gt 0 ]]; then
            [[ -n "${DEBUG_LOG}" ]] && exec 3>>"${DEBUG_LOG}" || exec 3>&2
            timestamp=$(date +'%Y-%m-%d %H:%M:%S')
            prefix="\033[36m[${timestamp}]\033[0m"
            prefix+="\033[35m$(basename "${BASH_SOURCE[-1]}")"
            [[ "${FUNCNAME[1]}" != "main" ]] && prefix+="\033[1m:${FUNCNAME[1]}()\033[0m"
            prefix+="\033[32m:${BASH_LINENO[0]}\033[0m -- "
            printf "%s\n" "${@}" \
                | awk -v prefix="${prefix}" '{print prefix $0;fflush()}' >&3
        fi
    fi
)
function debug-vars() {
    debug && [[ ${#} -gt 0 ]] && debug "$(declare -p "${@}" 2>&1)"
}


# ---- Validations -------------------------------------------------------------

# Ensure we're in a repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "fatal: not in a git repo" >&2
    exit 1
fi

# Ensure the CSV_FILE or its parent directory is writeable
parent_dir=$(dirname "${CSV_FILE}")
if [[ -f "${CSV_FILE}" ]]; then
    if ! [[ -w "${CSV_FILE}" ]]; then
        echo "fatal: cannot write to file: ${CSV_FILE}" >&2
        exit 1
    fi
elif ! [[ -w "${parent_dir}" ]]; then
    echo "fatal: cannot write to directory: ${parent_dir}" >&2
    exit 1
fi


# ---- Setup -------------------------------------------------------------------

# Determine local config settings
## remote
REMOTE=$(git remote | head -1)
## refspec
if [[ -z "${REMOTE_BRANCH_PREFIX}" ]]; then
    branches_refspec=$(
        git config --get-all remote."${REMOTE}".fetch | grep '/heads' | head -1
    )
    if [[ -z "${branches_refspec}" ]]; then
        # simply fallback to the standard (although the "standard" should have
        # been grep'd above...)
        REMOTE_BRANCH_PREFIX="refs/remotes/${REMOTE}/"
    else
        # given "+refs/foo:refs/remotes/foo/*", extract "refs/remotes/foo/"
        REMOTE_BRANCH_PREFIX="${branches_refspec#*:}"
        REMOTE_BRANCH_PREFIX="${REMOTE_BRANCH_PREFIX%\*}"
    fi
fi
### remove a trailing slash from the prefix if there is one
[[ "${REMOTE_BRANCH_PREFIX}" == */ ]] \
    && REMOTE_BRANCH_PREFIX="${REMOTE_BRANCH_PREFIX%/}"

# Fetch the latest changes from the repo
if ${DO_FETCH}; then
    if ! git fetch --all --tags --prune &>/dev/null; then
        echo "fatal: could not fetch latest changes from repo" >&2
        exit 1
    fi
fi

# Print the path to the CSV file being generated using whichever is shorter:
# the relative path or the absolute path (favoring relative if they're equal)
rel_path=$(realpath --relative-to=. "${CSV_FILE}")
abs_path=$(realpath --no-symlinks "${CSV_FILE}")
csv_path=""
if [[ "${#rel_path}" -gt "${#abs_path}" ]]; then
    csv_path="${abs_path}"
else
    csv_path="${rel_path}"
fi
printf '\e[2m%s\e[0m\n' "Generating branch status CSV: ${csv_path}"

# Set up a file descriptor for the CSV_FILE or /dev/null if not set
[[ -z "${CSV_FILE}" ]] && CSV_FILE="/dev/null"
exec 3> >(tee "${CSV_FILE}")

# Print the CSV header
(
    __header=(branch "${CORE_BRANCHES[@]}")
    IFS=,
    echo "${__header[*]}"
) >&3

# Get a list of all remote branches
readarray -t remote_branches < <(
    git for-each-ref --format='%(refname)' \
        | grep "^${REMOTE_BRANCH_PREFIX}" \
        | grep -v "^${REMOTE_BRANCH_PREFIX}/HEAD"
)


# ---- debug -------------------------------------------------------------------

debug-vars CSV_FILE CORE_BRANCHES REMOTE_BRANCH_PREFIX remote_branches


# ---- Main loop ---------------------------------------------------------------

# Loop over each remote branch, checking whether its HEAD is an ancestor of each
# of the core branches
for remote_branch in "${remote_branches[@]}"; do
    debug "checking remote_branch: ${remote_branch}"
    # Skip the core branches
    for core_branch in "${CORE_BRANCHES[@]}"; do
        remote_core_branch="${REMOTE_BRANCH_PREFIX}/${core_branch}"
        if [[ "${remote_branch}" == "${remote_core_branch}" ]]; then
            debug "skipping core branch: ${remote_branch}"
            continue 2
        fi
    done

    # Print the branch
    printf "\"${remote_branch#${REMOTE_BRANCH_PREFIX}/}\""

    # Get a list of remote branches containing this branch
    branch_contains=$(
        git for-each-ref --contains "${remote_branch}" --format='%(refname)' \
            | grep "^${REMOTE_BRANCH_PREFIX}" \
            | grep -v "^${REMOTE_BRANCH_PREFIX}/HEAD"
    )
    # While a `debug` line doesn't print except when DEBUG=true, it still slows
    # things down by just a hair, so with my already painfully slow Git Bash
    # setup, I leave these commented out unless I'm actively developing
    #debug "branches containing ${remote_branch}:"
    #debug-vars branch_contains
    for core_branch in "${CORE_BRANCHES[@]}"; do
        remote_core_branch="${REMOTE_BRANCH_PREFIX}/${core_branch}"
        # debug "checking for remote_core_branch: ${remote_core_branch}"
        printf ','
        grep -Eq "^${remote_core_branch}" <<< "${branch_contains}" \
                && printf "TRUE" \
                || printf "FALSE"
    done

    echo
done >&3
