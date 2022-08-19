include-source 'debug.sh'
include-source 'echo.sh'
include-source 'shell.sh'
include-source 'text.sh'

# Return the path to the git repository root
function git-root() {
    git rev-parse --show-toplevel
}

# Return the path of a file relative to the git repository root
function git-relpath() {
    local filepath="${1}"
    local git_root=$(git-root)
    local rel_path=$(realpath "${filepath}" --relative-to="${git_root}")
    echo "${rel_path}"
}

# Return the current git branch. If the current branch is detached, return the
# commit hash instead.
function git-branch-name() {
    local usage="usage: $(functionname) [-h|--help] [-n|--detached-name] [-c|--detached-commit] [-b|--detached-both]"
    local branch
    local branch_name
    local branch_hash

    # default values
    local detached_format="name" # "name", "commit", or "both"

    while [[ ${#} -gt 0 ]]; do
        local arg="$1"
        case "$arg" in
            -h|--help)
                echo ${usage}
                return 0
                ;;
            -n|--detached-name)
                name_only=1
                shift
                ;;

            -d|--detached-commit)
                name_only=0
                shift
                ;;
            -b|--detached-both)
                name_only=2
                shift
                ;;
            -*)
                echo "include-source: invalid option '$arg'" >&2
                exit 1
                ;;
        esac
    done

    debug "detached_format: ${detached_format}"

    branch=$(git rev-parse --abbrev-ref HEAD)

    debug "initial branch: ${branch}"

    if [ "${branch}" = "HEAD" ]; then
        # on detached HEAD
        if [ "${detached_format}" = "name" ] || [ "${detached_format}" = "both" ]; then
            # fetch the name
            branch_name=$(git name-rev --name-only HEAD 2> /dev/null)
            if [ "${detached_format}" = "name" ]; then
                # If showing the name only, remove any relative commit suffixes
                branch=$(echo "${branch_name}" | sed 's/[~^:].*//g')
            fi
        fi

        if [ "${detached_format}" = "commit" ] || [ "${detached_format}" = "both" ]; then
            # fetch the commit hash
            branch_hash=$(git rev-parse --short HEAD)
            if [ "${detached_format}" = "commit" ]; then
                branch="${branch_hash}"
            elif [ "${detached_format}" = "both" ]; then
                branch="${branch_name}:${branch_hash}"
            fi
        fi
    fi

    echo "${branch}"
}

# Determine if the specified commit exists in the current repo
function git-commit-exists() {
    local commit="${1}"

    # verify that the given commit is at least a valid hash
    if ! is-hex "${commit}" || [ "${#commit}" -lt 4 ]; then
        debug "'${commit}' is not formatted as a valid hash"
        echo "fatal: invalid commit hash" >&2
        return 1
    else
        debug "'${commit}' is a valid commit hash"
    fi

    # verify that the given commit exists in the current repo
    debug "using rev-parse to verify '${commit}' exists in the current repo"
    git rev-parse --verify "${commit}" >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        debug "'${commit}' exists in the current repo"
        return 0
    else
        debug "'${commit}' does not exist in the current repo"
        return 1
    fi
}

# Find which merge commit a specific commit is part of
function git-merge-commit() {
    local commit="${1}"
    local ref="${2:-HEAD}"

    debug "commit: ${commit}"
    debug "ref: ${ref}"

    if ! git-commit-exists "${commit}"; then
        echo "fatal: invalid commit '${commit}'" >&2
        return 1
    fi

    # verify the ref exists
    if ! git rev-parse --verify "${ref}" >/dev/null 2>&1; then
        echo "fatal: invalid ref '${ref}'" >&2
        return 1
    fi

    local ancestry_path=$(git rev-list --ancestry-path "${commit}".."${ref}" | cat -n)
    local first_parent=$(git rev-list --first-parent "${commit}".."${ref}" | cat -n)
    local merge_commit=$(
        echo "${ancestry_path}"$'\n'"${first_parent}" \
        | sort -k2 -s \
        | uniq -f1 -d \
        | sort -n \
        | tail -1 \
        | cut -f2
    )

    git show "${merge_commit}"
}

# returns 0 if the specified commit is a merge commit, 1 otherwise
function is-merge-commit() {
    local commit="${1}"
    debug "commit: ${commit}"

    if ! git-commit-exists "${commit}"; then
        debug "commit '${commit}' does not exist" >&2
        return 1
    else
        debug "commit exists"
    fi

    local merge_parents=$(git rev-list -1 --merges "${commit}~1".."${commit}")
    debug "git rev-list -1 --merges ${commit}~1..${commit} -> '${merge_parents}'"

    if [ -z "${merge_parents}" ]; then
        return 1
    else
        return 0
    fi
}

# Returns a list of commit hashes and filepaths in the ref in the format:
#   <commit hash>:<filepath>
# Any passed in arguments are passed along to the git log command
# example:
#   get-commit-hashes-and-objects master
#   get-commit-hashes-and-objects master --pretty=format:"%H:%p" -n 1
function get-commit-hashes-and-objects() {
    local ref="${1}"
    shift
    local git_options="${@}"
    debug "ref: ${ref}"
    debug "git_options: ${git_options}"

    git log "${ref}" --name-only --no-renames --pretty="%x01%h" ${git_options} \
        | grep -v "^$" \
        | awk '
            {if ($0 ~ /^\x01/) {
                # If the current line starts with \x01, store the hash
                commit=gensub(/^\x01/, "", 1, $0);
            } else {
                # else, print the stored hash and the filepath on this line
                print commit ":" $0;
            }}
        '
}

# given a git ref, return its type as one of the following:
#   "range", "branch", "tag", "commit", "remote", "unknown"
function get-ref-type() {
    local ref="${1}"
    local ref_type

    [ -z "${ref}" ] && return 1

    # determine if the ref is a range
    if [[ "${ref}" =~ ^[a-z0-9~^]+".."[a-z0-9~^]+$ ]]; then
        ref_type="range"
    elif git show-ref -q --verify "refs/heads/$1" 2>/dev/null; then
        ref_type="branch"
    elif git show-ref -q --verify "refs/tags/$1" 2>/dev/null; then
        ref_type="tag"
    elif git show-ref -q --verify "refs/remote/$1" 2>/dev/null; then
        ref_type="remote"
    elif git rev-parse --verify "$1^{commit}" >/dev/null 2>&1; then
        ref_type="commit"
    else
        ref_type="unknown"
    fi

    echo "${ref_type}"
    if [ "${ref_type}" = "unknown" ]; then
        return 1
    fi
    return 0
}

# returns a human readable version of the given git object status
function git-status-name() {
    local object_mode="${1}"

    # if the mode is "-", use stdin
    if [ "${object_mode}" == "-" ]; then
        object_mode=$(cat)
    fi

    # ensure the mode is upper case
    object_mode=$(echo "${object_mode}" | tr '[:lower:]' '[:upper:]')

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
        "R")
            object_mode="rename"
            ;;
        "C")
            object_mode="copied"
            ;;
        "U")
            object_mode="unmerged"
            ;;
        "T")
            object_mode="typechange"
            ;;
        *)
            object_mode="???"
            ;;
    esac

    echo "${object_mode}"
}