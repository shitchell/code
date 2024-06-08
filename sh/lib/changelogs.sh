# TODO: the below function (originally from `files.sh`) is far *faster* but
# TODO: produces erroneous output (switches added/deleted files). the version
# TODO: below it produces correct output but takes ~15x longer to run. look at
# TODO: getting the speed of this version but... correct
function generate-changelog() {
    :  'Generate a git-style name-status changelog between two directories

        Given two directories, generate a name-status changelog that describes
        the changes between the two directories. The changelog is sorted by
        filename.

        @usage
            [-x/--exclude <regex>] <source-dir> <target-dir>

        @arg -x/--exclude <regex>
            A regex pattern to exclude files from the comparison

        @arg <source-dir>
            The source directory to compare

        @arg <target-dir>
            The target directory to compare

        @stdout
            The name-status changelog
    '
    local source_dir
    local target_dir
    local exclude_patterns=()

    # Parse the options
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -x | --exclude)
                exclude_patterns+=("${2}")
                shift 2
                ;;
            -*)
                echo "error: unknown option: ${1}" >&2
                return ${E_ERROR}
                ;;
            *)
                if [[ -n "${target_dir}" ]]; then
                    echo "error: too many arguments" >&2
                    return 1
                fi
                [[ -z "${source_dir}" ]] && source_dir="${1}" || target_dir="${1}"
                shift 1
                ;;
        esac
    done

    local created_files=()
    local deleted_files=()
    local shared_files=()
    local changelog=()

    if [[ ! -d "${source_dir}" ]]; then
        echo "error: source directory does not exist: ${source_dir}" >&2
        return ${E_ERROR}
    fi

    if [[ ! -d "${target_dir}" ]]; then
        echo "error: target directory does not exist: ${target_dir}" >&2
        return ${E_ERROR}
    fi

    local source_files=()
    local target_files=()
    local source_file
    local target_file
    local filepath
    local source_md5
    local target_md5
    local file_sizes
    local file_bits
    local source_bits
    local target_bits
    local source_size
    local target_size
    local change_mode

    # Collect the source files as relative paths
    while IFS= read -r -d '' source_file; do
        # Skip files that match the exclude patterns
        for pattern in "${exclude_patterns[@]}"; do
            if [[ "${source_file}" =~ ${pattern} ]]; then
                continue 2
            fi
        done
        source_files+=("${source_file}")
    done < <(find "${source_dir}" -type f -printf "%P\0")

    # Collect the target files as relative paths
    while IFS= read -r -d '' target_file; do
        # Skip files that match the exclude patterns
        for pattern in "${exclude_patterns[@]}"; do
            if [[ "${target_file}" =~ ${pattern} ]]; then
                continue 2
            fi
        done
        target_files+=("${target_file}")
    done < <(find "${target_dir}" -type f -printf "%P\0")

    # Determine the created, modified, and shared files
    readarray -t created_files < <(
        comm -23 \
            <(printf "%s\n" "${source_files[@]}" | sort) \
            <(printf "%s\n" "${target_files[@]}" | sort)
    )
    readarray -t deleted_files < <(
        comm -13 \
            <(printf "%s\n" "${source_files[@]}" | sort) \
            <(printf "%s\n" "${target_files[@]}" | sort)
    )
    readarray -t shared_files < <(
        comm -12 \
            <(printf "%s\n" "${source_files[@]}" | sort) \
            <(printf "%s\n" "${target_files[@]}" | sort)
    )

    # Compare the shared files
    for filepath in "${shared_files[@]}"; do
        change_mode=""

        source_file="${source_dir}/${filepath}"
        target_file="${target_dir}/${filepath}"

        if [[ -f "${target_file}" ]]; then
            # Do a size comparison first
            file_sizes=$(stat -c %s "${source_file}" "${target_file}" 2>/dev/null)

            if [[ -n "${file_sizes}" ]]; then
                source_size="${file_sizes%%$'\n'*}"
                target_size="${file_sizes##*$'\n'}"

                # If the sizes are different, the files are different
                if [[ "${source_size}" -ne "${target_size}" ]]; then
                    change_mode="M"
                else
                    # If the sizes are the same, do an md5 comparison
                    source_md5=$(md5sum < "${source_file}")
                    source_md5="${source_md5//[^a-f0-9]/}"
                    target_md5=$(md5sum < "${target_file}")
                    target_md5="${target_md5//[^a-f0-9]/}"

                    if [[ "${source_md5}" != "${target_md5}" ]]; then
                        change_mode="M"
                    fi
                fi
            fi

            # Do a bit comparison
            file_bits=$(stat -c %a "${source_file}" "${target_file}" 2>/dev/null)
            source_bits="${file_bits%%$'\n'*}"
            target_bits="${file_bits##*$'\n'}"

            if [[ "${source_bits}" != "${target_bits}" ]]; then
                change_mode="M"
            fi
        else
            # If we get here... wat
            change_mode="D"
            echo "error: deleted file caught in shared files: ${filepath}" >&2
        fi

        if [[ -n "${change_mode}" ]]; then
            changelog+=("${change_mode}"$'\t'"${filepath}")
        fi
    done

    # Add the created files to the changelog
    for filepath in "${created_files[@]}"; do
        changelog+=("A"$'\t'"${filepath}")
    done

    # Add the deleted files to the changelog
    for filepath in "${deleted_files[@]}"; do
        changelog+=("D"$'\t'"${filepath}")
    done

    # Print the changelog, sorted by filename
    printf "%s\n" "${changelog[@]}" | sort -k2
}

