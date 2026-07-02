# Dispatcher timeout + fallback (Task C).
#
# Every backend on this box can occasionally stall, so clip::dispatch wraps each
# provider in `timeout` (CLIP_TIMEOUT, default 5s) and, if the chosen provider
# times out (124) or exits non-zero, falls back to the next-highest-scoring
# capable provider until one succeeds or none remain. On `set`, stdin is
# buffered once so every fallback attempt gets the full payload.

setup() {
  load helpers
  source "$BATS_TEST_DIRNAME/../../sh/lib/clip.sh"
  # Isolate PATH so clip::_providers (compgen -c 'clip.') sees ONLY the fakes
  # this file creates, not the real clip.* in ~/code/sh/bin. make_* helpers
  # prepend $BATS_TEST_TMPDIR/bin to PATH.
  export PATH="/usr/bin:/bin"
}

@test "chosen provider times out -> falls back to next and returns its output" {
  export CLIP_TIMEOUT=1
  make_hanging_provider clip.hang 80 "get:plain set:plain"
  make_provider         clip.ok   50 "get:plain set:plain" "OKVAL"
  run clip::dispatch get plain
  [ "$status" -eq 0 ]
  [ "$output" = "OKVAL" ]
}

@test "chosen provider exits non-zero -> falls back to next" {
  make_failing_provider clip.fail 80 "get:plain set:plain"
  make_provider         clip.ok   50 "get:plain set:plain" "OKVAL"
  run clip::dispatch get plain
  [ "$status" -eq 0 ]
  [ "$output" = "OKVAL" ]
}

@test "set payload reaches the fallback provider intact after first fails" {
  make_failing_provider clip.fail 80 "get:plain set:plain"
  make_provider         clip.ok   50 "get:plain set:plain" ""   # writes stdin to sink
  run bash -c "printf '%s' 'PAYLOAD-abc-123' | { source '$BATS_TEST_DIRNAME/../../sh/lib/clip.sh'; clip::dispatch set plain; }"
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/clip.ok.sink")" = "PAYLOAD-abc-123" ]
}

@test "all capable providers fail -> exit 3 with hint" {
  make_failing_provider clip.f1 80 "get:plain set:plain"
  make_failing_provider clip.f2 50 "get:plain set:plain"
  run clip::dispatch get plain
  [ "$status" -eq 3 ]
  [[ "$output" == *"no provider"* || "$output" == *"clip:"* ]]
}

@test "get output of a failed provider is not emitted before falling back" {
  # A provider that prints partial output then exits non-zero must NOT leak that
  # partial output; only the successful fallback's output is emitted.
  local dir="$BATS_TEST_TMPDIR/bin"; mkdir -p "$dir"
  cat > "$dir/clip.partial" <<'EOF'
#!/bin/bash
case "$1" in
  probe) echo "score 80"; echo "caps get:plain set:plain" ;;
  get)   printf 'GARBAGE'; exit 1 ;;
esac
EOF
  chmod +x "$dir/clip.partial"
  export PATH="$dir:$PATH"
  make_provider clip.ok 50 "get:plain set:plain" "CLEAN"
  run clip::dispatch get plain
  [ "$status" -eq 0 ]
  [ "$output" = "CLEAN" ]
}
