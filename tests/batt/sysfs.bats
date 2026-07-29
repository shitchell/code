setup() { load helpers; }

# --- device selection ------------------------------------------------------

@test "picks the battery, ignoring an AC adapter entry" {
  mk_charge_battery
  mk_battery ACAD type=Mains online=1
  run batt_sysfs get status
  [ "$status" -eq 0 ]
  [[ "$output" == *"percent 74"* ]]
}

@test "ignores peripheral batteries (scope=Device)" {
  # A wireless mouse reports type=Battery too. Selecting it would report the
  # mouse's charge as the laptop's.
  mk_battery hidpp_battery_0 type=Battery scope=Device capacity=10 status=Discharging
  mk_charge_battery
  run batt_sysfs get status
  [ "$status" -eq 0 ]
  [[ "$output" == *"percent 74"* ]]
}

@test "with two system batteries, the larger design capacity wins" {
  mk_battery BAT1 type=Battery status=Discharging capacity=20 \
    charge_now=1000000 charge_full=2000000 charge_full_design=2000000
  mk_charge_battery   # design 8800000 > 2000000
  run batt_sysfs get status
  [ "$status" -eq 0 ]
  [[ "$output" == *"percent 74"* ]]
}

@test "no battery present -> score 0, not a candidate" {
  mk_battery ACAD type=Mains online=1
  run batt_sysfs probe
  [ "$status" -eq 0 ]
  [[ "$output" == *"score 0"* ]]
  [[ "$output" != *"caps"* ]]
}

# --- unit conversion -------------------------------------------------------

@test "charge battery: Wh uses voltage_min_design, matching upower" {
  # 8.127 Ah * 6.0 V = 48.76 Wh. Using voltage_now (7.88 V) would give 64.04 —
  # the bug this test exists to prevent.
  mk_charge_battery
  run batt_sysfs get status
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | field_of energy_full_wh)" = "48.76" ]
  [ "$(printf '%s\n' "$output" | field_of energy_design_wh)" = "52.80" ]
}

@test "energy battery: Wh is passed through without a voltage multiply" {
  mk_energy_battery
  run batt_sysfs get status
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | field_of energy_full_wh)" = "50.00" ]
  [ "$(printf '%s\n' "$output" | field_of energy_design_wh)" = "60.00" ]
}

@test "health is full/design regardless of unit flavour" {
  mk_charge_battery
  run batt_sysfs get status
  [ "$(printf '%s\n' "$output" | field_of health_pct)" = "92.4" ]
}

@test "watts from current_now * voltage_now on a charge battery" {
  # 1.23 A * 7.88 V = 9.69 W
  mk_charge_battery
  run batt_sysfs get status
  [ "$(printf '%s\n' "$output" | field_of watts)" = "9.69" ]
  [ "$(printf '%s\n' "$output" | field_of amps)" = "1.23" ]
}

@test "watts from power_now directly on an energy battery" {
  mk_energy_battery
  run batt_sysfs get status
  [ "$(printf '%s\n' "$output" | field_of watts)" = "10.00" ]
}

# --- state and time --------------------------------------------------------

@test "seconds_left while discharging counts down from charge_now" {
  # 5.98 Ah / 1.23 A = 4.862h = 17503s
  mk_charge_battery
  run batt_sysfs get status
  local secs; secs=$(printf '%s\n' "$output" | field_of seconds_left)
  [ "$secs" -gt 17400 ] && [ "$secs" -lt 17600 ]
}

@test "seconds_left while charging counts up to charge_full" {
  # (8.127 - 5.98) Ah / 1.23 A = 1.745h = 6284s
  mk_charge_battery
  printf 'Charging\n' > "$BATT_SYSFS_ROOT/BAT0/status"
  run batt_sysfs get status
  [[ "$output" == *"state charging"* ]]
  local secs; secs=$(printf '%s\n' "$output" | field_of seconds_left)
  [ "$secs" -gt 6200 ] && [ "$secs" -lt 6400 ]
}

@test "a full battery reports no seconds_left" {
  mk_charge_battery
  printf 'Full\n' > "$BATT_SYSFS_ROOT/BAT0/status"
  run batt_sysfs get status
  [[ "$output" == *"state full"* ]]
  ! printf '%s\n' "$output" | field_of seconds_left
}

@test "zero current reports no seconds_left instead of dividing by zero" {
  mk_charge_battery
  printf '0\n' > "$BATT_SYSFS_ROOT/BAT0/current_now"
  run batt_sysfs get status
  [ "$status" -eq 0 ]
  ! printf '%s\n' "$output" | field_of seconds_left
}

@test "negative current (charging on some drivers) is read as a magnitude" {
  mk_charge_battery
  printf -- '-1230000\n' > "$BATT_SYSFS_ROOT/BAT0/current_now"
  run batt_sysfs get status
  [ "$(printf '%s\n' "$output" | field_of amps)" = "1.23" ]
}

@test "'Not charging' maps to notcharging, not unknown" {
  # Plugged in but the EC has stopped the charge — a real Librem 14 state, and
  # meaningfully different from 'unknown'.
  mk_charge_battery
  printf 'Not charging\n' > "$BATT_SYSFS_ROOT/BAT0/status"
  run batt_sysfs get status
  [[ "$output" == *"state notcharging"* ]]
}

# --- degraded inputs -------------------------------------------------------

@test "missing optional attributes are omitted, not emitted empty" {
  mk_battery BAT0 type=Battery status=Discharging capacity=55
  run batt_sysfs get status
  [ "$status" -eq 0 ]
  [[ "$output" == *"state discharging"* ]]
  [[ "$output" == *"percent 55"* ]]
  [[ "$output" != *"watts"* ]]
  [[ "$output" != *"health_pct"* ]]
}

@test "percent is derived from now/full when capacity is absent" {
  mk_battery BAT0 type=Battery status=Discharging \
    charge_now=5000000 charge_full=10000000 charge_full_design=10000000
  run batt_sysfs get status
  [ "$(printf '%s\n' "$output" | field_of percent)" = "50" ]
}

@test "a non-numeric sysfs value is skipped rather than emitted" {
  mk_charge_battery
  printf 'garbage\n' > "$BATT_SYSFS_ROOT/BAT0/cycle_count"
  run batt_sysfs get status
  [ "$status" -eq 0 ]
  [[ "$output" != *"cycles"* ]]
}
