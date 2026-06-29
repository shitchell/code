setup() { load helpers; export PATH="$BATS_TEST_DIRNAME/../../sh/bin:$PATH"; }

@test "clip with stdin acts as clipin" {
  make_provider clip.g 70 "get:plain set:plain" ""
  echo z | sh/bin/clip
  [ "$(cat "$BATS_TEST_TMPDIR/clip.g.sink")" = "z" ]
}

@test "clip without stdin acts as clipout" {
  make_provider clip.g 70 "get:plain set:plain" "OUT"
  run sh/bin/clip </dev/null
  [ "$status" -eq 0 ]
  [ "$output" = "OUT" ]
}

@test "clip image DWIM: no text + image provider + redirected stdout emits bytes" {
  make_provider clip.i 90 "get:image" "IMGBYTES"
  run sh/bin/clip </dev/null
  [ "$status" -eq 0 ]
  [ "$output" = "IMGBYTES" ]
}
