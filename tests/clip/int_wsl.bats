# Integration tests for clip.wsl — run on a WSL box (Windows clipboard).
#
# INERT on non-WSL machines: every test skips unless /proc/version names
# Microsoft, so this is safe to include in the suite on libre. The authoritative
# verification for this provider is a LIVE run on the real WSL box over SSH; this
# bats file is the same checks expressed locally, active only if ever run there.
#
# THE BUG THIS GUARDS: opening micro used to WIPE the Windows clipboard because a
# read was dispatched as a write. The no-clobber test below proves clip.wsl's
# `get` is a pure read — the clipboard is unchanged after a get.
#
# Be a good guest: the real clipboard is saved in setup and restored in teardown.

setup() {
  grep -qi microsoft /proc/version 2>/dev/null || skip "not WSL"
  export PATH="$BATS_TEST_DIRNAME/../../wsl/bin:$PATH"
  PSH="$(command -v powershell.exe || echo /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe)"
  [[ -x "$PSH" ]] || skip "no powershell.exe"
  # Save the real clipboard so we can restore it afterwards.
  SAVED_CLIP="$("$PSH" -NoProfile -Command 'Get-Clipboard -Raw' | tr -d '\r\0')"
}

teardown() {
  [[ -n "${PSH:-}" ]] || return 0
  # Restore whatever was there before (may be empty).
  printf '%s' "${SAVED_CLIP:-}" | /mnt/c/Windows/System32/clip.exe 2>/dev/null || true
}

@test "clip.wsl probe scores 70 with plain+rich caps" {
  run clip.wsl probe
  [ "$status" -eq 0 ]
  [[ "$output" == *"score 70"* ]]
  [[ "$output" == *"get:plain"* ]]
  [[ "$output" == *"set:plain"* ]]
}

@test "clip.wsl get is a PURE READ (does not clobber the clipboard)" {
  local known="KNOWN_$$_$RANDOM"
  printf '%s' "$known" | /mnt/c/Windows/System32/clip.exe
  # A get must return the value...
  run clip.wsl get plain
  [ "$status" -eq 0 ]
  [ "$output" = "$known" ]
  # ...AND must leave the clipboard unchanged (the original micro bug).
  local after
  after="$("$PSH" -NoProfile -Command 'Get-Clipboard -Raw' | tr -d '\r\0')"
  [ "$after" = "$known" ]
}

@test "clip.wsl round-trips plain text" {
  local val="RT_$$_$RANDOM"
  printf '%s' "$val" | clip.wsl set plain
  run clip.wsl get plain
  [ "$status" -eq 0 ]
  [ "$output" = "$val" ]
}

@test "clip.wsl set plain handles single quotes safely" {
  local val="it's a 'quoted' test"
  printf '%s' "$val" | clip.wsl set plain
  run clip.wsl get plain
  [ "$status" -eq 0 ]
  [ "$output" = "$val" ]
}
