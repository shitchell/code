#!/usr/bin/env bash
#
# Print the longest line of the given input

input_str="${1:- $'short\nmuch longer than short\na little longer'}"
echo "Using input: $(declare -p input_str)"

# Single command - awk
echo "-- AWK --"

# awk '
#   BEGIN {
#     longest_len=-1;
#     longest_str="";
#   }
#   {
#     this_len = length($0);
#     if (this_len > longest_len) {
#       longest_len = this_len;
#       longest_str = $0;
#     }
#   }
#   END {
#     if (longest_len > -1) {
#       print longest_str " (" longest_len ")"
#     }
#   }
# ' <<< "${input_str}"
awk '
    {
        if (length($0) > longest_len) {
                longest_len = length($0)
                longest_str = $0
        }
    }
    END {
        print longest_str
    }
' <<< "${input_str}"
awk '{if (length > max_l) {max_l = length; max_s = $0}}END{print max_s}' <<< "${input_str}"
echo

# Bash
echo "-- BASH --"
declare -i longest_len this_len
declare -- longest_str

while read -r line; do
  this_len="${#line}"
  ((this_len > longest_len)) && {
    longest_len=${this_len}
    longest_str="${line}"
  }
done <<< "${input_str}"
[[ -n "${longest_str+x}" ]] && echo "${longest_str}" || echo "fatal: empty input"

