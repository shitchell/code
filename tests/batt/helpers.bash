# helpers.bash — fake batt.* providers and fake sysfs trees

make_provider() { # $1=name $2=score $3=caps $4=get-output
  local dir="$BATS_TEST_TMPDIR/bin"; mkdir -p "$dir"
  cat > "$dir/$1" <<EOF
#!/bin/bash
case "\$1" in
  probe) echo "score $2"; echo "caps $3" ;;
  get)   printf '%s' "$4" ;;
esac
EOF
  chmod +x "$dir/$1"
  export PATH="$dir:$PATH"
}

make_status_provider() { # $1=name $2=score $3=status-body
  # A provider whose `get status` emits the given "key value" lines verbatim.
  local dir="$BATS_TEST_TMPDIR/bin"; mkdir -p "$dir"
  cat > "$dir/$1" <<EOF
#!/bin/bash
case "\$1:\$2" in
  probe:*)     echo "score $2"; echo "caps get:status" ;;
  get:status)  cat <<'BODY'
$3
BODY
    ;;
  *) exit 1 ;;
esac
EOF
  chmod +x "$dir/$1"
  export PATH="$dir:$PATH"
}

frontend_only_path() {
  # Expose `batt` on a PATH with NO real batt.<tag> providers, so tests control
  # provider existence entirely via the make_*_provider helpers. A symlink
  # preserves readlink -f resolution back to sh/bin so the front-end still
  # sources ../lib/batt.sh.
  local fe="$BATS_TEST_TMPDIR/fe"
  mkdir -p "$fe"
  ln -sf "$BATS_TEST_DIRNAME/../../sh/bin/batt" "$fe/batt"
  export PATH="$fe:/usr/bin:/bin"
}

# --- fake sysfs ------------------------------------------------------------

mk_battery() { # $1=devname; remaining args are "attr=value"
  local dev="$BATS_TEST_TMPDIR/sysfs/$1"; mkdir -p "$dev"
  local kv
  for kv in "${@:2}"; do
    printf '%s\n' "${kv#*=}" > "$dev/${kv%%=*}"
  done
  export BATT_SYSFS_ROOT="$BATS_TEST_TMPDIR/sysfs"
}

# A charge-based (µAh) battery matching this machine's real values, verified
# against upower on 2026-07-29: 48.762 Wh full, 92.35% health.
mk_charge_battery() {
  mk_battery BAT0 \
    type=Battery \
    status=Discharging \
    capacity=74 \
    charge_now=5980000 \
    charge_full=8127000 \
    charge_full_design=8800000 \
    voltage_now=7880000 \
    voltage_min_design=6000000 \
    current_now=1230000 \
    cycle_count=0
}

# An energy-based (µWh) battery, the other common kernel flavour.
mk_energy_battery() {
  mk_battery BAT0 \
    type=Battery \
    status=Discharging \
    energy_now=30000000 \
    energy_full=50000000 \
    energy_full_design=60000000 \
    voltage_now=11000000 \
    power_now=10000000
}

# Run the provider with rate sampling collapsed to a single read, so tests do
# not pay the 0.8s median window.
batt_sysfs() {
  BATT_RATE_SAMPLES=1 "$BATS_TEST_DIRNAME/../../sh/bin/batt.sysfs" "$@"
}

# Pull one "key value" line out of a status blob.
field_of() { # $1=key; status on stdin
  awk -v k="$1" '$1==k {print $2; found=1} END{exit !found}'
}
