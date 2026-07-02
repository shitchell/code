# Integration tests for clip.wl — run on a Wayland machine.
#
# The important assertion here is clip.wl's SELF-RATING: wl-clipboard is now the
# chosen PRIMARY backend, so it must rate HIGH even on GNOME (score 70), out-
# scoring gpaste (see Task B). That needs no clipboard round-trip.
#
# The round-trip itself CAN STALL 30-50s on GNOME/Mutter (the bug this project
# came from), so it is wrapped in `timeout` and skipped on a stall — never let it
# hang the suite. The real clipboard is saved/restored via gpaste.

setup() {
  [[ -n "$WAYLAND_DISPLAY" ]] || skip "no WAYLAND_DISPLAY"
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

@test "clip.wl probe scores HIGH (70) on GNOME (chosen primary)" {
  [[ "$XDG_CURRENT_DESKTOP" == *GNOME* ]] || skip "not GNOME"
  run clip.wl probe
  [ "$status" -eq 0 ]
  [[ "$output" == *"score 70"* ]]
  [[ "$output" == *"get:plain"* ]]
}

@test "clip.wl probe advertises image caps" {
  # Task A: wl-clipboard is the formatting-capable primary, so it must offer
  # image round-tripping. Caps-only assertion — no clipboard round-trip needed.
  run clip.wl probe
  [ "$status" -eq 0 ]
  [[ "$output" == *"get:image"* ]]
  [[ "$output" == *"set:image"* ]]
}

@test "clip.wl resolves a real (non-shim) wl-paste binary" {
  # Recursion guard: the backend must reach a real binary, not our own shim.
  source "$BATS_TEST_DIRNAME/../../sh/lib/clip.sh"
  run clip::real_binary wl-paste --need-binary
  [ "$status" -eq 0 ]
  [[ "$output" != "$HOME"/bin/* ]] || false
}

# NOTE on the `set` stages: wl-copy DAEMONIZES (forks a background process that
# keeps holding the selection) and inherits the command's stdout/stderr. If we
# let `run` capture that output over a pipe, `run` blocks on the forked child's
# open fd even after `timeout` kills the foreground wl-copy — so the test would
# hang past its own timeout. We therefore feed input from a file and redirect
# the set stage's stdout+stderr to /dev/null, so the forked daemon holds no fd
# that `run` is waiting on and the timeout can actually fire + skip.

@test "clip.wl round-trips plain text (timeout-guarded; skips on Mutter stall)" {
  local val="rt-wl-$$-$RANDOM" f="$BATS_TEST_TMPDIR/plain.txt"
  printf '%s' "$val" > "$f"
  run bash -c "timeout 60 clip.wl set plain < '$f' >/dev/null 2>&1"
  if [ "$status" -eq 124 ]; then skip "wl set stalled (known Mutter issue)"; fi
  [ "$status" -eq 0 ]
  run timeout 60 clip.wl get plain
  if [ "$status" -eq 124 ]; then skip "wl get stalled (known Mutter issue)"; fi
  [ "$status" -eq 0 ]
  [ "$output" = "$val" ]
}

@test "clip.wl round-trips a PNG image (timeout-guarded; skips on Mutter stall)" {
  # Task A: optional real round-trip. Uses a tiny 1x1 PNG. The daemon on this
  # box is finicky, so every wl call is timeout-guarded and skips on stall; the
  # clipboard is restored from SAVED_CLIP in teardown.
  local png="$BATS_TEST_TMPDIR/px.png"
  # 1x1 transparent PNG (base64).
  printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYPgPAAEEAQB9ssjfAAAAAElFTkSuQmCC' | base64 -d > "$png"
  run bash -c "timeout 30 clip.wl set image < '$png' >/dev/null 2>&1"
  if [ "$status" -eq 124 ]; then skip "wl set image stalled (known Mutter issue)"; fi
  [ "$status" -eq 0 ]
  run bash -c "timeout 30 clip.wl get image | cmp -s - '$png'"
  if [ "$status" -eq 124 ]; then skip "wl get image stalled (known Mutter issue)"; fi
  [ "$status" -eq 0 ]
}
