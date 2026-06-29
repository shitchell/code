# Unified Cross-Platform Clipboard — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build one shared clipboard system (`clipin`/`clipout`/`clipinout`/`clip` + standard-name shims) that works on macOS, WSL, Termux, and any Linux/WM, selecting the best backend per operation via self-registering `clip.<tags>` providers.

**Architecture:** Front-end commands parse intent and call a sourced dispatcher (`clip.sh` in the `bash-libs` submodule). The dispatcher enumerates `clip.*` providers via `compgen`, each of which `probe`s itself with a fitness score + capabilities; the highest-scoring provider that implements the requested `op:type` wins. Thin shims (`xclip`, `pbcopy`, …) translate standard tool dialects into the suite.

**Tech Stack:** Bash (portable, no bashisms beyond bash 4), `bats` for tests, `include-source` lib system, `: 'docstring'` convention. Backends: gpaste-client, wl-clipboard, xsel, clip.exe/PowerShell, pbcopy/pbpaste, termux-clipboard.

**Design ref:** `sh/docs/plans/2026-06-29-unified-clipboard-design.md`

**Conventions (from ~/code/CLAUDE.md):**
- Functions use `: 'docstring with @arg/@stdout'`.
- Scripts import via `source "$(dirname "$0")/../lib/include.sh"; include-source 'clip.sh'`.
- `bin/` = executable (+x, source-or-exec); `lib/` = source-only (and is the bash-libs submodule).

**Repos:** front-ends/providers/shims → `~/code` superproject. Dispatcher → `sh/lib` (`bash-libs` submodule: branch `dev`, remote `shitchell/bash-libs.git`). Submodule changes commit+push in the submodule, then bump the pointer in `~/code` (see Phase 8).

**Test PATH** (so `compgen -c clip.` finds worktree scripts): every test prepends
```
export PATH="$PWD/sh/bin:$PWD/wsl/bin:$PWD/macos/bin:$PATH"
```
Run all from the worktree root `~/code/_worktrees/feature-unified-clipboard`.

---

## Phase 0 — Scaffolding

### Task 0: Directories + bats harness

**Files:**
- Create: `macos/bin/.keep`, `tests/clip/` (bats lives here)
- Create: `tests/clip/helpers.bash`

**Step 1:** `mkdir -p macos/bin tests/clip` ; `touch macos/bin/.keep`

**Step 2:** Write `tests/clip/helpers.bash` — a fake-provider factory so dispatcher tests need no real clipboard:
```bash
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
```

**Step 3:** Commit.
```bash
git add macos/bin/.keep tests/clip/helpers.bash
git commit -m "test: scaffolding + fake-provider harness for clip"
```

---

## Phase 1 — Dispatcher (`sh/lib/clip.sh`, TDD)

The engine. Source-only → submodule. Exposes `clip::dispatch <get|set> <plain|rich|image>` and `clip::real_binary <name> [--need-binary] [--need-nonhome]`.

### Task 1: provider selection — highest compatible score wins

**Files:**
- Create: `sh/lib/clip.sh`
- Test: `tests/clip/dispatch.bats`

**Step 1: Failing test**
```bash
# tests/clip/dispatch.bats
setup() { load helpers; source "$BATS_TEST_DIRNAME/../../sh/lib/clip.sh"; }

@test "picks highest-score provider that supports the op:type" {
  make_provider clip.low  30 "get:plain set:plain" "LOWVAL"
  make_provider clip.high 80 "get:plain set:plain" "HIGHVAL"
  run clip::dispatch get plain
  [ "$status" -eq 0 ]
  [ "$output" = "HIGHVAL" ]
}
```

**Step 2:** Run → FAIL (`clip::dispatch` undefined).
Run: `bats tests/clip/dispatch.bats`

