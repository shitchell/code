# This library facilitates standardised versioning.

VERSION_REGEX="^v?([0-9]+)(\.([0-9]+))?(\.([0-9]+))?(\.([0-9]+))?([-_]([0-9A-Za-z\-\.]+))?$"
VERSION_REGEX="GIA9U-[0-9]+"
RELEASE_BRANCH_PATTERN="releases/(${VERSION_REGEX})"
PR_VERSION_REGEX="Merge pull request #[0-9]+ from [^/]+/${RELEASE_BRANCH_PATTERN}"
