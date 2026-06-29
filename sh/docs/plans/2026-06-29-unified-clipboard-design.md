# Unified Cross-Platform Clipboard System — Design

- **Date:** 2026-06-29
- **Status:** Design accepted; ready for implementation planning
- **Scope:** `~/code` (shared across all machines: macOS, WSL, Termux/Android, Linux + any WM/clipboard)

## 1. Motivation

Two machine-specific clipboard bugs exposed that today's clip tooling is
hand-written per machine (`~/bin/clipin` is `cat | gpaste-client` on one box,
`clip.exe "$@"` on another) with no shared, platform-aware implementation:

- **libre.sh (GNOME/Wayland):** micro froze ~30–50s on startup. Root cause:
  micro's default `clipboard: external` runs `wl-paste` on launch; on
  GNOME/Mutter (no `wlr-data-control`) `wl-paste` blocks in `do_sys_poll` on the
  Wayland socket waiting for Mutter to deliver the selection. gpaste's **D-Bus**
  path (`gpaste-client`) is always instant; the **Wayland** path intermittently
  stalls. (`clipin`/`clipout` use D-Bus, so they never hung.)
- **smitchell-pc (WSL2/WSLg):** opening micro **wiped** the Windows clipboard.
  Root cause: `~/bin/xclip` was `clipin.exe <&0` — it ignored `-out` and turned
  every *read* into an empty *write* (`Set-Clipboard ''`). micro reads the
  clipboard on startup via `xclip -out` → clipboard cleared.

Both are the same shape: *micro reads the clipboard on startup, and the read
path was broken/slow*. The per-machine fixes (micro→`terminal` on libre; a
corrected `xclip` dispatcher on WSL) work but don't persist or propagate. This
design replaces the ad-hoc tooling with one shared, self-describing system.

## 2. Goals / Non-goals

**Goals**
- One set of clipboard commands that behave identically on every machine.
- Plain-text always works (guaranteed floor); rich-text/HTML/markdown/image are
  optional, feature-detected, and degrade with a helpful error.
- New platforms/backends added by **dropping in a file**, never editing core.
- Third-party tools that call standard names (`xclip`, `pbcopy`, …) work too.

**Non-goals**
- Reimplementing a clipboard manager (gpaste, Windows clipboard, etc. stay).
- Per-machine config files for capability discovery (we use convention instead).

## 3. Architecture

Two layers plus drop-in providers.

**Front-end commands** (user-facing, byte-identical everywhere, *zero* platform
logic — they parse intent and delegate):

- `clipout` — *"does not care about args, params, or stdin — just pastes the
  clipboard."* Strict **text-only**.
- `clipin` — `echo foo | clipin` **or** `clipin "hello world"` — copies to the
  clipboard.
- `clipinout` — thin `clipin "$@" && clipout`. Nothing more; if it needs more,
  fix `clipin`/`clipout`.
- `clip` — *"a smarter combo… if stdin, then behaves as `clipin`, else behaves
  as `clipout`."* Also owns content-type DWIM (see §6).

**Dispatcher** (shared engine, source-only → lives in bash-libs):

- Input: operation (`get`/`set`) + type (`plain`/`rich`/`image`).
- Enumerates providers, keeps those that are compatible **and** implement the
  requested capability, invokes the **highest-fitness** survivor.

**Providers** (`clip.<tags>`, self-registering backends, drop-in):

- Small executables; often one-liners; frequently shared across machines.
- Each owns its own compatibility verdict and capability set.

## 4. Capability tiers

- **Tier 1 — primitives, always work (plain text).** The guaranteed floor.
- **Tier 2 — optional capabilities, feature-detected (rich/HTML/markdown/image).**
  Purely additive. `clipout --format markdown` →
  - if a provider offers `get:rich` on this machine → require `pandoc` (error if
    missing) → convert;
  - else → *"print an error that rich text clipboard funsies are not setup on
    this machine with a hint how to do so."*

Graceful degradation is a first-class feature, not an afterthought.

## 5. Provider contract

Each provider `clip.<tags>` (e.g. `clip.gpaste`, `clip.wl`, `clip.xsel`,
`clip.wsl`, `clip.macos`, `clip.termux`) is an executable answering a tiny
subcommand protocol, so it is independently runnable/testable by hand
(`clip.gpaste get plain`):

