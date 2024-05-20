#!/usr/bin/env bash

include-source shell

require zenity

TEXT="${1}"
TITLE="${2:-Zenity Notification}"
ICON="${3:-info}"
TIMEOUT="${4:-5}"

zenity --notification \
    --title="${TITLE}" \
    --text="${TEXT}" \
    --window-icon="${ICON}" \
    --timeout="${TIMEOUT}"
