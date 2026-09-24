# Integration tests for provider.clip.wsl — run on a WSL box (Windows clipboard).
#
# INERT on non-WSL machines: every test skips unless /proc/version names
# Microsoft, so this is safe to include in the suite on libre. The authoritative
# verification for this provider is a LIVE run on the real WSL box over SSH; this
# bats file is the same checks expressed locally, active only if ever run there.
#
# THE BUG THIS GUARDS: opening micro used to WIPE the Windows clipboard because a
# read was dispatched as a write. The no-clobber test below proves provider.clip.wsl's
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

@test "provider.clip.wsl probe scores 70 with plain+rich caps" {
  run provider.clip.wsl probe
  [ "$status" -eq 0 ]
  [[ "$output" == *"score 70"* ]]
  [[ "$output" == *"get:plain"* ]]
  [[ "$output" == *"set:plain"* ]]
}

@test "provider.clip.wsl get is a PURE READ (does not clobber the clipboard)" {
  local known="KNOWN_$$_$RANDOM"
  printf '%s' "$known" | /mnt/c/Windows/System32/clip.exe
  # A get must return the value...
  run provider.clip.wsl get plain
  [ "$status" -eq 0 ]
  [ "$output" = "$known" ]
  # ...AND must leave the clipboard unchanged (the original micro bug).
  local after
  after="$("$PSH" -NoProfile -Command 'Get-Clipboard -Raw' | tr -d '\r\0')"
  [ "$after" = "$known" ]
}

@test "provider.clip.wsl round-trips plain text" {
  local val="RT_$$_$RANDOM"
  printf '%s' "$val" | provider.clip.wsl set plain
  run provider.clip.wsl get plain
  [ "$status" -eq 0 ]
  [ "$output" = "$val" ]
}

@test "provider.clip.wsl set plain handles single quotes safely" {
  local val="it's a 'quoted' test"
  printf '%s' "$val" | provider.clip.wsl set plain
  run provider.clip.wsl get plain
  [ "$status" -eq 0 ]
  [ "$output" = "$val" ]
}

@test "provider.clip.wsl round-trips non-ASCII plain text (é ✓)" {
  local val="café ✓ naïve — ok"
  printf '%s' "$val" | provider.clip.wsl set plain
  run provider.clip.wsl get plain
  [ "$status" -eq 0 ]
  [ "$output" = "$val" ]
}

@test "provider.clip.wsl set plain handles >40K chars (no command-line limit)" {
  local val
  val="$(head -c 45000 /dev/zero | tr '\0' 'x')END"
  printf '%s' "$val" | provider.clip.wsl set plain
  run provider.clip.wsl get plain
  [ "$status" -eq 0 ]
  [ "${#output}" -eq 45003 ]
  [ "$output" = "$val" ]
}

@test "provider.clip.wsl set plain drops trailing newlines" {
  printf 'line1\nline2\n\n' | provider.clip.wsl set plain
  run provider.clip.wsl get plain
  [ "$output" = "$(printf 'line1\nline2')" ]
}

@test "provider.clip.wsl set rich: HTML + UnicodeText on one write, non-ASCII intact" {
  local fb="$BATS_TEST_TMPDIR/fallback.md"
  printf '# Title ✓\n' > "$fb"
  printf '<h1>Title ✓</h1>\n' | CLIP_PLAIN_FALLBACK="$fb" provider.clip.wsl set rich
  # Both flavours present.
  run "$PSH" -NoProfile -STA -Command 'Add-Type -AssemblyName System.Windows.Forms; $d=[Windows.Forms.Clipboard]::GetDataObject(); "html=" + $d.GetDataPresent("HTML Format") + " text=" + $d.GetDataPresent("UnicodeText")'
  [[ "$output" == *"html=True text=True"* ]]
  # get rich returns the fragment with the raw UTF-8 bytes of U+2713.
  run provider.clip.wsl get rich
  [ "$status" -eq 0 ]
  [ "$output" = "<h1>Title ✓</h1>" ]
  provider.clip.wsl get rich | grep -q $'\xe2\x9c\x93'
  # The plain flavour is the fallback file, not the HTML.
  run provider.clip.wsl get plain
  [ "$output" = "# Title ✓" ]
}

@test "provider.clip.wsl set rich without CLIP_PLAIN_FALLBACK derives plain text" {
  printf '<p>Some <b>bold</b> ✓</p>' | provider.clip.wsl set rich
  run provider.clip.wsl get plain
  [ "$status" -eq 0 ]
  # Exact rendering is the deriver's business (pandoc -t plain upper-cases
  # <b>); what matters is tags gone, text and non-ASCII kept.
  [[ "$output" == Some* ]]
  [[ "${output,,}" == *"bold ✓"* ]]
  [[ "$output" != *"<"* ]]
}

@test "provider.clip.wsl get rich is a PURE READ and empty when there is no HTML" {
  local known="KNOWN_$$_$RANDOM"
  printf '%s' "$known" | /mnt/c/Windows/System32/clip.exe
  run provider.clip.wsl get rich
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run provider.clip.wsl get plain
  [ "$output" = "$known" ]
}
