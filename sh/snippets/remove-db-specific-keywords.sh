#!/usr/bin/env bash
#
# A simple one-shot script to remove database-specific keywords from a list of
# SQL files.
#
# For now, we're looking for the following keywords:
# * TABLESPACE
# * PCTFREE    \d+
# * INITRANS   \d+
# * MAXTRANS   \d+
# * STORAGE    (
#               ...
#              )
#
# Usage:
#   remove-db-specific-keywords.sh <file1> <file2> ...

# ---- imports -----------------------------------------------------------------
include-source 'colors'
setup-colors

# ---- args --------------------------------------------------------------------
FILEPATHS=("${@}")

# ---- main --------------------------------------------------------------------
for filepath in "${FILEPATHS[@]}"; do
    echo "# ${S_BOLD}${filepath}${S_RESET}"
    {
        if [[ ! -f "${filepath}" ]]; then
            echo "error: file not found: ${filepath}"
            continue
        fi

        # Create a temporary file to store the modified content
        # This is necessary because we can't modify the file in-place with `awk`
        echo -n "* creating temporary file... "
        TMPFILE=$(mktemp) && echo "${C_GREEN}done${S_RESET}" || {
            echo "${C_RED}error${S_RESET}"
            echo "failed to create temporary file"
            continue
        }

        # Remove the keywords from the file with `awk` so that we can handle STORAGE
        # settings that span multiple lines
        echo "* removing keywords... "
        awk -v dim="${S_DIM}" -v bold="${S_BOLD}" -v reset="${S_RESET}" \
            -v green="${C_GREEN}" -v red="${C_RED}" -v cyan="${C_CYAN}" '
            BEGIN {
                in_storage = 0
                lines_removed_count = 0
                lines_removed = ""
            }

            {
                if ($0 ~ /TABLESPACE|PCTFREE|INITRANS|MAXTRANS/) {
                    lines_removed_count++
                    lines_removed = lines_removed $0 "\n"
                    next
                }

                if ($0 ~ /STORAGE/) {
                    lines_removed_count++
                    if ($0 ~ /\(/) {
                        in_storage = 1
                    }
                }

                if (in_storage) {
                    if ($0 ~ /\)/) {
                        in_storage = 0
                    }
                    lines_removed = lines_removed $0 "\n"
                    next
                }

                print
            }

            END {
                if (lines_removed_count > 0) {
                    printf("  %sRemoved %s%d%s line(s) from %s%s%s:%s\n",
                        bold, cyan, lines_removed_count, reset bold,
                        green, FILENAME, reset bold, reset) > "/dev/stderr"
                    # Print the removed lines with a 2 space indentation
                    split(lines_removed, lines_array, "\n")
                    for (i = 1; i <= length(lines_array); i++) {
                        printf("    %s%s%s\n",
                            red, lines_array[i], reset) > "/dev/stderr"
                    }
                }
            }
        ' "${filepath}" > "${TMPFILE}" && echo "* removing keywords ... ${C_GREEN}done${S_RESET}" || {
            echo "* removing keywords ... ${C_RED}error${S_RESET}"
            echo "failed to remove keywords"
            continue
        }

        # Replace the original file with the modified content only; don't update any
        # other metadata (timestamp, ownership, permissions...)
        echo -n "* updating file... "
        cat "${TMPFILE}" > "${filepath}" && echo "${C_GREEN}done${S_RESET}" || {
            echo "${C_RED}error${S_RESET}"
            echo "failed to update file"
            continue
        }

        # Remove the temporary file
        echo -n "* removing temporary file... "
        rm "${TMPFILE}" && echo "${C_GREEN}done${S_RESET}" || {
            echo "${C_RED}error${S_RESET}"
            echo "failed to remove temporary file"
            continue
        }
    } |& sed 's/^/  /'
done