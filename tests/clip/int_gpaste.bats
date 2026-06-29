# Integration tests for clip.gpaste — run on a machine with GPaste.
#
# These touch the REAL clipboard, so we save it in setup and restore it in
# teardown to avoid clobbering the user's actual clipboard.

setup() {
  command -v gpaste-client >/dev/null 2>&1 || skip "no gpaste-client"
  export PATH="$BATS_TEST_DIRNAME/../../sh/bin:$PATH"
  SAVED_CLIP="$(gpaste-client --use-index get 0 2>/dev/null || true)"
}

teardown() {
  if [[ -n "${SAVED_CLIP:-}" ]]; then
    gpaste-client add "$SAVED_CLIP" 2>/dev/null || true
  fi
}

@test "clip.gpaste probe reports a numeric score and plain caps" {
  run clip.gpaste probe
  [ "$status" -eq 0 ]
  [[ "$output" == *"get:plain"* ]]
  [[ "$output" == *"set:plain"* ]]
  local score
  score="$(sed -n 's/^score //p' <<<"$output")"
  [[ "$score" =~ ^[0-9]+$ ]]
  [ "$score" -ge 40 ]
}

@test "clip.gpaste scores 70 on GNOME" {
  [[ "$XDG_CURRENT_DESKTOP" == *GNOME* ]] || skip "not GNOME"
  run clip.gpaste probe
  [[ "$output" == *"score 70"* ]]
}

@test "clip.gpaste round-trips plain text" {
  local val="rt-gpaste-$$-$RANDOM"
  printf '%s' "$val" | clip.gpaste set plain
  [ "$(clip.gpaste get plain)" = "$val" ]
}
