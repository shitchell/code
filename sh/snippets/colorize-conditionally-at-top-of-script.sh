#!/bin/bash
#
# This should go at the top of your script, outside any functions, to determine whether
# or not the script should be colorized

# GIT version (tested)
__GIT_COLOR=$(git config --get color.ui)
[[ "${__GIT_COLOR}" == "always" || ("${__GIT_COLOR}" =~ ^("auto")?$ && -t 1) ]] \
    && USE_COLOR=true || USE_COLOR=false

# Standard version (untested)
[[ -t 1 ]] && USE_COLOR=true || USE_COLOR=false
