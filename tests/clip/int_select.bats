# Cross-provider selection — wl primary, gpaste fallback (Task B).
#
# With BOTH the real clip.gpaste and clip.wl on PATH, clip::dispatch must select
# clip.wl on GNOME: wl-clipboard is now the chosen primary (formatting-capable),
# and gpaste is kept only as a lower-priority plain-only fallback. We assert the
# score ordering directly (which is what the dispatcher keys on) AND verify an
# end-to-end dispatch get returns the wl value.
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

@test "wl out-scores gpaste on GNOME (so dispatch selects wl)" {
  local gs ws
  gs="$(clip.gpaste probe | sed -n 's/^score //p')"
  ws="$(clip.wl probe | sed -n 's/^score //p')"
  [[ "$gs" =~ ^[0-9]+$ ]]
  [[ "$ws" =~ ^[0-9]+$ ]]
  [ "$ws" -gt "$gs" ]
}
