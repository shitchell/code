setup() { load helpers; frontends_only_path; }

@test "clipin from args" {
  make_provider provider.clip.g 70 "get:plain set:plain" ""
  run sh/bin/clipin "hello world"
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/provider.clip.g.sink")" = "hello world" ]
}

@test "clipin joins multiple args" {
  make_provider provider.clip.g 70 "get:plain set:plain" ""
  run sh/bin/clipin foo bar baz
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/provider.clip.g.sink")" = "foo bar baz" ]
}

@test "clipin from stdin" {
  make_provider provider.clip.g 70 "get:plain set:plain" ""
  echo piped | sh/bin/clipin
  [ "$(cat "$BATS_TEST_TMPDIR/provider.clip.g.sink")" = "piped" ]
}

@test "clipin with no provider exits 3" {
  run sh/bin/clipin "x" </dev/null
  [ "$status" -eq 3 ]
}

@test "clipin --help prints usage and copies nothing" {
  make_provider provider.clip.g 70 "get:plain set:plain" ""
  run sh/bin/clipin --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--markdown"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/provider.clip.g.sink" ]
}

@test "clipin -- copies a literal leading option" {
  make_provider provider.clip.g 70 "get:plain set:plain" ""
  run sh/bin/clipin -- --help
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/provider.clip.g.sink")" = "--help" ]
}

# --- clipin --markdown -------------------------------------------------------

@test "clipin --markdown dispatches set rich: HTML fragment + markdown fallback" {
  command -v pandoc >/dev/null || skip "no pandoc"
  make_rich_recorder provider.clip.r 80
  printf '# Hi\n\nsome **bold** ✓\n' | sh/bin/clipin --markdown
  [ "$(cat "$BATS_TEST_TMPDIR/provider.clip.r.type")" = "rich" ]
  grep -q '<h1' "$BATS_TEST_TMPDIR/provider.clip.r.sink"
  grep -q '<strong>bold</strong> ✓' "$BATS_TEST_TMPDIR/provider.clip.r.sink"
  # A fragment, not a standalone document.
  ! grep -qi '<html' "$BATS_TEST_TMPDIR/provider.clip.r.sink"
  [ "$(cat "$BATS_TEST_TMPDIR/provider.clip.r.fallback")" = "$(printf '# Hi\n\nsome **bold** ✓\n')" ]
}

@test "clipin -m reads markdown from args" {
  command -v pandoc >/dev/null || skip "no pandoc"
  make_rich_recorder provider.clip.r 80
  run sh/bin/clipin -m 'some *em*'
  [ "$status" -eq 0 ]
  grep -q '<em>em</em>' "$BATS_TEST_TMPDIR/provider.clip.r.sink"
  [ "$(cat "$BATS_TEST_TMPDIR/provider.clip.r.fallback")" = "some *em*" ]
}

@test "clipin --markdown with no set:rich provider falls back to plain markdown" {
  command -v pandoc >/dev/null || skip "no pandoc"
  make_provider provider.clip.g 70 "get:plain set:plain" ""
  run sh/bin/clipin --markdown 'some **bold**'
  [ "$status" -eq 0 ]
  [[ "$output" == *"copied the markdown as plain text"* ]]
  [ "$(cat "$BATS_TEST_TMPDIR/provider.clip.g.sink")" = "some **bold**" ]
}

@test "clipin --markdown errors clearly (exit 3) without pandoc" {
  make_rich_recorder provider.clip.r 80
  # Only the tools clipin needs to start -- no pandoc.
  local nop="$BATS_TEST_TMPDIR/nopandoc" t
  mkdir -p "$nop"
  for t in bash dirname readlink; do ln -sf "$(command -v "$t")" "$nop/$t"; done
  run env PATH="$BATS_TEST_TMPDIR/fe:$BATS_TEST_TMPDIR/bin:$nop" \
    "$BATS_TEST_TMPDIR/fe/clipin" --markdown 'x'
  [ "$status" -eq 3 ]
  [[ "$output" == *"pandoc required"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/provider.clip.r.sink" ]
}

@test "clipin without --markdown is unchanged: set plain, no fallback env" {
  make_rich_recorder provider.clip.r 80
  run sh/bin/clipin '**not rendered**'
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/provider.clip.r.type")" = "plain" ]
  [ "$(cat "$BATS_TEST_TMPDIR/provider.clip.r.sink")" = "**not rendered**" ]
  [ ! -e "$BATS_TEST_TMPDIR/provider.clip.r.fallback" ]
}
