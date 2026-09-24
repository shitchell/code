# Portable `batt` command + shared provider dispatcher

Design for a provider-based `batt` command (clip/vol/bright pattern) and for
the extraction of `sh/lib/provider.sh`, the dispatch engine those three tools
had each been carrying as a private copy. Companion to
[2026-07-06-unified-vol-bright-design.md](2026-07-06-unified-vol-bright-design.md)
and [2026-06-29-unified-clipboard-design.md](2026-06-29-unified-clipboard-design.md).

> **Amended 2026-09-24:** providers are now named `provider.<ns>.<backend>`
> (e.g. `provider.batt.sysfs`) and enumerated with `compgen -c 'provider.<ns>.'`,
> across all four families. The bare `<ns>.` prefix matched unrelated
> executables such as Windows `clip.exe`. Names below use the new scheme; see
> [clipboard design §5](2026-06-29-unified-clipboard-design.md#5-provider-contract)
> for the full rationale.

## 1. Motivation

The immediate itch was simply not having a battery readout. `upower -i` answers
the question but is a mouthful, is absent on Termux and WSL, and — the part
that turned out to matter — reports a *smoothed* rate.

Why provider-based rather than one script (direct quote, 2026-07-29):

> can you write a script in the style of my vol/brightness scripts "batt" that
> aims to be portable with a registry system? that way it can work on WSL,
> termux, etc as i add more providers. for now, we'll just add one for this
> machine :) i'd love for it to display the above with an optional flag to
> remain alive and continue to show updated info every N seconds and another
> flag to show any high CPU draw processes

"the above" refers to a readout produced earlier in that session: percentage,
charge state, draw in watts, time to empty, and health as a percentage of
design capacity.

`batt` is also the **fourth** provider family, which is the trigger the
previous design set for revisiting the duplicated dispatcher:

