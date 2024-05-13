#!/usr/bin/env bash
: '
Git bash functions
'

include-source 'debug.sh'
include-source 'echo.sh'
include-source 'shell.sh'
include-source 'text.sh'
include-source 'exit-codes.sh'

function parse-git-command() {
    :  'Parse a git command into its parts

        Parses out a git command and stores them in the variables:
        - GIT_ARGS: the arguments to the git command
        - GIT_SUBCOMMAND: the git subcommand
        - GIT_SUBCOMMAND_ARGS: the arguments to the git subcommand

        @usage
            <git command>
        
        @arg+
            The git command to parse, separated as individual arguments
        
        @setenv GIT_ARGS
            An array of the arguments to the git command
        
        @setenv GIT_SUBCOMMAND
            The git subcommand
        
        @setenv GIT_SUBCOMMAND_ARGS
            An array of the arguments to the git subcommand
        
        @example
            parse-git-command git log --oneline
    '
    declare -ga GIT_ARGS=()
    declare -g  GIT_SUBCOMMAND=""
    declare -ga GIT_SUBCOMMAND_ARGS=()

    # If the first argument is git, remove it
    if [[ "${1}" = "git" || "${1}" == *"/git" ]]; then
        shift 1
    fi

    while [[ ${#} -gt 0 ]]; do
        debug "parsing: ${1}"
        case ${1} in
            # Handle all options that take no arguments
            -h | --help | --version | --html-path | --man-path | --info-path | \
            -p | --paginate | -P | --no-pager | --no-replace-objects | --bare | \
            --literal-pathspecs | --glob-pathspecs | --noglob-pathspecs | \
            --icase-pathspecs | --no-optional-locks | --no-renames | --exec-path*)
                debug "no arg: ${1}"
                GIT_ARGS+=("${1}")
                shift 1
                ;;

            # Handle all options that optionally take an argument
            --git-dir* | --work-tree* | --namespace* | --super-prefix* | \
            --config-env* | --list-cmds*)
                debug "arg optional: ${1}"
                # Determine if the argument contains an equals sign
                if [[ "${1}" =~ = ]]; then
                    # If it does, then there is no 2nd argument
                    GIT_ARGS+=("${1}")
                    shift 1
                else
                    # If it doesn't, then there is a 2nd argument to store
                    GIT_ARGS+=("${1}" "${2}")
                    shift 2
                fi
                ;;

            # Handle all options that require an argument
            -C | -c)
                debug "arg required: ${1}"
                GIT_ARGS+=("${1}" "${2}")
                shift 2
                ;;

            *)
                # This is the subcommand -- store it and the rest of the args
                GIT_SUBCOMMAND="${1}"
                shift 1
                GIT_SUBCOMMAND_ARGS=("${@}")
                debug "subcommand: ${GIT_SUBCOMMAND}"
                debug "subcommand args (${#@}):`printf " '%s'" "${GIT_SUBCOMMAND_ARGS[@]}"`"
                break
                ;;
        esac
        debug "git args (${#@}):`printf " '%s'" "${GIT_ARGS[@]}"`"
    done
}

# shellcheck disable=SC2120
# SC2120: this function references arguments that are never passed, but this is
#         a library, and other scripts will call this and pass arguments
function git-root() {
    :  'Get the root of the git repository

        @usage
            [path]
        
        @optarg path
            The path to the git repository. Default: .

        @stdout
            The path to the root of the git repository
        
        @return 0
            The path to the root of the git repository was found
        
        @return 128
            Not in a git repository
    '
    git -C "${1:-.}" rev-parse --show-toplevel
}

function git-relpath() {
    :  'Get the relative path of a file to the git repository root

        @usage
            <filepath>
        
        @arg filepath
            The path to the file
        
        @stdout
            The relative path of the file to the git repository root
    '
    local filepath="${1}"
    local git_root rel_path

    git_root=$(git-root)
    rel_path=$(
        realpath -m "${filepath}" --relative-to="${git_root}" --no-symlinks
    )
    echo "${rel_path}"
}

# Return the current git branch. If the current branch is detached, return the
# commit hash instead.
# TODO: build proper documentation for this
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

