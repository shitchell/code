# Unified volume/brightness commands + VT console wiring

Design for provider-based `vol` and `bright` commands (clip-pattern), thin
VT-aware `vtvol`/`vtbright` wrappers, and the fbterm/tmux key wiring that
consumes them. Companion to
[2026-06-29-unified-clipboard-design.md](2026-06-29-unified-clipboard-design.md),
whose architecture this deliberately mirrors.

## 1. Motivation

The immediate itch: tmux volume bindings in the tracked `.tmux.conf`
(prefix+F10/11/12) shell out to `pactl`, which no longer exists on libre
(PipeWire/WirePlumber; `wpctl` is the tool). Brightness has no bindings at
all, and `bin/brightness` is an abandoned draft hardcoded to a backlight
device (`intel_backlight`) that doesn't exist on libre (`acpi_video0` does,
verified working 2026-07-06). `bin/vol` works but is monolithic — its inline
backend chain doesn't know `wpctl`, so on libre it silently falls through to
`amixer`.

Why provider-based rather than two quick scripts (direct quote, 2026-07-06):

> actually, i do like using this setup in a few different places... can we try
> and set this up in a way that's more portable so that we *can* re-use it on
> other machines? perhaps using some setup similar to the `clip` system we
> recently set up with providers that register how to access the clipboard on
> different systems […] that way we can have a consistent `vol` and `bright`
> command that work on any system (or can be extended to work on new systems),
> and *then* we would actually be able to check them in, track them, and then
> we could do the same for tmux. the only thing i'd alter is writing small
> vtvol and vtbright wrappers (linked to under ~/projects/vtcon/ to keep
> everything together) which (1) check whether the wrapper is being called in
> a VT session and if yes then (2) passes $@ to `vol`/`bright`. and then those
> wrappers are what we'd link to in the tracked .tmux.conf.

## 2. Architecture: three layers

```
tracked .tmux.conf  ──binds──►  vtvol / vtbright     (policy: VT gate + toast)
                                     │ $@
                                     ▼
                                vol / bright          (mechanism: portable CLI)
                                     │ dispatch
                                     ▼
                    vol.wpctl  vol.pactl  vol.alsa …  (providers: one per system)
                    bright.sysfs  bright.brightnessctl
```

- **`vol` / `bright`** — mechanism only. No VT logic, no notifications.
  Identical behavior on a desktop, a headless box, a VT, Termux, or WSL.
