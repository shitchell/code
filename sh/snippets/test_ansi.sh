#!/bin/bash

# print a header for the style table, with each column header bold and padded to
# 10 characters. Each column header is a description of the ansi style 01-10
# applied to the column number 30-49
columns=(
    "RESET"
    "BOLD"
    "DIM"
    "ITALIC"
    "UNDERLINE"
    "BLINK"
    "BLINK_FAST"
    "REVERSE"
    "HIDDEN"
    "CROSSED_OUT"
    "DEFAULT"
)
rows=(
    "FG_BLACK"
    "FG_RED"
    "FG_GREEN"
    "FG_YELLOW"
    "FG_BLUE"
    "FG_MAGENTA"
    "FG_CYAN"
    "FG_WHITE"
    "FG_RGB"
    "FG_DEFAULT"
    "BG_BLACK"
    "BG_RED"
    "BG_GREEN"
    "BG_YELLOW"
    "BG_BLUE"
    "BG_MAGENTA"
    "BG_CYAN"
    "BG_WHITE"
    "BG_RGB"
    "BG_DEFAULT"
)

printf "%12s \e[1m%-12s %-12s %-12s %-12s %-12s %-12s %-12s %-12s %-12s %-12s %s\e[0m\n" "" "${columns[@]}"

i=0
for i_col in `seq 30 49`; do
    [[ $((i % 11)) -eq 0 ]] && printf "\e[1m%-12s\e[0m " "${rows[$((i_col - 30))]}"

    for s_col in `seq 0 10`; do
        printf "\e[%i;%im\\\e[%i;%02im\e[0m" \
            "${i_col}" "${s_col}" "${i_col}" "${s_col}"
        if [[ $((++i % 11)) -eq 0 ]]; then
            echo
        else
            printf "    "
        fi
    done
done

echo

# test extended color support
color_support=$(tput colors)
cs_pad=$(printf "${color_support}" | wc -c)

# Print "Terminal supports ${color_support} colors" with a rainbow of colors and
# the color support in RGB (1st char = Red, 2nd char = Green, 3rd char = Blue)
# echo -e "\e[35mTerminal supports \e[36;1m${color_support}\e[0m \e[35mcolors\e[0m"
first_part="Terminal supports "
second_part="${color_support}"
third_part=" colors"
while IFS= read -r -n1 char; do
    printf "\e[38;5;%im%s" "$(((RANDOM % color_support) + 1))" "${char}"
done <<< "${first_part}"
color_support_colors=(31 32 34)
i=0
while read -r -n1 char; do
    printf "\e[1;%im%s" "${color_support_colors[$((i++ % 3))]}" "${char}"
done <<< "${second_part}"
printf '\e[0m'
while IFS= read -r -n1 char; do
    printf "\e[38;5;%im%s" "$(((RANDOM % color_support) + 1))" "${char}"
done <<< "${third_part}"
printf '\e[0m\n'

n=0
include-source debug.sh
needs_newline=true
for ((i=0; i<color_support; i++)); do
    # debug "[$i/$color_support] printing line $(printf "\e[38;5;%im\\\e[38;5;%0${cs_pad}im\e[0m" "${i}" "${i}")"
    printf "\e[38;5;%im\\\e[38;5;%0${cs_pad}im\e[0m" "${i}" "${i}"

    # for i < 16, print 4 colors per line
    # for i >= 16, print 6 colors per line, shifted by 2
    if [[ ${i} -lt 16 ]]; then
        n=4 s=0
    else
        # n=7 and n=9 will not yield equal rows for 256 colors
        #n=5 s=4
        n=6  s=2
        # n=8  s=0
        # n=10 s=4
    fi
    if [[ $(((i + s) % n)) -eq $((n - 1)) ]]; then
        echo
        needs_newline=false
    else
        printf "    "
        needs_newline=true
    fi
done
${needs_newline} && echo

    # [[ "${i}" == "16" ]] && n=3
    # if [[ $(((i + n) % 6)) -eq 0 || ${i} -eq 15 ]]; then
    #     echo
    # else
    #     printf "    "
    # fi