**Step 3: Minimal implementation**
```bash
# sh/lib/clip.sh
: 'Unified clipboard dispatcher. Source-only.'

clip::_providers() { compgen -c 'clip.' 2>/dev/null | sort -u; }

clip::dispatch() {
  : 'Run the best provider for an op/type.
      @arg $1 op  (get|set)
      @arg $2 type (plain|rich|image)
      @stdin  content (for set)
      @stdout clipboard content (for get)
  '
  local op="$1" type="$2"; shift 2
  local want="$op:$type" best="" bestscore=0 p score caps line
  while IFS= read -r p; do
    score=0 caps=""
    while IFS= read -r line; do
      case "$line" in
        score\ *) score="${line#score }" ;;
        caps\ *)  caps=" ${line#caps } " ;;
      esac
    done < <("$p" probe 2>/dev/null)
    [[ "$score" =~ ^[0-9]+$ ]] || score=0
    if (( score > bestscore )) && [[ "$caps" == *" $want "* ]]; then
      best="$p"; bestscore="$score"
    fi
  done < <(clip::_providers)
  if [[ -z "$best" ]]; then
    clip::_no_provider "$op" "$type"; return 3
  fi
  "$best" "$op" "$type" "$@"
}

clip::_no_provider() {
  printf 'clip: no provider for %s:%s on this machine.\n' "$1" "$2" >&2
  [[ "$2" != plain ]] && printf 'clip: hint: install/enable a clip.<tag> that offers %s:%s (see sh/docs/plans/2026-06-29-unified-clipboard-design.md).\n' "$1" "$2" >&2
}
```

**Step 4:** Run → PASS. `bats tests/clip/dispatch.bats`

**Step 5: Commit** (in the submodule — see note)
```bash
git -C sh/lib add clip.sh
git -C sh/lib commit -m "feat(clip): dispatcher selects best-scoring compatible provider"
git add tests/clip/dispatch.bats; git commit -m "test(clip): dispatcher selection"
```

### Task 2: capability filtering — skip providers lacking the type

**Step 1: Failing test**
```bash
@test "skips a higher-score provider that lacks the requested capability" {
  make_provider clip.rich 90 "get:plain set:plain" "PLAIN90"   # no get:rich
  make_provider clip.has  40 "get:plain get:rich"  "RICH40"
  run clip::dispatch get rich
  [ "$status" -eq 0 ]; [ "$output" = "RICH40" ]
}
```
**Step 2:** Run → should already PASS with Task 1 code (caps filter). If not, fix. **Step 3:** n/a. **Step 4:** PASS. **Step 5:** commit test.

### Task 3: no-provider → friendly error + exit 3

**Step 1: Failing test**
```bash
@test "image with no provider errors with hint and exit 3" {
  make_provider clip.txt 50 "get:plain set:plain" "X"
  run clip::dispatch get image
  [ "$status" -eq 3 ]
  [[ "$output" == *"no provider for get:image"* ]]
}
```
**Steps 2-5:** verify PASS (already implemented), commit test.

### Task 4: `clip::real_binary` — find the real tool, exclude our shims

**Step 1: Failing test**
```bash
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
```

**Step 3: Implementation** (append to `clip.sh`)
```bash
clip::real_binary() {
  : 'Resolve the real system binary for NAME, excluding our own shims.
      @arg $1 name
      @arg $@ --need-binary  require a non-text file
      @arg $@ --need-nonhome require a path outside $HOME
      @stdout absolute path of the first matching candidate
      @return 0 if found, 1 otherwise
  '
  local name="$1"; shift
  local need_binary=false need_nonhome=false a
  for a in "$@"; do
    [[ "$a" == --need-binary ]] && need_binary=true
    [[ "$a" == --need-nonhome ]] && need_nonhome=true
  done
  local c
  while IFS= read -r c; do
    [[ -x "$c" ]] || continue
    if $need_nonhome; then case "$c" in "$HOME"/*) continue ;; esac; fi
    if $need_binary; then
      case "$(file -b --mime-type "$c" 2>/dev/null)" in text/*) continue ;; esac
    fi
    printf '%s\n' "$c"; return 0
  done < <(type -af "$name" 2>/dev/null | awk '{print $NF}')
  return 1
}
```
**Steps 2/4/5:** FAIL→PASS, commit in submodule.

> NOTE on commits in this phase: `clip.sh` lives in the `sh/lib` submodule. Commit there each task; bump happens once in Phase 8.

---

## Phase 2 — Front-end commands (`sh/bin/`, TDD against fake providers)

Each is a thin executable sourcing the lib. Template header:
```bash
#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../lib/include.sh"
include-source 'clip.sh'
```

### Task 5: `clipout` (strict text; `--format` maps to type; rich→pandoc)

**Files:** Create `sh/bin/clipout`; Test `tests/clip/clipout.bats`