# @description Given two directories, generate a name-status changelog
# @usage generate-changelog [-x/--exclude <regex>] <source-dir> <target-dir>
function generate-changelog() {
    local source_dir
    local target_dir
    local exclude_patterns=()

    # Parse the options
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -x | --exclude)
                exclude_patterns+=("${2}")
                shift 2
                ;;
            -*)
                echo "error: unknown option: ${1}" >&2
                return ${E_ERROR}
                ;;
            *)
                if [[ -n "${target_dir}" ]]; then
                    echo "error: too many arguments" >&2
                    return 1
                fi
                [[ -z "${source_dir}" ]] && source_dir="${1}" || target_dir="${1}"
                shift 1
                ;;
        esac
    done

    if [[ ! -d "${source_dir}" ]]; then
        echo "error: source directory does not exist: ${source_dir}" >&2
        return ${E_ERROR}
    fi

    if [[ ! -d "${target_dir}" ]]; then
        echo "error: target directory does not exist: ${target_dir}" >&2
        return ${E_ERROR}
    fi

    local changelog=()
    local filepaths=()
    local filepath
    local change_mode
    local source_file
    local target_file
    local source_md5
    local target_md5
    local file_sizes
    local file_bits
    local source_bits
    local target_bits
    local source_size
    local target_size

    # Collect all filepaths
    while read -r filepath; do
        # Skip excluded files
        for pattern in "${exclude_patterns[@]}"; do
            if [[ "${filepath}" =~ ${pattern} ]]; then
                continue 2
            fi
        done
        filepaths+=("${filepath}")
    done < <(find "${source_dir}" "${target_dir}" -type f -printf "%P\n" | sort -u)

    # Compare the files
    for filepath in "${filepaths[@]}"; do
        change_mode=""

        source_file="${source_dir}/${filepath}"
        target_file="${target_dir}/${filepath}"

        if [[ -f "${source_file}" && ! -f "${target_file}" ]]; then
            # If the file is in the source but not in the target, it's deleted
            change_mode="D"
        elif [[ ! -f "${source_file}" && -f "${target_file}" ]]; then
            # If the file is in the target but not in the source, it's created
            change_mode="A"
        elif [[ -f "${source_file}" && -f "${target_file}" ]]; then
            # If the file is in both the source and the target, determine if
            # it's been changed in the target

            ## Do a size comparison first
            file_sizes=$(stat -c %s "${source_file}" "${target_file}" 2>/dev/null)

            if [[ -n "${file_sizes}" ]]; then
                source_size="${file_sizes%%$'\n'*}"
                target_size="${file_sizes##*$'\n'}"

                # If the sizes are different, the files are different
                if [[ "${source_size}" -ne "${target_size}" ]]; then
                    change_mode="M"
                else
                    # If the sizes are the same, do an md5 comparison
                    source_md5=$(md5sum < "${source_file}")
                    source_md5="${source_md5//[^a-f0-9]/}"
                    target_md5=$(md5sum < "${target_file}")
                    target_md5="${target_md5//[^a-f0-9]/}"

                    if [[ "${source_md5}" != "${target_md5}" ]]; then
                        change_mode="M"
                    fi
                fi
            fi

            ## Do a bit / access rights comparison
            file_bits=$(stat -c %a "${source_file}" "${target_file}" 2>/dev/null)
            source_bits="${file_bits%%$'\n'*}"
            target_bits="${file_bits##*$'\n'}"

            if [[ "${source_bits}" != "${target_bits}" ]]; then
                change_mode="M"
            fi
        else
            # If we get here... wat
            change_mode="X"
            echo "error: filepath not in either directory: ${filepath}" >&2
        fi

        if [[ -n "${change_mode}" ]]; then
            changelog+=("${change_mode}"$'\t'"${filepath}")
        fi
    done

    # Print the changelog
    printf "%s\n" "${changelog[@]}"
}

