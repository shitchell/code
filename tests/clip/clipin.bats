setup() { load helpers; frontends_only_path; }

@test "clipin from args" {
  make_provider clip.g 70 "get:plain set:plain" ""
  run sh/bin/clipin "hello world"
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/clip.g.sink")" = "hello world" ]
}

@test "clipin joins multiple args" {
  make_provider clip.g 70 "get:plain set:plain" ""
  run sh/bin/clipin foo bar baz
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/clip.g.sink")" = "foo bar baz" ]
}

@test "clipin from stdin" {
  make_provider clip.g 70 "get:plain set:plain" ""
  echo piped | sh/bin/clipin
  [ "$(cat "$BATS_TEST_TMPDIR/clip.g.sink")" = "piped" ]
}

@test "clipin with no provider exits 3" {
  run sh/bin/clipin "x" </dev/null
  [ "$status" -eq 3 ]
}