- **`clip.<tags> probe`** — self-registration. Emits a **fitness score**
  (integer; `0`/no output = "not me") **and** the capabilities it offers, in one
  shot:
  ```
  score 70
  caps  get:plain set:plain
  ```
  This is where each provider's nuanced self-knowledge lives. Examples:
  - `clip.gpaste` scores high on GNOME (fast D-Bus), offers `get:plain set:plain`.
  - `clip.wl` scores **low on GNOME/Mutter** (the Wayland selection stalls) but
    **high on wlroots/sway**, and may offer `get:rich`.
  - So on libre, `plain` resolves to gpaste while `rich` resolves to wl — *on the
    same machine*.
- **`clip.<tags> get <plain|rich|image>`** — emit that representation to stdout.
- **`clip.<tags> set <plain|rich|image>`** — read stdin into the clipboard.

**Enumeration:** `compgen -c 'clip.' | sort -u`. The dot namespaces providers
away from the front-end `clip`/`clipin`/`clipout` (no dot), so this lists exactly
the providers, PATH-aware, no manual dir globbing.

## 6. Dispatch, tie-breaking, defaults

**Dispatcher** (one probe-fork per provider for discovery, one for the op):
```bash
best= bestscore=0
while read -r p; do
  read -r score caps < <("$p" probe 2>/dev/null)   # parse "score N" / "caps ..."
  (( score > bestscore )) && caps_has "$caps" "$op:$type" \
    && { best=$p; bestscore=$score; }
done < <(compgen -c 'clip.' | sort -u)
[[ $best ]] && exec "$best" "$op" "$type" || die_with_hint "$op" "$type"
```

**Tie-breaking — Option C, self-rated fitness.** When several providers are
compatible *and* implement the capability (on libre, both gpaste and wl offer
`get:plain`), the **higher `probe` score wins**. Each provider rates itself,
encoding platform nuance (gpaste high on GNOME; wl low on Mutter). Conditions
live in the provider — *"each could register when it should be used vs the core
thing having to be updated constantly with conditions."*

**Default format (no `--format`)** — emit the most universally consumable
representation = **plaintext**:
- Rich text, no format → emit the **plaintext fallback** (keeps `clipout | grep`,
  `x=$(clipout)`, `clipout > f.txt` predictable). Rich is opt-in via `--format`.
- **Image-only, no text representation** → **strict `clipout`** prints nothing to
  stdout, writes a stderr notice + nonzero exit:
  `clipboard holds a PNG (1920x1080); use `clipout --image``. Never spews binary
  into a pipe or `$(...)`.
- Content-type **DWIM lives in `clip`** (the smart one), not `clipout`: text →
  print; image → raw bytes if stdout is redirected, else the friendly hint.

Re-probing every call is a few cheap forks; add a per-host cache only if it ever
matters (YAGNI).

## 7. Standard-name shims (third-party tools)

Tools call `xclip`/`xsel`/`wl-copy`/`wl-paste`/`pbcopy`/`pbpaste`, not our suite
(micro calls `xclip`). Ship **thin shims** in `~/code/sh/bin/` that translate the
dialect into the suite:

- `xclip -o`/`-out` → `clipout`; `xclip -i`/default → `clipin` (the exact bug we
  fixed on WSL, now correct everywhere by construction).
- `wl-paste`/`pbpaste` → `clipout`; `wl-copy`/`pbcopy` → `clipin`; etc.

