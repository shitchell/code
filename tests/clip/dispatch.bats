setup() { load helpers; source "$BATS_TEST_DIRNAME/../../sh/lib/clip.sh"; }

@test "picks highest-score provider that supports the op:type" {
  make_provider clip.low  30 "get:plain set:plain" "LOWVAL"
  make_provider clip.high 80 "get:plain set:plain" "HIGHVAL"
  run clip::dispatch get plain
  [ "$status" -eq 0 ]
  [ "$output" = "HIGHVAL" ]
}
