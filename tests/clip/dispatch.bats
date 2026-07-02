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

@test "a provider that drains stdin during probe does not truncate enumeration" {
  # Regression: real backends like gpaste-client read stdin. The dispatcher
  # feeds the provider list on the probe loop's stdin via process substitution,
  # so a stdin-draining provider would eat the remaining provider names and
  # truncate enumeration unless the probe call has its stdin redirected.
  local dir="$BATS_TEST_TMPDIR/bin"; mkdir -p "$dir"
  cat > "$dir/clip.aaa" <<'EOF'
#!/bin/bash
case "$1" in
  probe) cat >/dev/null; echo "score 10"; echo "caps get:plain set:plain" ;;
  get)   printf 'AAA' ;;
esac
EOF
  chmod +x "$dir/clip.aaa"          # sorts first; drains stdin in probe
  export PATH="$dir:$PATH"
  make_provider clip.zzz 90 "get:plain set:plain" "ZZZVAL"   # sorts last
  run clip::dispatch get plain
  [ "$status" -eq 0 ]
  [ "$output" = "ZZZVAL" ]
}

@test "both providers present: wl (70) wins plain over gpaste (50)" {
  # Task B: wl-clipboard is the chosen primary and must out-score gpaste where
  # both exist. Fakes model the new scores/caps deterministically.
  make_provider clip.wl     70 "get:plain set:plain get:rich set:rich get:image set:image" "WLVAL"
  make_provider clip.gpaste 50 "get:plain set:plain" "GPVAL"
  run clip::dispatch get plain
  [ "$status" -eq 0 ]
  [ "$output" = "WLVAL" ]
}

@test "both providers present: rich routes to wl (only wl offers it)" {
  make_provider clip.wl     70 "get:plain set:plain get:rich set:rich get:image set:image" "WLRICH"
  make_provider clip.gpaste 50 "get:plain set:plain" "GPVAL"
  run clip::dispatch get rich
  [ "$status" -eq 0 ]
  [ "$output" = "WLRICH" ]
}

@test "both providers present: image routes to wl (only wl offers it)" {
  make_provider clip.wl     70 "get:plain set:plain get:rich set:rich get:image set:image" "WLIMG"
  make_provider clip.gpaste 50 "get:plain set:plain" "GPVAL"
  run clip::dispatch get image
  [ "$status" -eq 0 ]
  [ "$output" = "WLIMG" ]
}

@test "gpaste-only box (wl scores 0): gpaste still wins plain" {
  # On a machine with gpaste but no wl-* binaries, clip.wl probes score 0 and is
  # ineligible, so gpaste is selected for plain.
  make_provider clip.wl     0  "" ""
  make_provider clip.gpaste 50 "get:plain set:plain" "GPVAL"
  run clip::dispatch get plain
  [ "$status" -eq 0 ]
  [ "$output" = "GPVAL" ]
}

@test "real_binary skips our shim (in HOME) and returns the system binary" {
  # fake a shim under a HOME-like dir and a 'real' one elsewhere
  HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME/code/sh/bin" "$BATS_TEST_TMPDIR/usr"
  printf '#!/bin/bash\n' > "$HOME/code/sh/bin/foocmd"; chmod +x "$HOME/code/sh/bin/foocmd"
  printf '\x7fELF realish' > "$BATS_TEST_TMPDIR/usr/foocmd"; chmod +x "$BATS_TEST_TMPDIR/usr/foocmd"
  export PATH="$HOME/code/sh/bin:$BATS_TEST_TMPDIR/usr:$PATH"
  run clip::real_binary foocmd --need-nonhome
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TEST_TMPDIR/usr/foocmd" ]
}
