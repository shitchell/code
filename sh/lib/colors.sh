# ANSI escape codes, using ANSI-C syntax to facilitate using them anywhere, even
# in `echo` commands without needing to use `echo -e`

C_BLACK=$'\033[30m'
C_RED=$'\033[31m'
C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'
C_BLUE=$'\033[34m'
C_MAGENTA=$'\033[35m'
C_CYAN=$'\033[36m'
C_WHITE=$'\033[37m'
C_RGB=$'\033[38;2;%d;%d;%dm'
C_DEFAULT_FG=$'\033[39m'
C_BLACK_BG=$'\033[40m'
C_RED_BG=$'\033[41m'
C_GREEN_BG=$'\033[42m'
C_YELLOW_BG=$'\033[43m'
C_BLUE_BG=$'\033[44m'
C_MAGENTA_BG=$'\033[45m'
C_CYAN_BG=$'\033[46m'
C_WHITE_BG=$'\033[47m'
C_RGB_BG=$'\033[48;2;%d;%d;%dm'
C_DEFAULT_BG=$'\033[49m'
S_RESET=$'\033[0m'
S_BOLD=$'\033[1m'
S_DIM=$'\033[2m'
S_ITALIC=$'\033[3m'  # not widely supported, sometimes treated as inverse
S_UNDERLINE=$'\033[4m'
S_BLINK=$'\033[5m'  # slow blink
S_BLINK_FAST=$'\033[6m'  # fast blink
S_REVERSE=$'\033[7m'
S_HIDDEN=$'\033[8m'  # not widely supported
S_STRIKETHROUGH=$'\033[9m'  # not widely supported
S_DEFAULT=$'\033[10m'
