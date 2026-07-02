# helpers.bash — make fake clip.* providers on a temp PATH
make_provider() { # $1=name $2=score $3=caps $4=get-output
  local dir="$BATS_TEST_TMPDIR/bin"; mkdir -p "$dir"
  cat > "$dir/$1" <<EOF
#!/bin/bash
case "\$1" in
  probe) echo "score $2"; echo "caps $3" ;;
  get)   printf '%s' "$4" ;;
  set)   cat > "$BATS_TEST_TMPDIR/$1.sink" ;;
esac
EOF
  chmod +x "$dir/$1"
  export PATH="$dir:$PATH"
}

make_failing_provider() { # $1=name $2=score $3=caps
  # A capable provider whose get/set always exits non-zero (after draining any
  # stdin), to exercise the dispatcher's fall-back-on-failure path.
  local dir="$BATS_TEST_TMPDIR/bin"; mkdir -p "$dir"
  cat > "$dir/$1" <<EOF
#!/bin/bash
case "\$1" in
  probe) echo "score $2"; echo "caps $3" ;;
  get)   exit 1 ;;
  set)   cat >/dev/null; exit 1 ;;
esac
EOF
  chmod +x "$dir/$1"
  export PATH="$dir:$PATH"
}

make_hanging_provider() { # $1=name $2=score $3=caps
  # A capable provider that hangs forever on get/set, to exercise the
  # dispatcher's timeout + fall-back path. It must NOT hang during probe.
  local dir="$BATS_TEST_TMPDIR/bin"; mkdir -p "$dir"
  cat > "$dir/$1" <<EOF
#!/bin/bash
case "\$1" in
  probe) echo "score $2"; echo "caps $3" ;;
  get)   sleep 300 ;;
  set)   sleep 300 ;;
esac
EOF
  chmod +x "$dir/$1"
  export PATH="$dir:$PATH"
}

frontends_only_path() {
  # Expose the suite's front-end commands (clipin/clipout/clipinout/clip) on a
  # clean PATH that contains NONE of the real clip.<tag> providers, so negative
  # and DWIM tests control which providers exist purely via make_provider.
  # Symlinks preserve readlink -f resolution back to sh/bin (so the front-ends
  # still source ../lib/clip.sh correctly).
  local fe="$BATS_TEST_TMPDIR/fe" f
  mkdir -p "$fe"
  for f in clipin clipout clipinout clip; do
    ln -sf "$BATS_TEST_DIRNAME/../../sh/bin/$f" "$fe/$f"
  done
  export PATH="$fe:/usr/bin:/bin"
}
