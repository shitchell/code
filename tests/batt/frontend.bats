setup() { load helpers; frontend_only_path; }

full_status='state discharging
percent 74
energy_now_wh 36.53
energy_full_wh 48.76
energy_design_wh 52.80
health_pct 92.4
cycles 312
volts 7.88
amps 1.23
watts 9.69
seconds_left 17503'

# --- summary ---------------------------------------------------------------

@test "summary renders charge, draw, remaining and health" {
  make_status_provider batt.fake 50 "$full_status"
  run batt
  [ "$status" -eq 0 ]
  [[ "$output" == *"Battery"*"74%"*"discharging"* ]]
  [[ "$output" == *"Draw"*"9.69 W"*"1.23 A @ 7.88 V"* ]]
  [[ "$output" == *"Remaining"*"4h 51m"* ]]
  [[ "$output" == *"Health"*"92.4%"*"48.76 / 52.80 Wh"* ]]
  [[ "$output" == *"Cycles"*"312"* ]]
}

@test "charging relabels the time row as To full" {
  make_status_provider batt.fake 50 'state charging
percent 40
seconds_left 3600'
  run batt
  [ "$status" -eq 0 ]
  [[ "$output" == *"To full"*"1h 0m"* ]]
  [[ "$output" != *"Remaining"* ]]
}

@test "charging labels the rate row Charging, not Draw" {
  # The sensor measures battery flow. While charging that is energy INTO the
  # battery, not system consumption, so calling it "Draw" is simply wrong.
  make_status_provider batt.fake 50 'state charging
percent 56
amps 2.02
volts 7.96
watts 16.04'
  run batt
  [ "$status" -eq 0 ]
  [[ "$output" == *"Charging"*"16.04 W"* ]]
  [[ "$output" != *"Draw"* ]]
}

@test "discharging labels the rate row Draw" {
  make_status_provider batt.fake 50 'state discharging
percent 56
watts 9.40'
  run batt
  [ "$status" -eq 0 ]
  [[ "$output" == *"Draw"*"9.40 W"* ]]
  [[ "$output" != *"Charging"* ]]
}

@test "a full battery suppresses the rate row entirely" {
  # Flow is ~0 and says nothing about consumption; "Draw 0.00 W" would read as
  # "this laptop is using no power", which is false while it sits on AC.
  make_status_provider batt.fake 50 'state full
percent 100
watts 0.00'
  run batt
  [ "$status" -eq 0 ]
  [[ "$output" == *"100%"* ]]
  [[ "$output" != *"Draw"* ]]
  [[ "$output" != *"Charging"* ]]
  [[ "$output" != *"0.00 W"* ]]
}

@test "notcharging on AC also suppresses the rate row" {
  make_status_provider batt.fake 50 'state notcharging
percent 80
watts 0.00'
  run batt
  [ "$status" -eq 0 ]
  [[ "$output" != *"0.00 W"* ]]
}

@test "watts is still queryable as a field regardless of label" {
  # Scripts want the raw number; `state` tells them the direction.
  make_status_provider batt.fake 50 'state charging
percent 56
watts 16.04'
  run batt watts
  [ "$status" -eq 0 ]
  [ "$output" = "16.04" ]
}

@test "fields the provider omits are skipped entirely" {
  make_status_provider batt.fake 50 'state discharging
percent 74'
  run batt
  [ "$status" -eq 0 ]
  [[ "$output" == *"74%"* ]]
  [[ "$output" != *"Draw"* ]]
  [[ "$output" != *"Health"* ]]
  [[ "$output" != *"Remaining"* ]]
}

@test "cycle_count 0 is treated as 'not tracked' and hidden" {
  # Plenty of ECs report 0 forever; showing "Cycles 0" reads as a real
  # measurement of a brand-new battery.
  make_status_provider batt.fake 50 'state discharging
percent 74
cycles 0'
  run batt
  [ "$status" -eq 0 ]
  [[ "$output" != *"Cycles"* ]]
}

# --- oneline ---------------------------------------------------------------

@test "oneline is compact and single-line" {
  make_status_provider batt.fake 50 "$full_status"
  run batt -1
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "$output" == *"74%"* ]]
  [[ "$output" == *"9.69W"* ]]
  [[ "$output" == *"4h 51m"* ]]
}

@test "oneline arrow reflects direction" {
  make_status_provider batt.fake 50 'state charging
percent 50'
  run batt --oneline
  [ "$status" -eq 0 ]
  [[ "$output" == *"↑"* ]]
}

# --- field mode ------------------------------------------------------------

@test "field mode prints a bare value for scripting" {
  make_status_provider batt.fake 50 "$full_status"
  run batt percent
  [ "$status" -eq 0 ]
  [ "$output" = "74" ]
}

@test "field 'health' maps onto health_pct" {
  make_status_provider batt.fake 50 "$full_status"
  run batt health
  [ "$status" -eq 0 ]
  [ "$output" = "92.4" ]
}

@test "field 'time' is rendered human-readable, not raw seconds" {
  make_status_provider batt.fake 50 "$full_status"
  run batt time
  [ "$status" -eq 0 ]
  [ "$output" = "4h 51m" ]
}

@test "a field the provider did not report exits 4" {
  make_status_provider batt.fake 50 'state discharging
percent 74'
  run batt watts
  [ "$status" -eq 4 ]
  [ -z "$output" ]
}

@test "an unknown field name is a usage error" {
  make_status_provider batt.fake 50 "$full_status"
  run batt nonsense
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown field"* ]]
}

# --- procs -----------------------------------------------------------------

@test "--procs degrades gracefully when no provider offers get:procs" {
  make_status_provider batt.fake 50 "$full_status"
  run batt -p
  [ "$status" -eq 0 ]
  [[ "$output" == *"74%"* ]]              # summary still rendered
  [[ "$output" == *"no provider"* ]]      # and the flag says why
}

# --- dispatch ---------------------------------------------------------------

@test "no provider at all exits 3 with a hint" {
  run batt
  [ "$status" -eq 3 ]
  [[ "$output" == *"no provider for get:status"* ]]
}

@test "highest-scoring capable provider wins" {
  make_status_provider batt.low  10 'state discharging
percent 11'
  make_status_provider batt.high 90 'state discharging
percent 99'
  run batt percent
  [ "$status" -eq 0 ]
  [ "$output" = "99" ]
}
