#!/usr/bin/env bats
#
# Characterization tests for bin/find-mimetype.
#
# Golden outputs captured from the script itself on 2026-07-03. Results are
# sorted because find's traversal order is not guaranteed. The fixture set
# gives known mimetypes (per file --mime): readme.txt + sub/notes.txt
# text/plain us-ascii, script.sh text/x-shellscript us-ascii, image.png
# image/png binary, empty.bin inode/x-empty binary.

setup_file() {
  export FM="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/find-mimetype"
}

setup() {
  export FIXDIR="$BATS_TEST_TMPDIR/fixture"
  mkdir -p "$FIXDIR/sub"
  printf 'hello world\n' > "$FIXDIR/readme.txt"
  printf '#!/bin/bash\necho hi\n' > "$FIXDIR/script.sh"
  printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR' > "$FIXDIR/image.png"
  printf 'sub file\n' > "$FIXDIR/sub/notes.txt"
  : > "$FIXDIR/empty.bin"
  cd "$FIXDIR"
}

assert_equal() {
  if [[ "$1" != "$2" ]]; then
    echo "Expected: $1"
    echo "Got:      $2"
    return 1
  fi
}

run_sorted() {
  run bash -c "'$FM' $* | sort"
}

@test "no filters lists everything found, including directories" {
  run_sorted
  expected=".
./empty.bin
./image.png
./readme.txt
./script.sh
./sub
./sub/notes.txt"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "-m with a glob filters by mimetype" {
  run_sorted -m "'text/*'"
  expected="./readme.txt
./script.sh
./sub/notes.txt"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "repeated -m accumulates mimetypes" {
  run_sorted -m image/png -m inode/x-empty
  expected="./empty.bin
./image.png"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "-M appends the mimetype after a tab" {
  run "$FM" -m image/png -M
  assert_equal $'./image.png\timage/png' "$output"
  assert_equal 0 "$status"
}

@test "-x excludes paths by glob" {
  run_sorted -m "'text/*'" -x "'*sub*'"
  expected="./readme.txt
./script.sh"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "-E switches -m/-i matching to regex" {
  run_sorted -E -m "'text/.*'" -i "'.*\.txt'"
  expected="./readme.txt
./sub/notes.txt"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "FIXED: -c matches bare charset values" {
  # Previously the charset was extracted as the literal "charset=us-ascii"
  # (prefix never stripped), so -c us-ascii matched nothing
  run_sorted -c us-ascii
  expected="./readme.txt
./script.sh
./sub/notes.txt"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "FIXED: the old charset= prefix workaround no longer matches" {
  run_sorted -c "'charset=us-ascii'"
  assert_equal "" "$output"
  assert_equal 0 "$status"
}

@test "-F sets a custom separator for -M output" {
  run "$FM" -M -F ' | ' -m "text/*" -i "*readme*"
  assert_equal "./readme.txt | text/plain" "$output"
  assert_equal 0 "$status"
}

@test "an explicit directory argument limits the search" {
  run_sorted sub
  expected="sub
sub/notes.txt"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "-- passes remaining arguments as directories" {
  run_sorted -- sub
  expected="sub
sub/notes.txt"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

# Error wording/exit code standardized by the parseargs refactor (2026-07-03)
@test "unknown option fails with error and E_UNKNOWN_OPTION" {
  run "$FM" -z
  assert_equal "Error: Unknown option: -z" "$output"
  assert_equal 15 "$status"
}

@test "-h prints usage and exits 0" {
  run "$FM" -h
  assert_equal 0 "$status"
  [[ "${lines[0]}" == "usage: find-mimetype "* ]]
}
