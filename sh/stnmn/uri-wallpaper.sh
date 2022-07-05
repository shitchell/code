#!/bin/bash

# helpful vars
URI="http://wwc.instacam.com/instacamimg/STNMN/STNMN_l.jpg"
FILEPATH_ORIGINAL="/tmp/uri-wallpaper.orig.jpg"
FILEPATH_MODIFIED="/tmp/uri-wallpaper.jpg"

# helpful functions
##

help-usage() {
    echo "usage: $(basename "$0") [-qh] [-b blur] [url]"
}

help-epilogue() {
    echo "set wallpaper from image url with optional blur"
}

help() {
    help-usage
    help-epilogue
    echo
    cat << EOF
    -h/--help       show help info
    -b/--blur       set the sigma for the image blur. higher values increase the
                    fuzziness. 0 = no blur. defaults to 12
    -q/--quiet      hide all output
    -v/--verbose    show more output
EOF
}

# echo based on verbosity level
# first word is colored based on verbosity and placed inside brackets
# e.g., to echo if verbosity is <= 1:
# echo-managed 1 hello world
echo-managed() {
    # don't echo shit if verbosity is 0
    if [ "$VERBOSITY" -eq 0 ]; then
        return
    fi
    
    # default global verbosity is 2
    # default message verbosity level is 2
    level=2
    
    # if the first arg is a number, use it as verbosity level
    if [ $1 -eq $1 ] 2>/dev/null; then
        level=$1
        shift
    fi
    
    # use the first word as a label
    label=$1
    shift

    # echo if message level <= global verbosity level
    if [ $level -le $VERBOSITY ]; then
        printf "\033[0;3${level}m[%s]\033[0m %s\n" "$label" "$*"
    fi
}

# default options
VERBOSITY=2
BLUR=12

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        -h)
            help-usage
            help-epilogue
            echo
            echo "--help for more"
            exit
            ;;
        --help)
            help
            exit
            ;;
        -b|--blur)
            BLUR="$2"
            shift # past argument
            shift # past value
            ;;
        -v|--verbose)   
            let VERBOSITY++
            shift # past argument
            ;;
        -q|--quiet)
            VERBOSITY=0
            shift # past argument
            ;;
        *) # unknown option
            # positional arguments are treated as a url.
            # only the last one given will be used.
            URI="$1"
            shift # past argument
            ;;
    esac
done

# determine download command
# must happen *after* arguments are parsed in case a url is given
if command -v wget >/dev/null 2>&1; then
    DOWNLOAD_CMD="wget $URI -O $FILEPATH_ORIGINAL"
elif command -v curl >/dev/null 2>&1; then
    DOWNLOAD_CMD="curl $URI -o $FILEPATH_ORIGINAL"
else
    echo 'could not find wget or curl' 1>&2
    exit 1
fi

# download image
echo-managed 1 downloading $URI
$DOWNLOAD_CMD >/dev/null 2>&1

# blur image
echo-managed 2 imagemagick adding blur with sigma=$BLUR
convert -blur 0x$BLUR "$FILEPATH_ORIGINAL" "$FILEPATH_MODIFIED"

# set image as desktop background
echo-managed 1 gsettings setting as desktop background
gsettings set org.cinnamon.desktop.background picture-uri "file://$FILEPATH_MODIFIED"
