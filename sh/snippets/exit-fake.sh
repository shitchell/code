function exit() { code=${1:-0}; [[ "${code}" == "0" ]] && color=$'\033[32m' || color=$'\033[33m'; echo -e "\033[1mexit: ${color}${code}\033[0m"; }
