setup() { load helpers; export PATH="$BATS_TEST_DIRNAME/../../sh/bin:$PATH"; }

@test "clipout with no format emits plaintext" {
  make_provider clip.g 70 "get:plain set:plain" "hello"
  run sh/bin/clipout
  [ "$status" -eq 0 ]
  [ "$output" = "hello" ]
}

@test "clipout --format rich returns provider rich output" {
  make_provider clip.r 80 "get:plain get:rich" "<b>hi</b>"
  run sh/bin/clipout --format rich
  [ "$status" -eq 0 ]
  [ "$output" = "<b>hi</b>" ]
}

@test "clipout --format markdown needs rich provider; errors if absent" {
  make_provider clip.g 70 "get:plain set:plain" "hello"
  run sh/bin/clipout --format markdown
  [ "$status" -ne 0 ]
  [[ "$output" == *"no provider for get:rich"* ]]
}

@test "clipout --format markdown converts rich html via pandoc" {
  command -v pandoc >/dev/null || skip "no pandoc"
  make_provider clip.r 80 "get:plain get:rich" "<b>hi</b>"
  run sh/bin/clipout --format markdown
  [ "$status" -eq 0 ]
  [[ "$output" == *"**hi**"* ]]
}

@test "clipout --image dispatches a get image" {
  make_provider clip.i 90 "get:plain get:image" "IMGBYTES"
  run sh/bin/clipout --image
  [ "$status" -eq 0 ]
  [ "$output" = "IMGBYTES" ]
}

@test "clipout unknown format errors with exit 2" {
  make_provider clip.g 70 "get:plain set:plain" "hello"
  run sh/bin/clipout --format bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown format"* ]]
}