> **Copy dispatcher per tool instead of shared provider.sh** — Accepted
> (YAGNI; don't destabilize clip). Revisit if a fourth provider family shows up.
> — 2026-07-06 design, §7

## 2. Architecture

```
batt (front-end: CLI, formatting, watch loop)
  │ batt::dispatch
  ▼
lib/batt.sh ──┐
lib/vol.sh    ├──► lib/provider.sh   (probe, score, timeout, fallback, cache)
lib/bright.sh │
lib/clip.sh ──┘
  │
  ▼
provider.batt.sysfs  provider.vol.wpctl  provider.bright.brightnessctl
provider.clip.wl  …                                      (providers)
```

The family libs are now ~30-line wrappers: a `<ns>::dispatch` that forwards to
`provider::dispatch`, an optional `<ns>::_no_provider` hook for the error
wording, and whatever family-specific helpers already lived there (clip keeps
`dbus_has_owner` and `real_binary`).

### 2.1 What the extraction had to absorb

The three copies had drifted in exactly four ways. All four became parameters
rather than forks:

| behavior | clip | vol / bright / batt |
|---|---|---|
| stdin buffered on `set` | yes (`--stdin`) | no — payloads are argv |
| winning-provider cache | no (`--no-cache`) | yes, 60s TTL |
| no-provider hint text | `<ns>::_no_provider` hook | same hook |
| env prefix | `CLIP_*` | `VOL_*` / `BRIGHT_*` / `BATT_*` |

Env knobs resolve by indirection off the uppercased namespace, so
`CLIP_TIMEOUT` and `BATT_TIMEOUT` are served by one code path.

One ordering change was needed: clip buffered stdin *after* candidate
selection, vol/bright had no buffering but did have a cache fast-path. The
merged flow buffers stdin **first**, so a cache-hit attempt can also be fed the
payload. Nothing exercises that combination today (clip is the only `--stdin`
family and it is uncached), but the alternative is a latent trap for the first
family that wants both.

## 3. `batt` contract

Read-only: there is no `set`, so the caps vocabulary is `get:status` plus the
optional `get:procs`.

**`get:status` returns `key value` lines, not a scalar.** A battery has no one
number, and — unlike volume — which attributes exist varies wildly by kernel,
platform and driver. Every field except `state` is optional; the front-end
renders what arrives and stays silent about the rest. An absent row is honest;
a row reading `unknown` invites being misread as zero.

```
state             charging|discharging|full|notcharging|unknown
percent           integer 0-100
watts amps volts  instantaneous rate and electrical state
energy_now_wh energy_full_wh energy_design_wh
health_pct        100 * full/design
cycles            integer
seconds_left      to empty when discharging, to full when charging
```

`get:procs` returns `cpu_pct<TAB>pid<TAB>command` lines. It lives in the
provider rather than the front-end because a truthful answer needs a `/proc`
delta sample; `ps(1)`'s `%cpu` is a process-lifetime average and would finger
a days-old idle browser instead of the thing draining the battery now. On a
platform where nothing can answer, `--procs` says so and the summary still
renders — it is not an error.

### 3.1 Front-end CLI

```
batt                     summary
batt <field>             one field, bare, for scripting
batt -1 | --oneline      compact single line (status bars)
batt -p | --procs        also list top CPU consumers
batt -w[N] | --watch[=N] refresh every N seconds (default 2)
```

Exit codes follow the family: 0 success, 1 usage, 3 no capable provider, and a
new 4 for "this provider does not report that field" — distinguishable from an
empty value.

## 4. Rates: instantaneous, but sampled

This is the one place the design is not a mechanical copy of `vol`.

`upower`'s `energy-rate` is polled and smoothed over roughly 30 seconds. That
lag is not academic — measured on libre 2026-07-29, with a runaway process
pinning two cores:

| | reading |
|---|---|
| `upower` energy-rate (smoothed) | 15.1 W |
| `current_now × voltage_now` (instant) | 18.7 W |
| true idle draw, after the process was killed | 9.4 W |

A readout that trails reality by a minute is useless for "what is eating my
battery right now", so providers read the instantaneous attributes.

Raw instantaneous reads are too noisy to show directly, though. The EC
refreshes `current_now` only about once a second, consecutive values spanned
1.08–1.42 A at a steady idle, and `batt` perturbs what it measures — its own
probe sweep is a CPU burst. Successive invocations disagreed by 3h40m vs 5h08m
on time-to-empty.

`provider.batt.sysfs` therefore takes the **median** of `BATT_RATE_SAMPLES` reads
(default 3, `BATT_RATE_GAP` 0.4s apart). Median, not mean: the failure mode is
a lone spike, and the median discards it. Measured over 8 runs:

| | spread | sd |
|---|---|---|
| single sample | 6.68 W | 2.687 |
| median of 3 | 2.17 W | 0.628 |

Cost is ~0.8s per invocation. `--oneline` opts down to a single sample, on the
grounds that a status bar would rather have a noisy number now than a settled
one a second late; an explicit `BATT_RATE_SAMPLES` always wins.

### 4.1 What the rate actually measures

The sensor reports **battery flow**, and its meaning flips with direction. This
is not a labelling nicety — the two readings are different physical quantities:

| state | sensor measures | is it system consumption? |
|---|---|---|
| discharging | energy out of the battery | **yes** — the battery is the only source |
| charging | energy into the battery | **no** — it is the charge rate |
| full / notcharging | ~0 | no — says nothing about consumption |

On AC the relationship is `P_adapter = P_system + P_charge`, and this machine
measures only `P_charge`. `/sys/class/power_supply/AC` exposes `online` and
nothing else — no current, no voltage, no wattage (confirmed 2026-07-29;
`hwmon0` is the AC device and carries no `*_input` files, while `hwmon1` is
just BAT0's current/voltage under another name). **System power on AC is
therefore unknowable on this hardware**, not merely unimplemented.

The summary labels the row accordingly — `Draw` when discharging, `Charging`
when charging — and suppresses it entirely when the battery is neither. A row
reading `Draw 0.00 W` on a machine sitting on AC would be actively wrong: it
reads as "this laptop is using no power".

`intel-rapl` powercap *is* present and would give CPU-package watts, but that
excludes backlight, NVMe and wifi — often 30-50% of total — so it could only
ever appear as an explicitly-named extra row, never as "system power". Left
out; noted in `~/TODO.md`.

The `watts` field itself stays a magnitude with `state` carrying direction, so
scripts are unaffected by the labelling.

## 5. `provider.batt.sysfs`

Score 60, leaving room above for a future `provider.batt.upower` (richer history)
without displacing a backend that needs no daemon and works in a VT or over
ssh.

- Handles both kernel flavours: `charge_*` (µAh) + `current_now` (µA), and
  `energy_*` (µWh) + `power_now` (µW).
- Wh on a charge-based battery is `Ah × voltage_min_design`, **not**
  `× voltage_now` — this is what upower does, and it reproduces its numbers
  exactly (8.127 Ah × 6.0 V = 48.76 Wh, upower says 48.762). Using
  `voltage_now` would have reported 64 Wh and a >100% health figure.
- Device selection: largest design capacity wins, and `scope=Device` is
  excluded so a wireless mouse's battery is never mistaken for the laptop's.
- `cycle_count` of 0 is treated by the front-end as "not tracked" and hidden;
  plenty of ECs report 0 forever, and displaying it reads as a measurement.
- `BATT_SYSFS_ROOT` overrides the class directory. It exists for the tests:
  the unit conversions are the part worth testing and cannot be pinned against
  real hardware whose values change between reads.

## 6. Testing

`tests/batt/sysfs.bats` (18) drives the provider against fixture trees —
both unit flavours, dual batteries, peripheral exclusion, charging and
discharging time maths, zero and negative current, non-numeric values, and
missing attributes. `tests/batt/frontend.bats` (14) drives the CLI against
fake providers.

The extraction itself is gated by the pre-existing `tests/clip/*.bats`, which
is why clip's no-cache behavior was preserved rather than unified: keeping the
migration behavior-preserving is what makes a green clip suite meaningful
evidence. Baseline before the refactor and after are both 0 failures.

Note bats is not installed on libre; it runs out of
`~/code/git/github.com/bats-core/bats-core/bin/bats`.

## 7. Decision log

- **Extract `provider.sh` and migrate all four families** — Accepted.
  Context: `batt` is the fourth family, which the 2026-07-06 design named as
  the revisit trigger. User chose full extraction + migration over two
  narrower options (a fourth copy; or extract-but-only-batt-uses-it).
  Rationale: TBD — the option was chosen from a menu without stated reasoning.
- **clip stays uncached after migration** — Accepted. Context: clip is the
  family whose probe once froze micro for 100s, and its bats suite is the only
  regression gate for the extraction. Rationale: keeping behavior identical is
  what makes a passing clip suite evidence that the refactor is sound; a
  cache for clip can land as its own revertible commit.
- **`get:status` returns key/value lines, not a scalar** — Accepted.
  Rationale: a battery has no single number, and platforms expose different
  subsets; a provider must be free to report only what it can honestly
  measure.
- **`get:procs` is a provider capability, not front-end code** — Accepted.
  Rationale: an honest answer needs a `/proc` delta sample, which is
  platform-specific; `ps %cpu` is a lifetime average and would name the wrong
  process.
- **Median-of-N sampling rather than a single read or upower's smoothed rate**
  — Accepted. Rationale and measurements: §4.
- **Exit 4 for "field not reported"** — Accepted. Rationale: distinguishes a
  provider that cannot measure something from a genuinely empty value, which
  a script consuming `batt watts` needs to tell apart.
- **Label the rate row by state; suppress it when idle** — Accepted
  2026-07-29, after the first AC test. Context: user, on seeing `Draw` persist
  while plugged in — "it might be nice to also no what the charge rate is? Or
  is that what Draw is when it's charging? it seems like those would be two
  always-on things: power consumed / power input. and it's simply that, when
  not charging, the latter is 0. or am i misunderstanding something?"
  The intuition is right that these are two distinct quantities; the
  correction is that this hardware measures only one of them, and which one
  depends on direction (§4.1). So the fix is honest labelling rather than a
  second figure.
- **Deferred**: `vtbatt` wrapper and tmux/status-bar wiring. `batt -1` exists
  to feed one, but no binding is added here.
