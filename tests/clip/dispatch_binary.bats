# Binary-safety: clip::dispatch must not corrupt NUL bytes (e.g. image data).
# The dispatcher buffers set-stdin and captures get-stdout; doing that via shell
# variables would silently drop NULs. These tests pin the temp-file approach.

setup() {
  source "$BATS_TEST_DIRNAME/../../sh/lib/clip.sh"
  BIN="$BATS_TEST_TMPDIR/bin"; mkdir -p "$BIN"
  # Isolated PATH so only our fake provider is enumerated by compgen.
  export PATH="$BIN:/usr/bin:/bin"
}

# Fake provider: emits NUL-containing bytes on get, saves stdin on set.
mk_binprovider() {
  cat > "$BIN/clip.bin" <<EOF
#!/bin/bash
case "\$1" in
  probe) echo "score 90"; echo "caps get:plain set:plain" ;;
  get)   printf 'x\\000y\\000z' ;;
  set)   cat > "$BATS_TEST_TMPDIR/binsink" ;;
esac
EOF
  chmod +x "$BIN/clip.bin"
}

@test "dispatch get preserves NUL bytes (binary-safe)" {
  mk_binprovider
  clip::dispatch get plain > "$BATS_TEST_TMPDIR/out"
  # x \0 y \0 z = 5 bytes; a var-capture would collapse to 3 (NULs dropped)
  [ "$(wc -c < "$BATS_TEST_TMPDIR/out")" -eq 5 ]
}

@test "dispatch set preserves NUL bytes (binary-safe)" {
  mk_binprovider
  printf 'a\000b\000c' | clip::dispatch set plain
  [ "$(wc -c < "$BATS_TEST_TMPDIR/binsink")" -eq 5 ]
}
