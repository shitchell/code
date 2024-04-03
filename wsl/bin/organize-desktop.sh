#!/usr/bin/env bash
#
# Create a temporary directory on the Desktop to move things to, then move them
# back

include-source 'colors.sh'
include-source 'shell.sh'

# Where is yo desktop bruh
DESKTOP_DIRS=("${@}")
if [[ ${#} -eq 0 ]]; then
    # Desktop stuff is put in place both via the home desktop *and* the public
    # desktop because... why not
    DESKTOP_DIRS=(
        "/mnt/c/Users/Public/Desktop"
        "$(realpath --no-symlinks "${1:-${HOME}/Desktop}" 2>/dev/null)"
    )
fi

function clean-desktop() {
    DESKTOP_DIR="${1}"

    [[ -z "${DESKTOP_DIR}" ]] && {
        echo -e "${C_RED}error: no Desktop specified${S_RESET}" >&2
        exit 1
    }
    [[ ! -d "${DESKTOP_DIR}" ]] && {
        echo -e "${C_RED}error: invalid Desktop: ${DESKTOP_DIR}${S_RESET}" >&2
        exit 1
    }
    # Make a pretty version that either:
    # - replaces the leading home dir with ~
    # - uses a relative path if it's fewer chars
    # - ...is just the absolute path otherwise i guess
    DESKTOP_DIR_PRETTY="${DESKTOP_DIR}"
    DESKTOP_DIR_REL=$(realpath --no-symlinks --relative-to="${PWD}" "${DESKTOP_DIR}")
    if [[ "${DESKTOP_DIR}" == "${HOME}/"* ]]; then
        DESKTOP_DIR_PRETTY="~${DESKTOP_DIR#${HOME}}"
    elif [[ "${#DESKTOP_DIR_REL}" -lt "${#DESKTOP_DIR}" ]]; then
        DESKTOP_DIR_PRETTY="${DESKTOP_DIR_REL}"
    fi

    # Create a temporary directory
    echo -n "* creating temporary directory ... "
    TEMPDIR=$(
        mktemp --directory --tmpdir="${DESKTOP_DIR}" ".organize-desktop.XXXXXX" 2>/dev/null
    )
    [[ -z "${TEMPDIR}" ]] && {
        echo -e "${C_RED}error${S_RESET}"
        echo -e "${C_RED}error: could not create temporary directory, exiting${S_RESET}" >&2
        exit 1
    }
    TEMPDIRNAME="${TEMPDIR##*/}"
    TEMPDIR_PRETTY="${DESKTOP_DIR_PRETTY}/${TEMPDIRNAME}"
    if [[ ${?} -eq 0 ]]; then
        echo -e "${C_GREEN}${TEMPDIR_PRETTY}${S_RESET}"
    else
        echo -e "${C_RED}error${S_RESET}"
        exit 1
    fi

    echo -n "* moving files to temporary directory ... "
    # Find all the files on the Desktop and move them to the temporary directory
    # find . -not -path . \( -path './.tmp*' -prune -o -print \)
    find "${DESKTOP_DIR}/" \
        -maxdepth 1 \
        -not -path "${TEMPDIR}" \
        -not -path "${DESKTOP_DIR}/" \
        -exec mv {} "${TEMPDIR}" \; \
        && echo -e "${C_GREEN}done${S_RESET}" \
        || {
            echo -e "${C_RED}error, exiting${S_RESET}"
            exit 1
        }

    echo -n "* waiting a couple seconds ."
    for i in {1..2}; do
        sleep 1
        printf "."
    done
    echo -e " ${C_GREEN}done${S_RESET}"

    echo -n "* putting the files back ... "
    # Move all the files back to the Desktop
    find "${TEMPDIR}" \
        -maxdepth 1 \
        -not -path "${TEMPDIR}" \
        -exec mv {} "${DESKTOP_DIR}" \; \
        && echo -e "${C_GREEN}done${S_RESET}" \
        || {
            echo -e "${C_RED}error, exiting${S_RESET}"
            exit 1
        }

    # Remove the temporary directory if it's empty
    echo -n "* removing the temporary directory ... "
    rmdir "${TEMPDIR}" 2>/dev/null \
        && echo -e "${C_GREEN}done${S_RESET}" \
        || echo "Temporary directory not empty: ${TEMPDIR}" >&2
}
# Save this function to a temporary directory accessible via wsl-sudo
{
    clean_script_bin=$(mktemp -d)
    clean_script="${clean_script_bin}/clean-desktop"
    {
        echo "#!/usr/bin/env bash"
        include-source --cat 'colors.sh'
        print-function clean-desktop _clean_desktop
        echo '_clean_desktop "${@}"'
    } >"${clean_script}"
    chmod +x "${clean_script}"
    export PATH="${clean_script_bin}:${PATH}"
    function trap-exit() {
        rm -fr "${clean_script_bin}" 2>/dev/null
    }
    trap trap-exit EXIT
}

for DESKTOP_DIR in "${DESKTOP_DIRS[@]}"; do
    # Try to figure out if we need to use "wudo" because the desktop isn't in
    # the user's home dir
    if ! [[ "${DESKTOP_DIR}" == "${HOME}"/* ]]; then
        wsl-sudo clean-desktop "${DESKTOP_DIR}"
    else
        clean-desktop "${DESKTOP_DIR}"
    fi
done