function git-commit-exists() {
    :  'Determine if the specified commit exists in the current repo

        @usage
            <commit>
        
        @arg commit
            The commit to check
        
        @return 0
            The commit exists in the current repo
        
        @return 1
            The commit does not exist in the current repo
        
        @return 2
            The commit is not a valid hash
        
        @return 3
            No commit was given
    '
    local commit="${1}"

    # ensure a commit was given
    if [ -z "${commit}" ]; then
        echo "fatal: no commit given" >&2
        return 3
    fi

    # verify that the given commit is at least a valid hash
    if ! is-hex "${commit}" || [ "${#commit}" -lt 4 ]; then
        debug "'${commit}' is not formatted as a valid hash"
        echo "fatal: invalid commit hash" >&2
        return 2
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
function get-parent-merge-commit() {
    :  'Given a commit and a ref, find the merge that brought the commit into
        the ref history.

        @usage
            <commit> [ref]

        @arg commit
            The commit to find the merge commit for

        @optarg ref
            The ref to search for the merge commit in. Default: HEAD

        @stdout
            The merge commit that the specified commit is part of
        
        @return 0
            The merge commit was found
        
        @return 1

    '
    local commit="${1}"
    local ref="${2:-HEAD}"
    local ancestry_path first_parent merge_commit

    debug "commit: ${commit}"
    debug "ref: ${ref}"

    if ! git-commit-exists "${commit}"; then
        echo "fatal: invalid commit '${commit}'" >&2
        return ${E_INVALID_COMMIT}
    fi

    # verify the ref exists
    if ! git rev-parse --verify "${ref}" >/dev/null 2>&1; then
        echo "fatal: invalid ref '${ref}'" >&2
        return 1
    fi

    ancestry_path=$(git rev-list --ancestry-path "${commit}".."${ref}" | cat -n)
    first_parent=$(git rev-list --first-parent "${commit}".."${ref}" | cat -n)
    merge_commit=$(
        echo "${ancestry_path}"$'\n'"${first_parent}" \
        | sort -k2 -s \
        | uniq -f1 -d \
        | sort -n \
        | tail -1 \
        | cut -f2
    )

    git log -1 "${merge_commit}"
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
# TODO: improve this for remote refs
function get-ref-type() {
    local ref="${1}"
    local ref_type

    [ -z "${ref}" ] && return 1

    # remove a remote prefix if it exists
    local remote=$(git remote)
    local normalized_ref="${ref#${remote}/}"

    # determine if the ref is a range
    if [[ "${normalized_ref}" =~ ^[a-z0-9~^]+".."[a-z0-9~^]+$ ]]; then
        ref_type="range"
    elif git show-ref -q --verify "refs/heads/${normalized_ref}" 2>/dev/null; then
        ref_type="branch"
    elif git show-ref -q --verify "refs/tags/${normalized_ref}" 2>/dev/null; then
        ref_type="tag"
    elif git show-ref -q --verify "refs/remotes/${remote}/${normalized_ref}" 2>/dev/null; then
        ref_type="remote"
    elif git rev-parse --verify "${normalized_ref}^{commit}" >/dev/null 2>&1; then
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

# returns 0 if the ref is a branch, 1 otherwise
function ref-is-branch() {
    local ref="${1}"
    local ref_type=$(get-ref-type "${ref}")

    [ "${ref_type}" = "branch" ] || [ "${ref_type}" = "remote" ]
}

# returns 0 if the ref is a tag, 1 otherwise
function ref-is-tag() {
    local ref="${1}"
    local ref_type=$(get-ref-type "${ref}")

    [ "${ref_type}" = "tag" ]
}

# returns 0 if the ref is a commit, 1 otherwise
function ref-is-commit() {
    local ref="${1}"
    local ref_type=$(get-ref-type "${ref}")

    [ "${ref_type}" = "commit" ]
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

# @description Determine if an object is a blob, tree, or commit
# @usage is-blob-tree-or-commit <object>
# @example is-blob-tree-or-commit HEAD
# @example is-blob-tree-or-commit ./path/to/file
# @example is-blob-tree-or-commit ./path/to/dir/
function is-blob-tree-or-commit() {
    local object="${1}"
    local object_type
    local is_ref=false
    local is_file=false
    local is_dir=false

    if [ -z "${object}" ]; then
        return 1
    fi

    # determine if this is a ref
    local ref_type=$(get-ref-type "${object}")
    [[ "${ref_type}" != "unknown" ]] && is_ref=true

    # determine if this is a blob or tree
    ## get the object hash
    local relpath=$(git-relpath "${object}")
    local object_hash=$(git ls-tree HEAD "${relpath}" | awk '{print $3}')
    if git cat-file -t "${object_hash}" 2>/dev/null | grep -q "^blob$"; then
        is_file=true
    elif git cat-file -t "${object_hash}" 2>/dev/null | grep -q "^tree$"; then
        is_dir=true
    elif git cat-file -t "${object_hash}" 2>/dev/null | grep -q "^commit$"; then
        is_ref=true
    fi

    # determine the output
    if (${is_ref} && ${is_file}) \
    || (${is_ref} && ${is_dir}) \
    || (${is_file} && ${is_dir}); then
        echo "ambiguous"
    elif ${is_ref}; then
        echo "commit"
    elif ${is_file}; then
        echo "blob"
    elif ${is_dir}; then
        echo "tree"
    else
        return 1
    fi
}

# determine if an object is a ref or a file (or ambiguous). outputs:
#   stdout      exit code
#   ----------  ----------
#   ref         0
#   file        0
#   ambiguous   1
#               2 (if the object is not a ref or a file)
# TODO: improve this for remote refs
function is-ref-or-file() {
    local object="${1}"

    # determine if this is a ref
    local ref_type=$(get-ref-type "${object}")

    # if it's unknown, check to see if it's a currently untracked remote branch
    if [[ "${ref_type}" == "unknown" ]]; then
        # remove a remote prefix if it exists
        object="${object#$(git remote)/}"
        if git show-ref -q --verify "refs/remotes/$(git remote)/${object}" 2>/dev/null; then
            ref_type="branch"
        fi
    fi

    local has_been_tracked=$(
        git log -1 \
            --all \
            --pretty=format: \
            --name-only \
            --diff-filter=A \
            --no-renames \
            -- "${object}" \
                | grep -q '.'
        echo  $?
    )

    local output exit_code
    if [[ "${ref_type}" == "unknown" ]]; then
        if [ "${has_been_tracked}" -eq 0 ]; then
            # if it's not a ref, but it's been tracked, it's a file
            output="file"
            exit_code=0
        else
            # if it's not a ref, and it's not been tracked, it's nothing
            exit_code=2
        fi
    else
        if [ "${has_been_tracked}" -eq 0 ]; then
            # if it's a ref, and it's been tracked as a file, it's ambiguous
            output="ambiguous"
            exit_code=1
        else
            # if it's a ref, and it's not been tracked, it's a ref
            output="ref"
            exit_code=0
        fi
    fi

    [ -n "${output}" ] && echo "${output}"
    return ${exit_code}
}

# @description: Determine where a config setting is coming from
# @param: $1 - the config setting to check
# @usage: config-source <setting>
# @example: config-source core.editor
# @example: [ "$(config-source core.editor)" = "global" ] && echo "set globally"
# @echoes: "global", "local", "system", "argument", "unset"
# @returns: 0 = setting found, 1 = setting not found
function config-source() {
    local setting="${1}"
    local source

    if [ -z "${setting}" ]; then
        echo "usage: config-source <setting>" >&2
        return 1
    fi

    # get the current value of the setting
    local value=$(git config --get "${setting}")

    # if the value is empty, the setting is unset
    if [ -z "${value}" ]; then
        echo "unset"
        return 1
    fi

    # determine if the value matches the system config
    local system_value=$(git config --system --get "${setting}")
    if [ "${value}" = "${system_value}" ]; then
        echo "system"
        return 0
    fi

    # determine if the value matches the global config
    local global_value=$(git config --global --get "${setting}")
    if [ "${value}" = "${global_value}" ]; then
        echo "global"
        return 0
    fi

    # determine if the value matches the local config
    local local_value=$(git config --local --get "${setting}")
    if [ "${value}" = "${local_value}" ]; then
        echo "local"
        return 0
    fi

    # if the value is set but doesn't match any of the configs, it was set as an
    # argument
    echo "argument"
    return 0
}

# @description: Return insertion/deletion stats for each user in a git repo
function git-user-stats() {
    local git_opts=( "$@" )

    git log "${git_opts[@]}" --format='author: %ae' --numstat \
        | tr '[A-Z]' '[a-z]' \
        | grep -v '^$' \
        | grep -v '^-' \
        | awk '
            {
                if ($1 == "author:") {
                    author = $2;
                    commits[author]++;
                } else {
                    insertions[author] += $1;
                    deletions[author] += $2;
                    total[author] += $1 + $2;
                    # if this is the first time seeing this file for this
                    # author, increment their file count
                    author_file = author ":" $3;
                    if (!(author_file in seen)) {
                        seen[author_file] = 1;
                        files[author]++;
                    }
                }
            }
            END {
                # Print a header in the format:
                #   Email\tCommits\tFiles\tInsertions\tDeletions\tTotal Lines\n
                printf("%-30s\t%-10s\t%-10s\t%-10s\t%-10s\t%-10s\n",
                       "Email", "Commits", "Files", "Insertions", "Deletions", "Total Lines");
                printf("%-30s\t%-10s\t%-10s\t%-10s\t%-10s\t%-10s\n",
                       "-----", "-------", "-----", "----------", "---------", "-----------");

                # Print the stats for each user, sorted by total lines
                n = asorti(total, sorted_emails, "@val_num_desc");
                for (i = 1; i <= n; i++) {
                    email = sorted_emails[i];
                    printf("%-30s\t%-10s\t%-10s\t%-10s\t%-10s\t%-10s\n",
                           email, commits[email], files[email],
                           insertions[email], deletions[email], total[email]);
                }
            }
    '
}
