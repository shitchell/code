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