# @description Given a changelog, determine the type of changelog
# @usage get-changelog-type [-n/--lines <int>] <changelog>
function get-changelog-type() {
    local changelog_filepath
    local changelog
    local lines="" # default to all lines

    # Parse the options
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            --lines)
                lines="${2}"
                shift 2
                ;;
            -)
                if [[ -n "${changelog_filepath}" ]]; then
                    echo "error: too many arguments" >&2
                    return 1
                fi
                changelog_filepath="${1}"
                shift 1
                ;;
            -*)
                echo "error: unknown option: ${1}" >&2
                return 1
                ;;
            *)
                if [[ -n "${changelog_filepath}" ]]; then
                    echo "error: too many arguments" >&2
                    return 1
                fi
                changelog_filepath="${1}"
                shift 1
                ;;
        esac
    done

    if [[ -z "${changelog_filepath}" ]]; then
        echo "usage: get-changelog-type <changelog>"
        return 1
    fi

    if [[ "${changelog_filepath}" == "-" ]]; then
        changelog_filepath="/dev/stdin"
    fi

    changelog=$(<"${changelog_filepath}")

    # Validate the lines option
    if [[ -n "${lines}" ]]; then
        if [[ "${lines}" == "all" ]]; then
            lines=""
        elif [[ ! "${lines}" =~ ^[0-9]+$ ]]; then
            echo "error: invalid line count: ${lines}" >&2
            return 1
        fi
        changelog=$(head -n "${lines}" <<< "${changelog}")
    fi

    local name_status_line_count=0
    local name_only_line_count=0
    while read -r line; do
        # Skip empty lines
        [[ "${line}" == "" ]] && continue

        if [[ "${line}" =~ ^([A-QS-Z]|R[0-9]{1,3})$'\t' ]]; then
            ((name_status_line_count++))
        else
            ((name_only_line_count++))
        fi
    done <<< "${changelog}"

    if [[
        "${name_status_line_count}" -gt 0
        && "${name_only_line_count}" -eq 0
    ]]; then
        echo "name-status"
    elif [[
        "${name_status_line_count}" -eq 0
        && "${name_only_line_count}" -gt 0
    ]]; then
        echo "name-only"
    else
        echo "mixed"
    fi
}

# @description Take a changelog and convert it to name-only if it is not already
# @usage normalize-changelog <changelog>
function normalize-changelog() {
    local changelog_filepath="${1:-/dev/stdin}"
    local changelog=$(<"${changelog_filepath}")

    # TODO: handle renames where a filename contains a tab?
    awk -F $'\t' '
        function print_unique(line) {
            if (seen[line]++) {
                return
            }
            print line
        }
        {
        # If the line does not contain a tab, just print it
        if (NF == 1) {
            print_unique($0)
            next
        }

        # If it contains a tab, try to parse it
        mode = $1
        mode_char = substr(mode, 1, 1)

        if (mode_char == "R") {
            # If the mode is "R", validate that there are 2 filenames and print
            # them on separate lines
            if (NF != 3) {
                print "error: invalid rename line: " $0 > "/dev/stderr"
                next
            }
            file1 = $2
            file2 = $3
            print_unique(file1)
            print_unique(file2)
        } else {
            # If the mode is not "R", print the filename
            gsub(/^[A-Z0-9]{1,5}\t/, "")
            print_unique($1)
        }
    }' <<< "${changelog}"
}

# @description Read a name-status changelog into an associative array
# @usage read-changelog <file> [<array-name>]
function read-changelog() {
    local filepath="${1}"
    local array_name="${2:-CHANGELOG}"

    # Check to see if the array name was provided and exists
    if [[ -n "${array_name}" ]]; then
        if ! declare -p "${2}" &>/dev/null; then
            # Declare it globally
            debug "declaring global associative array: ${array_name}"
            declare -gA "${array_name}"
        else
            debug "using existing associative array: ${array_name}"
            if debug; then
                debug "$(declare -p "${array_name}")"
            fi
        fi
    fi
    declare -gn array="${array_name}"
    
    [[ "${filepath}" == "-" ]] && filepath="/dev/stdin"

    if [[ -z "${filepath}" ]]; then
        echo "error: no file provided" >&2
        return ${E_ERROR:-1}
    fi

    while IFS= read -r line; do
        debug "line: ${line}"
        local mode="${line%%$'\t'*}"
        local file="${line#*$'\t'}"
        debug-vars mode file
        array["${file}"]="${mode}"
    done < "${filepath}"

    if debug; then
        debug "array: ${array_name}"
        debug "$(declare -p "${array_name}")"
    fi
}

function test-declare-n() {
    local is_first=true

    for varname in "${@}"; do
        ${is_first} && is_first=false || echo

        declare -n var="${varname}"

        # Determine the type of the variable
        vartype=$(
            declare -p "${varname}" 2>/dev/null | grep -oP 'declare -\K[^ ]+'
        ) || vartype="?"
        printf 'pre:  %s\n' "$(declare -p "${varname}" 2>&1)"
        local test_key="test_key_${RANDOM}"
        local test_str="test_str_${RANDOM}"
        case "${vartype}" in
            a)
                var+=("${test_str}")
                ;;
            A)
                var["${test_key}"]="${test_str}"
                ;;
            i)
                var=$((var + 1))
                ;;
            x)
                ;;
            -)
                var="${test_str}"
                ;;
            *)
                var="${test_str}"
                ;;
        esac
        printf 'post: %s\n' "$(declare -p "${varname}" 2>&1)"
    done
}
