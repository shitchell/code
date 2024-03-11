C_RED=$'\033[31m'
C_GREEN=$'\033[32m'
S_RESET=$'\033[0m'
S_BOLD=$'\033[1m'

FILES=( "${@}" )

grep -Pri '\bcreate\b( or replace)?( editionable)? (trigger|function|table|sequence)' "${FILES[@]}" \
  | tr -d '"' \
  | grep -v INDEX \
  | sed -E 's/ *$//' \
  | awk -F: -v c_match="${C_GREEN}" -v c_error="${C_RED}${S_BOLD}" -v s_reset="${S_RESET}" '
      BEGIN {
        print "directory\tfilename\tobject\tmatch"
        print "---------\t--------\t------\t-----"
      }
      {
        obj = toupper($0)
        gsub(/.*(TRIGGER|FUNCTION|TABLE|SEQUENCE) +/, "", obj)
        gsub(/[\( ;].*/, "", obj)
        gsub(/^[A-Za-z0-9]+\./, "", obj)

        dname = $1
        gsub(/\/[^\/]+$/, "", dname)

        fname = $1
        gsub(/.*\//, "", fname)

        printf dname "\t" fname "\t" obj "\t"

        if (fname ~ obj) {
          print c_match "match" s_reset
        } else {
          print c_error "error" s_reset
        }
      }' \
  | column -t -s$'\t'
