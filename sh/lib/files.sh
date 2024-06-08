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

function is-java-class() {
    :  'Determine if a file is a java class

        @usage
            <file>

        @stdout
            The specified filepath and its java type (class, groovy, jar)

        @stderr
            Any error messages

        @return 0
            The file is a java class

        @return 1
            The file is not a java class

        @return 2
            No file was specified

        @return 3
            The file does not exist or is not readable

        @return 4
            The file is a directory

        @return 5
            The file is a symlink

        @return 6
            The file has no extension

        @return 7
            The file has an invalid extension
    '

    local filepath="${1}"
    local filename=$(basename "${filepath%.*}")
    local extension

    # Use /dev/stdin if "-" was passed
    [[ "${filepath}" == "-" ]] && filepath="/dev/stdin"

    # Determine the extension
    if [[ "${filepath}" == "/dev/stdin" ]]; then
        extension="java"
        echo "${filepath}: warning: skipping extension and filename validations" >&2
    elif [[ "${filepath}" =~ \. ]]; then
        extension="${filepath##*.}"
    fi

    # Make sure a filepath was given
    if [[ -z "${filepath}" ]]; then
        echo "error: no filepath specified" >&2
        return 2
    fi

    # Perform some file / filename checks if not reading from stdin
    if [[ "${filepath}" != "/dev/stdin" ]]; then
        # Check if the filepath is a directory
        if [[ -d "${filepath}" ]]; then
            echo "${filepath}: error: is a directory" >&2
            return 4
        fi

        # Check if it's a symlink
        if [[ -L "${filepath}" ]]; then
            # If we're not following symlinks, exit with an error
            if [[ ${FOLLOW_SYMLINKS} -eq 0 ]]; then
                echo "${filepath}: error: is a symlink" >&2
                return 5
            fi

            # Otherwise, get the real path
            filepath=$(readlink -f "${filepath}")
            if [[ $? -ne 0 ]]; then
                echo "${filepath}: error: failed to read symlink '${filepath}'" >&2
                return 5
            fi

            # And call this function again
            is-java-class "${filepath}"
            return ${?}
        fi

        # Check for an extension
        if [[ -z "${extension}" ]]; then
            echo "${filepath}: error: no extension" >&2
            return 6
        fi

        # Check that the extension is "java", "class", "jar", or "groovy"
        if [[
            "${extension}" != "java"
            && "${extension}" != "class"
            && "${extension}" != "jar"
            && "${extension}" != "groovy"
        ]]; then
            echo "${filepath}: error: invalid extension '.${extension}'" >&2
            return 7
        fi

        # ...and that the file exists
        if [[ ! -f "${filepath}" ]]; then
            echo "${filepath}: error: file '${filepath}' does not exist" >&2
            return 3
        fi

        # If the extension is "jar" or "class", do a `file` check
        if [[ "${extension}" == "jar" || "${extension}" == "class" ]]; then
            file_info=$(file "${filepath}")
            if [[ "${file_info}" =~ "Java class data" ]]; then
                echo "${filepath}: compiled java class"
                return 0
            elif [[ "${file_info}" =~ "Java archive data" ]]; then
                echo "${filepath}: compiled java archive"
                return 0
            else
                echo "${filepath}: error: file is not a java class" >&2
                return 1
            fi
        fi
    fi

    # Then read the file
    data=$(cat "${filepath}" 2>&1 | tr -d '\0')
    if [[ $? -ne 0 ]]; then
        echo "${filepath}: error: failed to read file '${filepath}'" >&2
        if [[ -n "${data}" ]]; then
            echo "${data}" >&2
        fi
        return 1
    fi

    # Make sure there's data
    if [[ -z "${data}" ]]; then
        echo "${filepath}: error: no file content to check" >&2
        return 1
    fi

    # Grep for the class declaration
    class_name=$(
        echo "${data}" \
            | grep -zoP '\n?(public\s+)?class\s+\K([^\s]+)(?=\s+{)' 2>/dev/null \
            | tr -d '\0'
    )

    # Finally, check that the class name matches the filename
    if [[ "${filepath}" == "/dev/stdin" ]]; then
        if [[ -n "${class_name}" ]]; then
            echo "/dev/stdin: java class"
            return 0
        else
            echo "/dev/stdin: error: file is not a java class" >&2
            return 1
        fi
    elif [[ -n "${class_name}" ]]; then
        if [[ "${class_name}" == "${filename}" ]]; then
            echo "${filepath}: java class"
            return 0
        else
            echo "${filepath}: error: class name '${class_name}' does not match filename '${filename}'" >&2
            return 1
        fi
    else
        echo "${filepath}: error: file is not a java class" >&2
        return 1
    fi
}