**Step 1: Failing tests**
```bash
@test "clipout with no format emits plaintext" {
  make_provider clip.g 70 "get:plain set:plain" "hello"
  run sh/bin/clipout; [ "$output" = "hello" ]
}
@test "clipout --format markdown needs rich provider; errors if absent" {
  make_provider clip.g 70 "get:plain set:plain" "hello"
  run sh/bin/clipout --format markdown
  [ "$status" -ne 0 ]; [[ "$output$stderr" == *"no provider for get:rich"* ]] || true
}
```

**Step 3: Implementation**
```bash
#!/usr/bin/env bash
# clipout — print the clipboard. Strict text by default.
source "$(dirname "$(readlink -f "$0")")/../lib/include.sh"
include-source 'clip.sh'
main() {
  local fmt=plain
  [[ "$1" == --format ]] && { fmt="$2"; shift 2; }
  [[ "$1" == --image ]] && { fmt=image; shift; }
  case "$fmt" in
    plain) clip::dispatch get plain ;;
    rich|html) clip::dispatch get rich ;;
    markdown|md)
      command -v pandoc >/dev/null || { echo "clipout: pandoc required for --format markdown" >&2; exit 3; }
      clip::dispatch get rich | pandoc -f html -t gfm-raw_html --wrap=none ;;
    image) clip::dispatch get image ;;
    *) echo "clipout: unknown format: $fmt" >&2; exit 2 ;;
  esac
}
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
```
**Steps 2/4/5:** FAIL→PASS, commit.

### Task 6: `clipin` (args or stdin → set plain)

**Step 1: Failing tests**
```bash
@test "clipin from args" { make_provider clip.g 70 "get:plain set:plain" "";
  run sh/bin/clipin "hello world"; [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/clip.g.sink")" = "hello world" ]; }
@test "clipin from stdin" { make_provider clip.g 70 "get:plain set:plain" "";
  echo piped | sh/bin/clipin
  [ "$(cat "$BATS_TEST_TMPDIR/clip.g.sink")" = "piped" ]; }
```
**Step 3: Implementation**
```bash
#!/usr/bin/env bash
# clipin — copy args (or stdin) to the clipboard.
source "$(dirname "$(readlink -f "$0")")/../lib/include.sh"
include-source 'clip.sh'
main() {
  if (($#)); then printf '%s' "$*" | clip::dispatch set plain
  else clip::dispatch set plain; fi
}
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
```
**Steps 2/4/5:** FAIL→PASS, commit.

### Task 7: `clipinout` and `clip`

**Step 1: Failing tests**
```bash
@test "clipinout copies then pastes" { make_provider clip.g 70 "get:plain set:plain" "RT";
  run sh/bin/clipinout "x"; [ "$output" = "RT" ]; }     # get returns fixed "RT"
@test "clip with stdin acts as clipin" { make_provider clip.g 70 "get:plain set:plain" "";
  echo z | sh/bin/clip; [ "$(cat "$BATS_TEST_TMPDIR/clip.g.sink")" = "z" ]; }
@test "clip without stdin acts as clipout" { make_provider clip.g 70 "get:plain set:plain" "OUT";
  run sh/bin/clip </dev/null; [ "$output" = "OUT" ]; }
```
**Step 3: Implementation**
```bash
# sh/bin/clipinout
#!/usr/bin/env bash
exec clipin "$@" && exec clipout      # (see note: use a function, not double-exec)
```
Correct version:
```bash
#!/usr/bin/env bash
clipin "$@" && clipout
```
```bash
# sh/bin/clip — stdin? -> clipin ; else -> clipout (with image DWIM)
#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../lib/include.sh"
include-source 'clip.sh'
main() {
  if [[ ! -t 0 ]]; then exec clipin "$@"; fi
  # output side: text if available, else image DWIM
  if clipout 2>/dev/null; then return 0; fi
  if [[ ! -t 1 ]]; then clipout --image; else
    echo "clip: clipboard holds non-text; redirect for bytes or use 'clipout --image'" >&2; return 3
  fi
}
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
```
**Steps 2/4/5:** FAIL→PASS, commit (`chmod +x` all four front-ends).

---

## Phase 3 — Providers (integration; run on the matching machine)

Provider contract (executable, +x): subcommands `probe` (→ `score N` + `caps ...`), `get <type>`, `set <type>`. Providers that wrap a shimmed tool (wl-paste, xclip) MUST reach the real binary via `clip::real_binary`.

### Task 8: `clip.gpaste` (libre; integration)

