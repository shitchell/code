#!/usr/bin/env bats
#
# Characterization tests for bin/markdown-table.
#
# These pin the script's current observable behavior (stdout, stderr, exit
# codes) so that refactors -- e.g. moving option parsing to lib/parseargs.sh --
# can be verified 1:1. Golden outputs were captured from the script itself on
# 2026-07-03; if a test here fails after a refactor, the refactor changed
# behavior.

setup_file() {
  export MT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/markdown-table"
}

# Compare expected vs actual, printing both on mismatch
assert_equal() {
  if [[ "$1" != "$2" ]]; then
    echo "Expected: $1"
    echo "Got:      $2"
    return 1
  fi
}


## help ########################################################################

@test "-h prints only the usage block" {
  run "$MT" -h
  expected="Usage: markdown-table -COLUMNS [CELLS]
       markdown-table -sSEPARATOR < file"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "--help prints the full help text" {
  run "$MT" --help
  assert_equal 0 "$status"
  # Full help = usage block plus the man-style sections
  # (46 lines total; note bats' \$lines drops blanks, so count via wc)
  assert_equal 46 "$(echo "$output" | wc -l)"
  assert_equal "Usage: markdown-table -COLUMNS [CELLS]" "${lines[0]}"
  [[ "$output" == *$'\nNAME\n'* ]]
  [[ "$output" == *$'\nSYNOPSIS\n'* ]]
  [[ "$output" == *$'\nOPTIONS\n'* ]]
  [[ "$output" == *$'\nEXAMPLES\n'* ]]
}


## args mode (-COLUMNS) ########################################################

@test "-2 builds a two-column table from arguments" {
  run "$MT" -2 "Heading 1" "H2" "a" "b"
  expected="| Heading 1 | H2  |
| --------- | --- |
| a         | b   |"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "-3 with exactly one row of cells emits header only" {
  run "$MT" -3 x y z
  expected="| x   | y   | z   |
| --- | --- | --- |"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "columns are padded to a minimum width of 3" {
  run "$MT" -2 a b c d
  expected="| a   | b   |
| --- | --- |
| c   | d   |"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "-- stops option parsing so cells may start with dashes" {
  run "$MT" -2 -- -a -b
  expected="| -a  | -b  |
| --- | --- |"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "cell count not divisible by columns pads the last row with empties" {
  run "$MT" -3 a b c d
  expected="| a   | b   | c   |
| --- | --- | --- |
| d   |     |     |"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "when the column count is given twice, the last one wins" {
  run "$MT" -2 -3 a b c
  expected="| a   | b   | c   |
| --- | --- | --- |"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}


## stdin mode (-s / --csv / --tsv) #############################################

@test "--csv converts comma-separated stdin" {
  run bash -c "printf 'name,age\nalice,30\nbob,7\n' | '$MT' --csv"
  expected="| name  | age |
| ----- | --- |
| alice | 30  |
| bob   | 7   |"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "--tsv converts tab-separated stdin and sizes to the widest cell" {
  run bash -c "printf 'a\tb\nlonger cell\tx\n' | '$MT' --tsv"
  expected="| a           | b   |
| ----------- | --- |
| longer cell | x   |"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "-sSEP accepts a multi-character separator" {
  run bash -c "printf 'a::b\nc::d\n' | '$MT' -s::"
  expected="| a   | b   |
| --- | --- |
| c   | d   |"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "empty stdin produces a single empty column" {
  run bash -c "'$MT' --csv < /dev/null"
  expected="|     |
| --- |"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "ragged stdin rows keep their own cell count (no padding)" {
  run bash -c "printf 'a,b,c\nd,e\n' | '$MT' --csv"
  expected="| a   | b   | c   |
| --- | --- | --- |
| d   | e   |"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "empty cells are preserved as blank columns" {
  run bash -c "printf 'a,,c\n,e,\n' | '$MT' --csv"
  expected="| a   |     | c   |
| --- | --- | --- |
|     | e   |     |"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}


## errors ######################################################################

@test "unknown option fails with a warning and exit 1" {
  run "$MT" -z
  assert_equal "Invalid option '-z'" "$output"
  assert_equal 1 "$status"
}

@test "bare -s (blank separator) fails with a warning and exit 1" {
  run bash -c "printf 'a,b\n' | '$MT' -s"
  assert_equal "Field separator can't be blank!" "$output"
  assert_equal 1 "$status"
}

@test "cell arguments without a column count fail with a warning and exit 1" {
  run "$MT" a b
  assert_equal "Missing or Invalid column count!" "$output"
  assert_equal 1 "$status"
}


## known bugs ##################################################################

@test "KNOWN BUG: -0 with cell arguments loops forever" {
  # `-0` passes the ^[0-9]+$ column-count check, but the fill loop never
  # shifts any arguments, so the script spins emitting newlines forever.
  # Documented here so the refactor can fix it deliberately; un-skip and
  # assert an error message + exit 1 once fixed.
  skip "pre-existing infinite loop; fix during the parseargs refactor"
  run timeout 2 "$MT" -0 a b
  assert_equal 124 "$status"
}
