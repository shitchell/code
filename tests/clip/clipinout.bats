setup() { load helpers; export PATH="$BATS_TEST_DIRNAME/../../sh/bin:$PATH"; }

@test "clipinout copies then pastes" {
  make_provider clip.g 70 "get:plain set:plain" "RT"
  run sh/bin/clipinout "x"
  [ "$status" -eq 0 ]
  [ "$output" = "RT" ]
  [ "$(cat "$BATS_TEST_TMPDIR/clip.g.sink")" = "x" ]
}

@test "clipinout from stdin copies then pastes" {
  make_provider clip.g 70 "get:plain set:plain" "RT"
  run bash -c 'echo piped | sh/bin/clipinout'
  [ "$status" -eq 0 ]
  [ "$output" = "RT" ]
  [ "$(cat "$BATS_TEST_TMPDIR/clip.g.sink")" = "piped" ]
}
