#!/usr/bin/env bats
#
# Characterization tests for bin/srt-format.
#
# These pin the script's current observable behavior (stdout, stderr, exit
# codes) so the template-boilerplate condensation (lib-based parse-args, help,
# colors, config) can be verified against it. Golden outputs were captured
# from the script itself on 2026-07-03.
#
# Help output is deliberately pinned LOOSELY (key lines/content, not
# byte-for-byte) -- per project decision, minimal drift in help/args wording
# is acceptable during the refactor; core behavior is not allowed to drift.

setup_file() {
  export SF="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/srt-format"
}

setup() {
  # Hermetic HOME so a real ~/.srt-format.conf can't leak into tests
  export TESTHOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$TESTHOME"

  # Two-cue fixture, second cue with a continuation line
  export FIXTURE="$BATS_TEST_TMPDIR/sample.srt"
  printf '1\n00:00:01,000 --> 00:00:03,500\nHello world\n\n2\n00:00:04,000 --> 00:00:06,250\nSecond line\nwith continuation\n' > "$FIXTURE"
}

# Compare expected vs actual, printing both on mismatch
assert_equal() {
  if [[ "$1" != "$2" ]]; then
    echo "Expected: $1"
    echo "Got:      $2"
    return 1
  fi
}


## formatting ##################################################################

@test "default format from a file argument" {
  HOME="$TESTHOME" run "$SF" "$FIXTURE"
  expected="**00:00:01.000:** Hello world
**00:00:04.000:** Second line with continuation"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "default format from stdin" {
  HOME="$TESTHOME" run bash -c "'$SF' < '$FIXTURE'"
  expected="**00:00:01.000:** Hello world
**00:00:04.000:** Second line with continuation"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "-f applies a custom template" {
  HOME="$TESTHOME" run "$SF" -f '{index}. [{start_timestamp}-{end_timestamp}] {text}' "$FIXTURE"
  expected="1. [00:00:01.000-00:00:03.500] Hello world
2. [00:00:04.000-00:00:06.250] Second line with continuation"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "all timestamp component variables interpolate" {
  HOME="$TESTHOME" run "$SF" -f '{start_hour}h{start_minute}m{start_seconds}s{start_ms} {end_hour}h{end_minute}m{end_seconds}s{end_ms}' "$FIXTURE"
  expected="00h00m01s000 00h00m03s500
00h00m04s000 00h00m06s250"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "-- terminates option parsing before the file argument" {
  HOME="$TESTHOME" run "$SF" -- "$FIXTURE"
  expected="**00:00:01.000:** Hello world
**00:00:04.000:** Second line with continuation"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "empty stdin produces no output and exit 0" {
  HOME="$TESTHOME" run bash -c "'$SF' < /dev/null"
  assert_equal "" "$output"
  assert_equal 0 "$status"
}


## help (pinned loosely; minimal drift allowed) ################################

@test "-h prints usage + epilogue and exits 0" {
  HOME="$TESTHOME" run "$SF" -h
  assert_equal 0 "$status"
  [[ "${lines[0]}" == "usage: srt-format "* ]]
  [[ "$output" == *"format SRT subtitle files"* ]]
}

@test "--help prints full help (options + template variables) and exits 0" {
  HOME="$TESTHOME" run "$SF" --help
  assert_equal 0 "$status"
  [[ "${lines[0]}" == "usage: srt-format "* ]]
  [[ "$output" == *"-f/--format"* ]]
  [[ "$output" == *"{start_timestamp}"* ]]
  [[ "$output" == *"{text}"* ]]
}


## color / silent modes ########################################################

