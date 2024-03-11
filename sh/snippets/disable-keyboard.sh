#!/usr/bin/env bash
#
# Temporarily disable the keyboard.

# `xinput list` will produce output like so:
#
#   $ xinput list
#   WARNING: running xinput against an Xwayland server. See the xinput man page for details.
#   ⎡ Virtual core pointer                          id=2    [master pointer  (3)]
#   ⎜   ↳ Virtual core XTEST pointer                id=4    [slave  pointer  (2)]
#   ⎜   ↳ xwayland-pointer:18                       id=6    [slave  pointer  (2)]
#   ⎜   ↳ xwayland-relative-pointer:18              id=7    [slave  pointer  (2)]
#   ⎣ Virtual core keyboard                         id=3    [master keyboard (2)]
#       ↳ Virtual core XTEST keyboard               id=5    [slave  keyboard (3)]
#       ↳ xwayland-keyboard:18                      id=8    [slave  keyboard (3)]
#
# We're interested in the last line:
#
#       ↳ xwayland-keyboard:18                      id=8    [slave  keyboard (3)]
#
# where the "8" is our keyboard ID and the "3" is the master. We'll use:
#
#   $ xinput float 8
#
# to disable the keyboard and:
#
#   $ xinput reattach 8 3
#
# to re-enable it. At some point, I'll automate this to automatically parse
# that info :P

include-source 'echo.sh'
include-source 'shell.sh'

require 'xinput'

DEVICE="${1}"
MASTER="${2}"
SLEEPS="${3:-10}"

if [[ -z "${MASTER}" ]]; then
    # Print the xinput list and usage
    xinput list
    echo-error "usage: $(basename "${0}") <device> <master> [<sleep>]"
    exit
fi

if ! [[ "${SLEEPS}" =~ ^[0-9]+$ ]]; then
    echo-error "usage: $(basename "${0}") <device> <master> [<sleep>]"
    echo-error "<sleep> must be an int"
    exit 1
fi

function trap-exit() {
    xinput reattach "${DEVICE}" "${MASTER}"
}
trap trap-exit EXIT


xinput float "${DEVICE}"
sleep ${SLEEPS}
