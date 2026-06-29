# Tests for the standard-name shims (xclip, xsel, wl-paste, wl-copy,
# pbpaste, pbcopy). Each shim is a thin router into our front-ends, so we
# stub clipin/clipout on a temp PATH and assert the routing, never touching
# the real clipboard.

setup() { load helpers; }

# stub <name> <body> — drop an executable <name> on a temp stub dir that is
# prepended to PATH, so the shim's `exec clipin/clipout` resolves to it.
stub() {
  local dir="$BATS_TEST_TMPDIR/stub"; mkdir -p "$dir"
  { printf '#!/usr/bin/env bash\n'; printf '%s\n' "$2"; } > "$dir/$1"
  chmod +x "$dir/$1"
  export PATH="$dir:$PATH"
}

# ---- xclip --------------------------------------------------------------

@test "xclip -out routes to clipout (read, not write)" {
  stub clipout 'echo PASTED'
  run sh/bin/xclip -out -selection clipboard
  [ "$status" -eq 0 ]
  [ "$output" = "PASTED" ]
}

@test "xclip -o routes to clipout" {
  stub clipout 'echo PASTED'
  run sh/bin/xclip -o
  [ "$output" = "PASTED" ]
}

@test "xclip -i routes to clipin" {
  stub clipin 'cat > "$BATS_TEST_TMPDIR/in"'
  echo data | sh/bin/xclip -i
  [ "$(cat "$BATS_TEST_TMPDIR/in")" = data ]
}

@test "xclip with no mode flag defaults to clipin (write)" {
  stub clipin 'cat > "$BATS_TEST_TMPDIR/in"'
  echo plain | sh/bin/xclip -selection clipboard
  [ "$(cat "$BATS_TEST_TMPDIR/in")" = plain ]
}

# ---- xsel ---------------------------------------------------------------

@test "xsel -o routes to clipout" {
  stub clipout 'echo PASTED'
  run sh/bin/xsel -o
  [ "$output" = "PASTED" ]
}

@test "xsel -b -o routes to clipout" {
  stub clipout 'echo PASTED'
  run sh/bin/xsel -b -o
  [ "$output" = "PASTED" ]
}

@test "xsel -i routes to clipin" {
  stub clipin 'cat > "$BATS_TEST_TMPDIR/in"'
  echo data | sh/bin/xsel -i
  [ "$(cat "$BATS_TEST_TMPDIR/in")" = data ]
}

@test "xsel with no mode flag defaults to clipin" {
  stub clipin 'cat > "$BATS_TEST_TMPDIR/in"'
  echo plain | sh/bin/xsel -b
  [ "$(cat "$BATS_TEST_TMPDIR/in")" = plain ]
}

# ---- wl-paste / wl-copy -------------------------------------------------

@test "wl-paste routes to clipout" {
  stub clipout 'echo PASTED'
  run sh/bin/wl-paste
  [ "$output" = "PASTED" ]
}

@test "wl-paste -t text/html routes to clipout --format rich" {
  stub clipout 'echo "OUT:$*"'
  run sh/bin/wl-paste -t text/html
  [ "$output" = "OUT:--format rich" ]
}

@test "wl-copy routes to clipin" {
  stub clipin 'cat > "$BATS_TEST_TMPDIR/in"'
  echo data | sh/bin/wl-copy
  [ "$(cat "$BATS_TEST_TMPDIR/in")" = data ]
}

# ---- pbpaste / pbcopy ---------------------------------------------------

@test "pbpaste routes to clipout" {
  stub clipout 'echo PASTED'
  run sh/bin/pbpaste
  [ "$output" = "PASTED" ]
}

@test "pbcopy routes to clipin" {
  stub clipin 'cat > "$BATS_TEST_TMPDIR/in"'
  echo data | sh/bin/pbcopy
  [ "$(cat "$BATS_TEST_TMPDIR/in")" = data ]
}

# ---- recursion guard ----------------------------------------------------
# With our real sh/bin (containing the wl-paste & xsel shims) on PATH ahead of
# /usr/bin, a bare `clip::real_binary <name>` would resolve OUR shim and loop
# (shim -> clipout -> dispatch -> provider -> shim ...). clip::real_binary with
# --need-binary must skip the text shim and return a real, non-$HOME binary.

@test "recursion guard: real_binary skips wl-paste shim, returns system binary" {
  command -v /usr/bin/wl-paste >/dev/null 2>&1 || skip "no system wl-paste"
  source "$BATS_TEST_DIRNAME/../../sh/lib/clip.sh"
  # sh/bin (with our shim) FIRST, exactly like production PATH ordering.
  export PATH="$BATS_TEST_DIRNAME/../../sh/bin:/usr/bin:/bin"
  run clip::real_binary wl-paste --need-binary
  [ "$status" -eq 0 ]
  [[ "$output" != "$BATS_TEST_DIRNAME/../../sh/bin/"* ]]   # not our shim
  case "$output" in "$HOME"/*) false ;; *) true ;; esac     # not under $HOME
  [ -x "$output" ]
  [[ "$(file -b --mime-type "$output")" != text/* ]]        # a real binary
}

@test "recursion guard: real_binary skips xsel shim, returns system binary" {
  command -v /usr/bin/xsel >/dev/null 2>&1 || skip "no system xsel"
  source "$BATS_TEST_DIRNAME/../../sh/lib/clip.sh"
  export PATH="$BATS_TEST_DIRNAME/../../sh/bin:/usr/bin:/bin"
  run clip::real_binary xsel --need-binary
  [ "$status" -eq 0 ]
  [[ "$output" != "$BATS_TEST_DIRNAME/../../sh/bin/"* ]]
  case "$output" in "$HOME"/*) false ;; *) true ;; esac
  [ -x "$output" ]
  [[ "$(file -b --mime-type "$output")" != text/* ]]
}