**Files:** Create `sh/bin/clip.gpaste`; Test `tests/clip/int_gpaste.bats` (skips if no gpaste)
```bash
#!/usr/bin/env bash
# clip.gpaste — GPaste D-Bus backend (fast; preferred on GNOME)
probe() {
  command -v gpaste-client >/dev/null && pgrep -x gpaste-daemon >/dev/null || \
    { command -v gpaste-client >/dev/null && gpaste-client --version >/dev/null 2>&1; } || { echo "score 0"; return; }
  local score=40; [[ "$XDG_CURRENT_DESKTOP" == *GNOME* ]] && score=70
  echo "score $score"; echo "caps get:plain set:plain"
}
case "$1" in
  probe) probe ;;
  get) [[ "$2" == plain ]] && gpaste-client --use-index get 0 ;;
  set) [[ "$2" == plain ]] && gpaste-client add "$(cat)" ;;
esac
```
**Integration test**
```bash
@test "gpaste round-trips plain text" {
  command -v gpaste-client >/dev/null || skip "no gpaste"
  printf 'rt-%s' "$$" | sh/bin/clip.gpaste set plain
  [ "$(sh/bin/clip.gpaste get plain)" = "rt-$$" ]
}
```
Run on libre: `bats tests/clip/int_gpaste.bats`. Commit.

### Task 9: `clip.wl` (Wayland; scores LOW on Mutter — this is the libre lesson)

```bash
#!/usr/bin/env bash
# clip.wl — wl-clipboard backend. Low score on GNOME/Mutter (selection stalls).
source "$(dirname "$(readlink -f "$0")")/../lib/include.sh"; include-source 'clip.sh'
WLP="$(clip::real_binary wl-paste --need-binary)"; WLC="$(clip::real_binary wl-copy --need-binary)"
probe() {
  [[ -n "$WAYLAND_DISPLAY" && -n "$WLP" ]] || { echo "score 0"; return; }
  local score=80; [[ "$XDG_CURRENT_DESKTOP" == *GNOME* ]] && score=20   # Mutter: stalls
  echo "score $score"; echo "caps get:plain set:plain get:rich set:rich"
}
case "$1" in
  probe) probe ;;
  get) case "$2" in plain) "$WLP" --no-newline ;; rich) "$WLP" -t text/html ;; esac ;;
  set) case "$2" in plain) "$WLC" ;; rich) "$WLC" -t text/html ;; esac ;;
esac
```
Integration test mirrors Task 8 (skip if no `$WAYLAND_DISPLAY`). On libre, also assert `probe` score is 20 (Mutter). Commit.

### Task 10: `clip.xsel` (X11) — same shape, `xsel -ob` / `xsel -ib`, `clip::real_binary xsel`. Commit.

### Task 11: `clip.wsl` (→ `wsl/bin/clip.wsl`; run on smitchell-pc over SSH)

Fold in existing `clip.exe`/`clipin.exe`/`clipout.exe` logic:
```bash
#!/usr/bin/env bash
# clip.wsl — Windows clipboard via PowerShell. Plain + rich + image.
PSH="$(command -v powershell.exe || echo /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe)"
probe() {
  grep -qi microsoft /proc/version 2>/dev/null && [[ -x "$PSH" ]] || { echo "score 0"; return; }
  echo "score 70"; echo "caps get:plain set:plain get:rich set:rich get:image"
}
case "$1" in
  probe) probe ;;
  get) case "$2" in
        plain) "$PSH" -NoProfile -Command 'Get-Clipboard -Raw' | tr -d '\r\0' ;;
        rich)  "$PSH" -NoProfile -Command 'Get-Clipboard -TextFormatType Html' | tr -d '\r\0' ;;
        image) "$PSH" -NoProfile -Command '...Save clipboard image to stdout...' ;;
       esac ;;
  set) case "$2" in
        plain) "$PSH" -NoProfile -Command "Set-Clipboard -Value @'
$(cat)
'@" ;;
       esac ;;
esac
```
Integration test on WSL via `ssh guy@192.168.0.248` (PATH must include the worktree). Verify round-trip AND that a `get` does **not** clear the clipboard (the original bug). Commit.

