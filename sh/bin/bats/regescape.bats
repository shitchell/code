#!/usr/bin/env bats
#
# Characterization tests for bin/regescape.
#
# Golden outputs captured from the script itself on 2026-07-03, pinning
# stdout, stderr, and exit codes ahead of the parseargs refactor.

setup_file() {
  export RG="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/regescape"
}

assert_equal() {
  if [[ "$1" != "$2" ]]; then
    echo "Expected: $1"
    echo "Got:      $2"
    return 1
  fi
}


## extended (default) ##########################################################

@test "escapes ERE metacharacters by default" {
  run "$RG" 'a.b*c'
  assert_equal 'a\.b\*c' "$output"
  assert_equal 0 "$status"
}

@test "joins multiple arguments with spaces before escaping" {
  run "$RG" a.b 'c?d'
  assert_equal 'a\.b c\?d' "$output"
  assert_equal 0 "$status"
}

@test "escapes leading ^ and trailing \$ anchors" {
  run "$RG" '^a$'
  assert_equal '\^a\$' "$output"
  assert_equal 0 "$status"
}

@test "a non-trailing \$ is left alone" {
  run "$RG" 'a$b'
  assert_equal 'a$b' "$output"
  assert_equal 0 "$status"
}

@test "escapes brackets, braces, parens, pipes, and plus" {
  run "$RG" '[foo]{1,2}(bar|baz)+'
  assert_equal '\[foo\]\{1,2\}\(bar\|baz\)\+' "$output"
  assert_equal 0 "$status"
}

@test "-- terminates option parsing so dash-strings escape literally" {
  run "$RG" -- -E
  assert_equal '-E' "$output"
  assert_equal 0 "$status"
}


## other regex types ###########################################################

@test "-B (basic) leaves unbackslashed metacharacters alone" {
  # The basic escaper only rewrites backslash-prefixed sequences (see the
  # TODO in the escape-basic source); plain strings pass through unchanged
  run "$RG" -B 'a.b*c[x]'
  assert_equal 'a.b*c[x]' "$output"
  assert_equal 0 "$status"
}

@test "-P (perl) wraps the string in \\Q...\\E" {
  run "$RG" -P 'a.b*c'
  assert_equal '\Qa.b*c\E' "$output"
  assert_equal 0 "$status"
}

@test "the last regex-type flag wins" {
  run "$RG" -B -P foo
  assert_equal '\Qfoo\E' "$output"
  assert_equal 0 "$status"
}

# Exit codes standardized by the parseargs refactor (2026-07-03):
# granular E_* codes from exit-codes.sh.

@test "-A (awk) is accepted but unimplemented: unknown regex type" {
  run "$RG" -A foo
  assert_equal "error: unknown regex type: awk" "$output"
  assert_equal 18 "$status"
}

@test "-J (javascript) is accepted but unimplemented: unknown regex type" {
  run "$RG" -J foo
  assert_equal "error: unknown regex type: javascript" "$output"
  assert_equal 18 "$status"
}


## help (pinned loosely; minimal drift allowed) ################################

@test "-h prints usage and exits 0" {
  run "$RG" -h
  assert_equal 0 "$status"
  [[ "${lines[0]}" == "usage: regescape "* ]]
}

@test "--help lists the regex type options and exits 0" {
  run "$RG" --help
  assert_equal 0 "$status"
  [[ "$output" == *"-E/--extended"* ]]
  [[ "$output" == *"-B/--basic"* ]]
  [[ "$output" == *"-P/--perl"* ]]
}


## errors ######################################################################

@test "no string provided fails with error + usage on stderr" {
  run "$RG"
  assert_equal 11 "$status"
  [[ "${lines[0]}" == "error: no string provided" ]]
  [[ "${lines[1]}" == "usage: regescape "* ]]
}

@test "unknown option fails with error and E_UNKNOWN_OPTION" {
  run "$RG" -z foo
  assert_equal "Error: Unknown option: -z" "$output"
  assert_equal 15 "$status"
}
