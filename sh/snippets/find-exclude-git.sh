# Print all directories except git repos
find . -type d \( -exec sh -c 'test -e "$1/.git"' sh {} \; -prune -o -print \)

# Find all directories, including git repos, but don't recurse into git repos
find . -type d \( -exec sh -c 'test -e "$1/.git"' sh {} \; -print -prune -o -print \)

# Find all files, excluding any inside git repos
find . \( -exec sh -c 'test -e "$1/.git"' sh {} \; -prune -o -type f -print \)

# Find all files, except those in git repos, but print the excluded git dirs
find . \( -exec sh -c 'test -e "$1/.git"' sh {} \; -print -prune -o -type f -print \)

---

# Print all git repos
find . -type d \( -exec sh -c 'test -e "$1/.git"' sh {} \; -print -prune \)

# Print all git repos including submodules
find . -type d \( -exec sh -c 'test -e "$1/.git"' sh {} \; -print \) -o \( -name '.git' -prune \)
