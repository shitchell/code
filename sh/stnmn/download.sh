#!/bin/bash

export STNMN_URI="http://wwc.instacam.com/instacamimg/STNMN/STNMN_l.jpg"
filepath="/tmp/stnmn_l.jpg"
cmds=((wget "$STNMN_URI" -O ))

while ! command -v inotifywait >/dev/null 2>&1; then
    echo "error: command 'inotifywait' not found"
    exit 1
fi