@test "-c always and -c never do not change formatted output" {
  HOME="$TESTHOME" run "$SF" -c always "$FIXTURE"
  expected="**00:00:01.000:** Hello world
**00:00:04.000:** Second line with continuation"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"

  HOME="$TESTHOME" run "$SF" -c never "$FIXTURE"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "-s suppresses all output and exits 0" {
  HOME="$TESTHOME" run "$SF" -s "$FIXTURE"
  assert_equal "" "$output"
  assert_equal 0 "$status"
}


## errors ######################################################################
# Exit codes and error wording standardized by the parseargs refactor
# (2026-07-03, per the accepted "minimal drift" decision): granular E_*
# codes from exit-codes.sh, parseargs' error message format.

@test "unknown option fails with error and E_UNKNOWN_OPTION" {
  HOME="$TESTHOME" run "$SF" -z "$FIXTURE"
  assert_equal "Error: Unknown option: -z" "$output"
  assert_equal 15 "$status"
}

@test "multiple input files fail with error and E_INVALID_ARGUMENT" {
  HOME="$TESTHOME" run "$SF" "$FIXTURE" extra.srt
  assert_equal "error: multiple input files specified" "$output"
  assert_equal 10 "$status"
}

@test "nonexistent input file fails with error and E_FILE_NOT_FOUND" {
  HOME="$TESTHOME" run "$SF" /nonexistent/file.srt
  assert_equal "error: file not found: /nonexistent/file.srt" "$output"
  assert_equal 46 "$status"
}

@test "invalid color mode fails with error and E_INVALID_VALUE" {
  HOME="$TESTHOME" run "$SF" -c bogus "$FIXTURE"
  assert_equal "Error: Invalid value 'bogus' for option -c, expected one of: auto,always,never" "$output"
  assert_equal 16 "$status"
}


## config file #################################################################

@test "config file can set COLOR (invalid values fall back to auto)" {
  # Choices validation only applies to CLI values; a bogus config COLOR
  # resolves like auto (no color on non-tty) instead of erroring
  printf 'COLOR=bogus\n' > "$TESTHOME/.srt-format.conf"
  HOME="$TESTHOME" run "$SF" "$FIXTURE"
  expected="**00:00:01.000:** Hello world
**00:00:04.000:** Second line with continuation"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "CLI -f wins over config file FORMAT" {
  printf 'FORMAT="{index}: {text}"\n' > "$TESTHOME/.srt-format.conf"
  HOME="$TESTHOME" run "$SF" -f 'X {text}' "$FIXTURE"
  expected="X Hello world
X Second line with continuation"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}


## fixed bugs ##################################################################
# These three were pinned as KNOWN BUG characterization tests before the
# parseargs refactor; the refactor fixed them deliberately.

@test "FIXED: config file FORMAT now takes effect" {
  # Previously clobbered by an unconditional default assignment after the
  # config was sourced
  printf 'FORMAT="{index}: {text}"\n' > "$TESTHOME/.srt-format.conf"
  HOME="$TESTHOME" run "$SF" "$FIXTURE"
  expected="1: Hello world
2: Second line with continuation"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "FIXED: explicit --config-file FORMAT now takes effect" {
  local cf="$BATS_TEST_TMPDIR/custom.conf"
  printf 'FORMAT="[{start_timestamp}] {text}"\n' > "$cf"
  HOME="$TESTHOME" run "$SF" --config-file "$cf" "$FIXTURE"
  expected="[00:00:01.000] Hello world
[00:00:04.000] Second line with continuation"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}

@test "FIXED: -c belongs to --color only; cwd files are never sourced" {
  # Previously the config pre-scan matched '-c | --config-file', so
  # 'srt-format -c always' SOURCED a file named 'always' from the cwd
  # (arbitrary code execution)
  local d="$BATS_TEST_TMPDIR/cwd"; mkdir -p "$d"
  printf 'echo "CONFIG SOURCED AS SIDE EFFECT"\n' > "$d/always"
  cd "$d"
  HOME="$TESTHOME" run "$SF" -c always "$FIXTURE"
  expected="**00:00:01.000:** Hello world
**00:00:04.000:** Second line with continuation"
  assert_equal "$expected" "$output"
  assert_equal 0 "$status"
}
