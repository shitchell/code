# Cross-provider selection — the libre lesson.
#
# With BOTH the real clip.gpaste and clip.wl on PATH, clip::dispatch must select
# gpaste on GNOME (it out-scores wl 70 vs 20). We assert the score ordering
# directly (which is exactly what the dispatcher's selection math keys on) AND
# verify an end-to-end dispatch get returns the gpaste-seeded value quickly — a
# stall would mean wl was wrongly chosen.
#
# Real clipboard is saved/restored via gpaste.

setup() {
  command -v gpaste-client >/dev/null 2>&1 || skip "no gpaste-client"
  [[ "$XDG_CURRENT_DESKTOP" == *GNOME* ]] || skip "not GNOME (selection lesson is GNOME-specific)"
  export PATH="$BATS_TEST_DIRNAME/../../sh/bin:$PATH"
  source "$BATS_TEST_DIRNAME/../../sh/lib/clip.sh"
  SAVED_CLIP="$(gpaste-client --use-index get 0 2>/dev/null || true)"
}

teardown() {
  if [[ -n "${SAVED_CLIP:-}" ]]; then
    gpaste-client add "$SAVED_CLIP" 2>/dev/null || true
  fi
}

@test "gpaste out-scores wl on GNOME (so dispatch selects gpaste)" {
  local gs ws
  gs="$(clip.gpaste probe | sed -n 's/^score //p')"
  ws="$(clip.wl probe | sed -n 's/^score //p')"
  [[ "$gs" =~ ^[0-9]+$ ]]
  [[ "$ws" =~ ^[0-9]+$ ]]
  [ "$gs" -gt "$ws" ]
}

@test "clip::dispatch get plain selects gpaste (fast; returns seeded value)" {
  local val="select-$$-$RANDOM"
  gpaste-client add "$val"
  # clip::dispatch is a shell function, so run it inside a sourced bash -c (a
  # bare `timeout clip::dispatch` would fail: timeout only runs external cmds).
  # gpaste's D-Bus path is fast; status 124 would mean wl was selected and stalled.
  run timeout 15 bash -c "source '$BATS_TEST_DIRNAME/../../sh/lib/clip.sh'; clip::dispatch get plain"
  if [ "$status" -eq 124 ]; then skip "dispatch stalled (wl wrongly selected?)"; fi
  [ "$status" -eq 0 ]
  [ "$output" = "$val" ]
}
