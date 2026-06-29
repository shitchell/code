setup() { load helpers; source "$BATS_TEST_DIRNAME/../../sh/lib/clip.sh"; }

@test "picks highest-score provider that supports the op:type" {
  make_provider clip.low  30 "get:plain set:plain" "LOWVAL"
  make_provider clip.high 80 "get:plain set:plain" "HIGHVAL"
  run clip::dispatch get plain
  [ "$status" -eq 0 ]
  [ "$output" = "HIGHVAL" ]
}

@test "skips a higher-score provider that lacks the requested capability" {
  make_provider clip.rich 90 "get:plain set:plain" "PLAIN90"   # no get:rich
  make_provider clip.has  40 "get:plain get:rich"  "RICH40"
  run clip::dispatch get rich
  [ "$status" -eq 0 ]; [ "$output" = "RICH40" ]
}

@test "image with no provider errors with hint and exit 3" {
  make_provider clip.txt 50 "get:plain set:plain" "X"
  run clip::dispatch get image
  [ "$status" -eq 3 ]
  [[ "$output" == *"no provider for get:image"* ]]
}
