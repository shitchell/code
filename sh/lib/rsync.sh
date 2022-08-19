# sync one git repository to the other, respecting the .gitignore file and
# without the .git directory
# TODO:
#   - add a --dry-run option to show what would be copied
#   - add a --verbose option to show what is being copied
#   - add a --delete option to delete files that are not in the source
#   - add a --force option to overwrite files that are in the destination
#   - add an --rsync-options option to pass rsync options to rsync
function rsync-git() {
    local src_repo="${1}"
    local dst_repo="${2}"

    # remove any trailing slashes from the paths
    src_repo="${src_repo%/}"
    dst_repo="${dst_repo%/}"

    rsync -lzr --delete --exclude '.git' "${src_repo}/" "${dst_repo}/"
}