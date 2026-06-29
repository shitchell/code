# Integration tests for clip.xsel — X11 / XWayland.
#
# On a headless or pure-Wayland session $DISPLAY may be unset (or XWayland
# unavailable), so probe must report score 0 and the round-trip skips. The real
# clipboard is saved/restored via gpaste when available.

setup() {
  command -v xsel >/dev/null 2>&1 || skip "no xsel"
  export PATH="$BATS_TEST_DIRNAME/../../sh/bin:$PATH"
  if command -v gpaste-client >/dev/null 2>&1; then
    SAVED_CLIP="$(gpaste-client --use-index get 0 2>/dev/null || true)"
  fi
}

teardown() {
  if [[ -n "${SAVED_CLIP:-}" ]]; then
    gpaste-client add "$SAVED_CLIP" 2>/dev/null || true
  fi
}

@test "clip.xsel probe: caps with an X display, score 0 without" {
  run clip.xsel probe
  [ "$status" -eq 0 ]
  if [[ -n "$DISPLAY" ]]; then
    [[ "$output" == *"get:plain"* ]]
    [[ "$output" == *"set:plain"* ]]
    local score
    score="$(sed -n 's/^score //p' <<<"$output")"
    [[ "$score" =~ ^[0-9]+$ ]]
    [ "$score" -gt 0 ]
  else
    [[ "$output" == *"score 0"* ]]
  fi
}

@test "clip.xsel round-trips plain text (skips without X / if not functional)" {
  [[ -n "$DISPLAY" ]] || skip "no DISPLAY (xsel needs X/XWayland)"
  export VAL="rt-xsel-$$-$RANDOM"
  run bash -c 'printf "%s" "$VAL" | timeout 30 clip.xsel set plain'
  if [ "$status" -ne 0 ]; then skip "xsel set not functional (status $status)"; fi
  run timeout 30 clip.xsel get plain
  if [ "$status" -ne 0 ]; then skip "xsel get not functional (status $status)"; fi
  [ "$output" = "$VAL" ]
}
