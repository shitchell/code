#!/usr/bin/env bash
#
# Loop over the devapi directories and set them up with correct permissions

OWNER="devapi"
GROUP_ADMIN="devapi-admin"
GROUP_USERS="devapi"
DEVAPI_DIR="/u02/www"

C_RED=$'\033[31m'
C_GREEN=$'\033[32m'
C_BLUE=$'\033[34m'
C_MAGENTA=$'\033[35m'
C_CYAN=$'\033[36m'
C_WHITE=$'\033[37m'
S_RESET=$'\033[0m'
S_BOLD=$'\033[1m'
S_DIM=$'\033[2m'
C_CODE="${C_CYAN}"
C_DIR="${S_BOLD}${C_BLUE}"
C_SUCCESS="${C_GREEN}"
C_ERR="${C_RED}"

# Ensure user is root
if [[ "$(id -u)" != 0 ]]; then
    echo "error: must be root" >&2
    exit 69
fi

if [[ ${#} -gt 0 ]]; then
    DIRS=( "${@}" )
else
    readarray -t DIRS < <(
        find "${DEVAPI_DIR}" -maxdepth 1 -type d -name 'devapi*'
    )
fi

for d in "${DIRS[@]}"; do
    d=$(realpath "${d}")
    dname=$(basename "${d}")

    # Don't process any directories that aren't `/u02/www/devapi*`
    if [[ "${d}" != "${DEVAPI_DIR}/devapi"* ]]; then
        echo "error: invalid devapi directory: ${C_DIR}${d}${S_RESET}" >&2
        exit 1
    fi

    # Allow non-privileged users in devapi-sbx.
    # For everything else, devapi admins only.
    if [[ "${dname}" == "devapi-sbx" ]]; then
        group="${GROUP_USERS}"
    else
        group="${GROUP_ADMIN}"
    fi

    # Set the owner/group on all files
    echo -n "* setting owner:group to ${C_CODE}${OWNER}:${group}${S_RESET} on '${C_DIR}${d}${S_RESET}' ... "
    output=$(chown -R "${OWNER}:${group}" -- "${d}")
    if [[ ${?} -ne 0 ]]; then
        echo "${C_ERROR}error${S_RESET}"
        echo "${output}" >&2
        exit 1
    fi
    echo "${C_SUCCESS}done${S_RESET}"

    # Set directories to readable, writable, executable for the owner and group,
    # and set the group permissions to be sticky (applied to all new files)
    perms="u=rwx,g=rwxs,o="
    echo -n "* setting directories to ${C_CODE}${perms}${S_RESET} in '${C_DIR}${d}${S_RESET}' ... "
    output=$(find "${d}" -type d | xargs -I{} chmod ${perms} -- {})
    if [[ ${?} -ne 0 ]]; then
        echo "${C_ERROR}error${S_RESET}"
        echo "${output}" >&2
        exit 1
    fi
    echo "${C_SUCCESS}done${S_RESET}"

    # Set files to readable and writable by user and group
    perms="u+rw,g+rw,o="
    echo -n "* setting files to ${C_CODE}${perms}${S_RESET} in '${C_DIR}${d}${S_RESET}' ... "
    output=$(find "${d}" -type f | xargs -I{} chmod ${perms} -- {})
    if [[ ${?} -ne 0 ]]; then
        echo "${C_ERROR}error${S_RESET}"
        echo "${output}" >&2
        exit 1
    fi
    echo "${C_SUCCESS}done${S_RESET}"
done
