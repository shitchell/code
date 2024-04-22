#!/bin/bash
#
# Find duplicates in the specified column of a TSV file

column=${1}
file=${2}

# If the file is "-", use stdin
if [ "${file}" = "-" ]; then
    data=$(cat)
else
    data=$(cat "${file}")
fi

echo "${data}" \
    | awk -v col="${column}" -F $'\t' '
        {
            # Check if the specified column is stored in the array
            if (seen[$col]) {
                # The first time we run into a duplicate, we need to copy the
                # original value into the duplicates array and then add the
                # duplicate
                if (duplicates[$col] == "") {
                    duplicates[$col] = seen[$col];
                }
                # Add the line to the duplicates array
                duplicates[$col] = duplicates[$col] "\n" $0;
            }
            # Add it to the array
            seen[$col] = $0;
        }
        END {
            # Print the duplicates
            for (key in duplicates) {
                print duplicates[key];
            }
        }'
