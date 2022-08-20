#!/bin/bash

BACKUP_DIR="${1:-/var/stnm}"
FILENAME="$(date '+stnm_%Y%m%d_%H%M.jpg')"
FILEPATH="$BACKUP_DIR/$FILENAME"
TMPDIR="$BACKUP_DIR/.tmp"
TMPPATH="$TMPDIR/$FILENAME"
HASHDIR="$BACKUP_DIR/.hashes"

if [ -n "$TERM" ]; then
    red=$(tput setaf 1)
    green=$(tput setaf 2)
    reset=$(tput sgr0)
    status=$green
    smul=$(tput smul)
    rmul=$(tput rmul)
fi

function hashify()
{
	md5sum "$1" | cut -d ' ' -f 1
}

function log()
{
	echo "${status}[$1]${reset} $2"
}

# Temporarily download the file
! [ -d "$TMPDIR" ] && mkdir -p "$TMPDIR"
echo -n "${status}[get]${reset}  $TMPPATH"
wget --quiet http://wwc.instacam.com/instacamimg/STNMN/STNMN_l.jpg -O "$TMPPATH"

# Get the md5 hash
md5hash=$(hashify "$TMPPATH")
echo " [md5:$md5hash]"

# Determine if the hash exists already
HASHFILEPATH="$HASHDIR/$md5hash"
if [[ -f "$HASHFILEPATH" ]]; then
	status=$red
	log "err" " hash found: $HASHFILEPATH"
	# If the hash exists, we already have the picture, so delete this one
	rm "$TMPPATH"
	log "del" " removed $TMPPATH"
	exit 0
else
	# Move the downloaded image to the backup dir
	log "move" "$TMPPATH => $FILEPATH"
	echo mv "$TMPPATH" "$FILEPATH"
	mv "$TMPPATH" "$FILEPATH"
	# Ensure the hash dir exists
	! [ -d "$HASHDIR" ] && mkdir -p "$HASHDIR"
	# Link the hash to the file
	log "link" "$smul$HASHFILEPATH$rmul => $FILEPATH"
	ln -s "$FILEPATH" "$HASHFILEPATH"
fi