function mkuniq() {
    :  'Create a unique filename

        Given a filename, create a unique filename by appending a number to the
        end of the filename. If the filename already exists, increment the
        number until a unique filename is found.

        @usage
            <filename>

        @arg filename
            The filename to make unique

        @stdout
            The unique filename
    '
    local filename="${1}"

    if [ -f "${filename}" ]; then
        local n=1
        while [[ -f "${filename}.${n}" ]]; do
            n=$((n+1))
        done
        filename="${filename}.${n}"
    fi

    echo "${filename}"
}

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