- **`vtvol` / `vtbright`** — policy. Seat-gated no-op outside text VTs;
  delegate `$@`; fire lnotify *if configured* (quote: "oh, and the `vt*`
  wrappers would also fire the lnotify call *if* lnotify is configured on the
  system (again, portability)").
- **tmux** — three key bindings and nothing else, guarded so the tracked
  config stays inert on machines without the tools.

## 3. Portable layer (sh repo)

Layout and contract copied from clip (see clipboard design §3–§8):

| Piece | Path |
|---|---|
| Dispatcher libs (source-only, not +x) | `sh/lib/vol.sh`, `sh/lib/bright.sh` |
| Front-ends | `sh/bin/vol`, `sh/bin/bright` |
| Volume providers | `sh/bin/vol.wpctl` (new), `.pactl`, `.alsa`, `.termux`, `.powershell`, `.macos` (ported from monolithic `vol`) |
| Brightness providers | `sh/bin/bright.sysfs`, `sh/bin/bright.brightnessctl` |

- Dispatch logic is a namespaced copy of `clip::dispatch` (probe → `score N` +
  `caps …`, filter on capability, sort by score desc, `timeout` per attempt,
  fall back down the list, exit 3 when none succeed). We copy rather than
  extract a shared `provider.sh` so the working clip system stays untouched;
  consolidating the three copies is a possible later change.
- Caps vocabulary: `get:volume set:volume get:mute set:mute` and
  `get:brightness set:brightness` — a provider may honestly advertise a
  subset (e.g. a backend with no mute concept).
- Numbers are integer percent 0–100 end to end. Providers get/set raw state
  only; the front-ends own `±N` math and clamping (0–100; `bright` floors at
  1 so a typo can't black the panel).
- Front-ends print the resulting state after a set (`vol +5` → `85`,
  `vol mute` → `on|off`), so vtvol/vtbright build their toast from a single
  invocation (added 2026-07-06 after a measured ~1.5s keypress→toast lag:
  ~90ms probe sweep + ~120ms bash/dispatcher overhead × 3 invocations × up
  to 4 dispatches).
- Winning providers are cached per `op:control` in `XDG_RUNTIME_DIR` with a
  60s TTL (`VOL_CACHE_TTL`/`BRIGHT_CACHE_TTL`) + failure invalidation: a
  cached provider that errors is dropped and the same invocation re-probes,
  so a backend swap never errors a keypress — it pays ~90ms once. TTL chosen
  over background re-validation (always-fast, self-corrects next press) for
  simplicity: no background jobs or cache-write races from a mashed
  keybinding. Quote: "what are the odds i press the volume key, which
  updates the cache, then swap out the backend in a breaking-change sort of
  way and in less than 60 seconds, then press the volume key again".
- Front-end CLI (unchanged from existing `vol`, extended):
  - `vol` → print percent; `vol 40` → set; `vol +5` / `vol -5` → relative
  - `vol mute [on|off|toggle]` → default `toggle`; `vol muted` → query
  - `bright` mirrors: `bright`, `bright 50`, `bright +10`, `bright -10`
- Scoring sketch: `vol.wpctl` 80 when `wpctl` exists and a PipeWire socket is
  live in `$XDG_RUNTIME_DIR`; `vol.pactl` 70 when `pactl` works; `vol.alsa`
  40 (last-ditch); platform providers (termux/powershell/macos) 70 on their
  platforms, 0 elsewhere. `bright.sysfs` 60 when `/sys/class/backlight/*`
  exists (device = largest `max_brightness`; write directly, else `sudo -n`,
  else fail so the dispatcher falls through); `bright.brightnessctl` 70 when
  installed (its logind path needs no sudo).
- `bin/brightness` (broken draft) is deleted in the same commit.

## 4. VT layer (vtcon)

`vtvol` / `vtbright` live in `sh/bin/` (tracked) and are symlinked into
`~/projects/vtcon/bin/` per vtcon's "map, not fork" rule.

1. **Seat gate** — proceed only when the seat's *active* session is a text
   VT: read `/sys/class/tty/tty0/active`, ask logind (`loginctl`) whether the
   active session is graphical; graphical/unknown → exit 0 silently.
   Chosen over inspecting the caller's own tty because tmux `run-shell`
   executes from the tmux *server* — the wrapper always sees a pts, so a
   naive `tty` check would never pass. Seat semantics also match the
   hardware nature of speakers/backlight (ssh callers adjust *this*
   machine while its console is on a VT — considered correct).
   Requirement (quote, 2026-07-06): "i'd prefer if these shortcuts did *not*
   fire (or at least, if the helper scripts didn't do anything) while i'm in
   a GUI / not in a VT".
2. **Delegate** — one `vol "$@"` / `bright "$@"` invocation; the toast text
   comes from the state it prints (mute toggles toast "Muted"/"Unmuted").
3. **Toast if configured** — when `lnotify` is on PATH *and* its daemon
   socket exists: `lnotify --group volume|brightness --timeout 1500 …`
   (`--group` collapses repeated presses into one updating toast). Absent or
   dead lnotify never breaks the keybinding.

## 5. Key wiring (libre; portable in principle)

- Console facts (verified 2026-07-06): media keys map to keycodes 113/114/115;
  the stock keymap gives 113=F13 (`\e[25~`), 114=F14 (`\e[26~`), 115=Help
  (emits nothing). Brightness Fn keys are keycodes ≥128, which the kernel
  console cannot map — hence volume on media keys, brightness on function
  keys (quote: "can we just use the standard volume keys and then some
  function keys?").
- One keymap line in vtcon `config/remap.inc` (→ `/etc/console-setup/remap.inc`):
  `keycode 115 = F15` so vol-up emits `\e[28~`. Reapply honoring the
  documented setupcon cache gotcha (touch `/etc/default/keyboard` first).
  Machine-level change → log in `/usr/share/CHANGELOG.md`.
- Tracked `.tmux.conf`: the dead pactl bindings are replaced by
  `F13/F14/F15` (no prefix) → `vtvol mute` / `vtvol -5` / `vtvol +5`, and
  `prefix+F8/F9` → `vtbright -10` / `vtbright +10`, each guarded with a
  `command -v vtvol` check so machines without vtcon stay inert. If tmux
  doesn't recognize F13–F15 through fbterm's terminfo, fall back to
  `user-keys[n]` bound to the raw CSI sequences (decide empirically).
- lnotify deployment on libre: install built binaries to `~/.local/bin`,
  `lnotifyd.service` systemd user unit, enabled.

## 6. Rollout order

portable layer → hand-test `vol`/`bright` → vt wrappers + symlinks → keymap →
tmux binds → lnotify wiring last (everything must work without it).

## 7. Decision log

- **Provider pattern over quick scripts** — Accepted. Context: multiple
  machines (libre, Termux, WSL, macOS exposure via existing vol backends);
  tracked configs must not depend on untracked helpers. Rationale: quoted in §1.
- **vtvol/vtbright as the only tmux-facing entry points** — Accepted.
  Rationale: quoted in §1 ("those wrappers are what we'd link to in the
  tracked .tmux.conf").
- **Seat-based VT gate (not caller-tty, not tmux `#{client_tty}`)** —
  Accepted. Context/rationale: §4; user: "love it and agree with your
  wrinkle recs".
- **Copy dispatcher per tool instead of shared provider.sh** — Accepted
  (YAGNI; don't destabilize clip). Revisit if a fourth provider family shows up.
- **lnotify integration lives in vt\* layer, optional at runtime** —
  Accepted. Rationale: portability quote in §2.
- **Earlier rejected shapes for the related "mpv on its own VT" task** (still
  open, distinct from this design): wrapper command, dedicated autologin
  movie VT, mpv Lua auto-respawn — see `~/TODO.md` VT-setup section,
  2026-07-06 exploration log.