**Real-binary resolution** (avoid the shim shadowing/recursing onto itself):
mirror the `git` wrapper pattern — enumerate PATH candidates (`compgen`/`type
-a`) and exclude our shim, with **per-tool tunable checks**:
- *is it a text file?* (our shims are scripts; real `xclip` is an ELF binary)
- *is it under `$HOME`?* (ours live in `~/code`; system ones don't)

Tune per tool by what we know about it:
- `git` — always a binary, never home-compiled → require **both** (not-text **and**
  not-home).
- `python` under pyenv — always a binary but **may** live in `$HOME` → check
  **binary only**, ignore path.
- A tool that could be text *or* binary → ignore filetype, check **path only**.

(Consult the `git-wrapper-system` skill for the exact idiom.)

## 8. Layout & PATH

`~/.path` adds every `~/code/*/bin/` to `$PATH`, so `compgen -c 'clip.'` finds
providers in any topic dir.

- `~/code/sh/lib/clip.sh` — dispatcher + shared helpers. **Source-only →
  `lib/`**, and `sh/lib` is the **`bash-libs` submodule**. *"the dispatcher can
  live in bash-libs if it's source-only. that's where it belongs. i'd prioritize
  maintaining my current organizational rules."* May read-only source existing
  helpers (`wsl.sh`, `colors.sh`, `debug.sh`).
- `~/code/sh/bin/{clipin,clipout,clipinout,clip}` — thin executables that source
  the lib (+x → `bin/`).
- `~/code/sh/bin/{xclip,xsel,wl-copy,wl-paste,pbcopy,pbpaste}` — name-shims.
- Providers (executables, +x → `bin/`):
  - `~/code/sh/bin/clip.gpaste`, `clip.wl`, `clip.xsel`, `clip.termux` (anywhere-bash)
  - `~/code/wsl/bin/clip.wsl` (may be PowerShell via `psrun` shebang; folds in the
    existing `clip.exe`/`clipin.exe`/`clipout.exe` rich/image logic)
  - `~/code/macos/bin/clip.macos` (**new topic dir**; basic `pbcopy`/`pbpaste`)

Convention: `bin/` = executable (source-or-exec OK with +x); `lib/` = only-ever-
sourced.

## 9. Submodule workflow (sh/lib = bash-libs)

When the dispatcher (or any `sh/lib` file) changes:
1. Commit + push **inside** `~/code/sh/lib` (branch `dev`, remote
   `shitchell/bash-libs.git`).
2. Bump the submodule pointer in `~/code` and commit that.

The design doc and `bin/` providers/shims are in the `~/code` repo proper (not the
submodule).

## 10. micro realignment

Once the suite + shims exist, *"firmly update how micro works."* Options at impl
time: revert micro to `clipboard: external` and rely on the now-correct,
gpaste-preferring `xclip`/`wl-paste` shims, **or** keep `clipboard: terminal`.
Decide per the shim behavior we end up with.

## 11. Testing

- **Round-trip per type:** `printf X | clipin; [[ "$(clipout)" == X ]]` for plain
  (and rich/image where supported). Reuse/extend `~/code/wsl/bin/test-clipboard.sh`.
- **Provider probe:** each `clip.<tags> probe` emits a parseable `score`/`caps`;
  `is_compatible` returns sane scores per platform.
- **Dispatch selection:** on a machine with multiple compatible providers, assert
  the expected one wins per type (libre: plain→gpaste).
- **Shim translation:** `xclip -out` reads (does **not** clear), `xclip -i`
  writes; `pbpaste`/`wl-paste` map to `clipout`; real-binary finder excludes the
  shim.
- **Degradation:** `clipout --format markdown` with no rich provider → nonzero +
  hint, not a crash.

## 12. Open items / future

- Per-host probe cache (only if forks ever matter).
- READMEs: `~/code` (topic-dir + bin/lib conventions), `~/code/sh` ("works
  anywhere bash/sh runs"). (Flagged for retrospective.)
- Memory entry for the clipboard architecture + conventions. (Flagged for
  retrospective.)
- Optional libre system-level mitigation: restart the long-running
  `gpaste-daemon` and/or investigate the Mutter Wayland-selection stall.

## Appendix — decisions & rationale

- **Two-tier (guaranteed plaintext + optional rich/image).** Accepted. Rationale:
  primitives must *"always work"*; rich text *"depends on the clipboard allowing
  access to rich text (which not all do; i believe gpaste is an example)."*
- **Self-registering providers with `is_compatible()`.** Accepted. Rationale:
  *"each could register when it should be used vs the core thing having to be
  updated constantly with conditions."*
- **Per-operation selection; multiple providers may be compatible.** Accepted.
  *"multiple providers might be compatible… the gpaste one wouldn't be able to
  offer a rich text function while the wl-copy one might."*
- **Tie-break by self-rated fitness (Option C).** Accepted ("i can dig C").
- **Strict `clipout`; image DWIM in `clip` (Option #1).** Accepted ("let's do #1").
- **Provider naming `clip.<tags>`, enumerate via `compgen`.** Accepted.
- **Dispatcher in bash-libs submodule (source-only).** Accepted; prioritizes
  existing org rules over avoiding the submodule dance.
- **Ship thin name-shims; per-tool tunable real-binary checks.** Accepted.
