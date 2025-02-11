#!/usr/bin/env bash
#
# Translate WSL paths before passing them to Beyond Compare

PATH_LEFT="${1}"
PATH_RIGHT="${2}"
BC_ARGS=()
ENVIRONMENT_NAME=$(environment)

if [[ -n "${PATH_LEFT}" ]]; then
    # Get the realpath
    PATH_LEFT=$(realpath "${PATH_LEFT}")
    
    # Convert the path to WSL if in a WSL environment
    if [[ "${ENVIRONMENT_NAME}" == "WSL"* ]]; then
        PATH_LEFT="$(wslpath -aw "${PATH_LEFT}")"
    fi
    
    BC_ARGS+=("${PATH_LEFT}")
fi

# Do it all over again for the right path
if [[ -n "${PATH_RIGHT}" ]]; then
    # Get the realpath
    PATH_RIGHT=$(realpath "${PATH_RIGHT}")
    
    # Convert the path to WSL if in a WSL environment
    if [[ "${ENVIRONMENT_NAME}" == "WSL"* ]]; then
        PATH_RIGHT="$(wslpath -aw "${PATH_RIGHT}")"
    fi
    
    BC_ARGS+=("${PATH_RIGHT}")
fi

bcomp.exe "${PATH_LEFT}" "${PATH_RIGHT}"