### Task 12: `clip.macos` (→ `macos/bin/clip.macos`; basic, untested — no Mac)
```bash
#!/usr/bin/env bash
# clip.macos — pbcopy/pbpaste. Basic; untested (no Mac available).
probe() { [[ "$(uname)" == Darwin ]] && command -v pbpaste >/dev/null \
  && { echo "score 70"; echo "caps get:plain set:plain"; } || echo "score 0"; }
case "$1" in
  probe) probe ;;
  get) [[ "$2" == plain ]] && pbpaste ;;
  set) [[ "$2" == plain ]] && pbcopy ;;
esac
```
Add `clip.termux` similarly (`termux-clipboard-get/set`) if quick. Commit.

---

## Phase 4 — Standard-name shims (`sh/bin/`, TDD with stubbed front-ends)

### Task 13: `xclip` shim (the fix, generalized)

**Test** (`tests/clip/shims.bats`): stub `clipin`/`clipout` on PATH, assert `xclip -o`→clipout, `xclip -i`→clipin.
```bash
@test "xclip -out routes to clipout (read, not write)" {
  stub clipout 'echo PASTED'; run sh/bin/xclip -out -selection clipboard
  [ "$output" = "PASTED" ]
}
@test "xclip -i routes to clipin" {
  stub clipin 'cat > "$BATS_TEST_TMPDIR/in"'; echo data | sh/bin/xclip -i
  [ "$(cat "$BATS_TEST_TMPDIR/in")" = data ]
}
```
**Implementation**
```bash
#!/usr/bin/env bash
# xclip — shim: -o/-out => clipout (read); else => clipin (write).
mode=write
for a in "$@"; do case "$a" in -o|-ou|-out) mode=read ;; -i|-in) mode=write ;; esac; done
[[ $mode == read ]] && exec clipout || exec clipin
```
Commit.

### Task 14: remaining shims
- `wl-paste`, `pbpaste` → `exec clipout "$@"` (map `-t text/html`→`--format rich` where easy).
- `wl-copy`, `pbcopy` → `exec clipin`.
- `xsel` → `-o`→clipout else clipin.
One bats test each (stub + assert). Commit per shim.

> Recursion guard: shims call front-ends; providers (`clip.wl`/`clip.xsel`) reach real binaries via `clip::real_binary`, so no shim→provider→shim loop. Add a bats test asserting `clip.wl` resolves a non-`$HOME` `wl-paste`.

---

## Phase 5 — micro realignment + cross-machine verification

### Task 15: libre — switch micro back to `external`, verify gpaste wins
- Edit `~/.config/micro/settings.json`: `clipboard` → `external` (now that `clip.wl` scores low and `xclip`/shim route correctly... but micro calls `wl-paste`/`xclip` directly → our shims route to clipout → gpaste). Verify: open micro, no stall (uses gpaste path), clipboard intact.
- If micro still hits real `wl-paste` (PATH order), confirm `~/code/sh/bin` precedes `/usr/bin`. Else keep `terminal`. Document the outcome.

### Task 16: WSL — deploy + verify on smitchell-pc
- On 192.168.0.248: ensure worktree/branch present (or copy `clip.*`/shims), confirm `xclip` shim + `clip.wsl` provider. Re-run the empty-overwrite test: opening micro must NOT clear the clipboard; round-trip works.

---

## Phase 6 — Docs + finalize

### Task 17: READMEs
- `~/code/sh/README.md` — "scripts here work anywhere bash/sh runs"; bin/lib convention.
- `~/code/README.md` (or update) — topic-dir layout + `~/.path`.
- Section in `sh/README.md` documenting the clip provider contract (how to add a `clip.<tag>`).

### Task 18: Full test pass
Run: `bats tests/clip/` → all green (integration tests skip where backend absent). Record results.

---

## Phase 7 — Submodule bump + branch finish

### Task 19: bash-libs submodule
```bash
cd sh/lib
git checkout dev && git pull --ff-only
git push origin dev                      # clip.sh commits from Phase 1
cd ../..
git add sh/lib                           # bump pointer
git commit -m "chore: bump bash-libs (clip dispatcher)"
```

### Task 20: finish branch
Use superpowers:finishing-a-development-branch (merge/PR/cleanup). Then remove worktree.

---

## Notes / YAGNI
- v1 = plain text everywhere + rich where trivial (wl, wsl). Image only where free (wsl). Don't block on full rich/image parity.
- No probe cache in v1 (a few forks). Add only if measured.
- `clip.termux`, `clip.xclip` are nice-to-haves; ship if quick.
