# VTui: `vtui-patch-font` + project rename/branding

Design for a single generalized fbterm font-patching CLI, plus renaming the
`vtcon` console setup to **VTui** and adopting a `vtui-` naming convention for
its setup-specific utilities.

Companion to the font-saga work in `~/projects/vtcon/README.md` and
`2026-07-06-unified-vol-bright-design.md`.

## 1. Motivation

The fbterm setup accumulated three font fixes discovered the hard way
(box-drawing seam, powerline separator slivers, box-junction vertical
misalignment), currently living in a Hasklug-specific one-off script
(`patch-fbterm-boxdrawing.py`). Goals:

- **Any monospace font, not just pre-built Nerd Fonts.** Quote (guy,
  2026-07-07): "i have a few fonts that work, but only because i'm using
  pre-built fonts because it was easier. if i could use any arbitrary mono
  font, i'd be way happier and probably switch it up :p plus i'm planning on
  sharing this setup once it's working and we've polished things."
- **Shareable.** The tool and the surrounding setup are meant to be published,
  so generality, honest dependencies, and clean UX matter more than for a
  personal script.

Target UX:

```
$ vtui-patch-font path/to/myfont.ttf
* adding powerline glyphs ... done
* fixing box-drawing seams ... done
* fixing powerline separators ... done
* aligning box junctions (exact @15px) ... done
* calculating fbterm-friendly sizes ... done

Patched font saved to myfont-VTui.ttf
FbTerm-friendly sizes: 8px, 12px, 16px*, 20px, 24px   (* recommended)
```

## 2. Pipeline

`vtui-patch-font <input-font> [--size N] [--nerd] [--verify] [-o OUT]` runs four
stages. Stages 1–2 are size-independent and robust; all fragility is quarantined
in stage 3.

1. **Add powerline/symbol glyphs (only if missing).** Delegate to an existing
   fontforge-based patcher — do not reinvent. Quote (guy): "i believe the
   powerline repo has a patch script? ... no need to rewrite that; just borrow
   it from the source (or add the source as a dependency)." Default:
   powerline/fontpatcher (adds exactly the E0Bx separators the tmux bar needs).
   `--nerd` routes through nerd-fonts font-patcher for the full icon set. Skip
   entirely if the input already carries the glyphs (Nerd Fonts do). This is the
   only stage needing **fontforge** (declared dependency; not yet installed —
   `apt install fontforge`).
2. **fbterm geometry fixes (pure fontTools, no fontforge):**
   - Box-drawing x-extents clamped to `[0, advance]` (kills the cell-boundary
     seam; size-independent).
   - Solid powerline separators affine-stretched onto U+2588's box (kills the
     undershoot slivers; size-independent).
3. **Box-junction alignment (size-coupled — see §3).**
4. **Ideal-size report (see §4).**

Output family gets a suffix (e.g. "<Name> VTui") so it coexists with the
original, exactly as the current "… FbTerm" family does; `~/.fbtermrc` lists the
patched family first.

## 3. Junction alignment

fbterm shoves any glyph whose ink overflows the cell TOP downward to fit it, so
up-stem box glyphs (`┼ ┴ ├ ┤ └ ┘`) render their bar low while plain-bar glyphs
(`─ ┬ ┌ ┐`) don't — horizontal rules step at every junction. The fix: shift the
no-up-stem bar glyphs DOWN to meet them. The shove magnitude depends on both
fbterm's cell-fit rule AND the font's box-glyph overflow, so it cannot be
hardcoded (measured 2px for Hasklug @ size 15).

**Approach: derive fbterm's placement rule from its source (fbterm 1.7, small,
open) into a formula** — given a font's box-glyph vertical metrics + a target
pixel size, compute the exact shove analytically. This keeps the tool
deterministic and portable (someone can patch a font on a laptop, no framebuffer
needed at patch time). Safety rails:

- `--verify`: when run on an fbterm machine, spin up the spare-VT harness
  (throwaway `fbterm` on a free VT → `vt-capture` → per-column bar-centroid),
  render a box grid, and print the residual px error. Auto-skips with a note
  where there's no framebuffer.
- Baked for `--size N` (default = top recommended size from §4). The report
  states plainly "junction-exact at Npx; other sizes get seam+powerline only."
- Fallback if the formula proves gnarly: self-calibration via the harness as the
  primary path, with 2px as a last-resort default.

## 4. Ideal-size calculator

fbterm needs an integral cell width or a dead column appears that no glyph can
fill (the font-saga lesson, generalized). Cell width = `size_px × advance/upm`,
so safe sizes are multiples of `upm / gcd(advance, upm)`, computed per font
(Hasklug 600/1000 → step 5 → 5/10/15/20/25; a 1024/2048 font → step 2 →
8/12/16/…). The tool prints these across a legible range (~8–32px), shows each
one's cell **W×H**, and stars a recommended pick (readability sweet spot
~14–18px on 1080p). Feeds stage 3's default `--size`.

## 5. Rename & naming convention

- **Project: `vtcon` → VTui.** Quote (guy): "i think i really like VTui as a
  name for this project." Rename `~/projects/vtcon` → `~/projects/vtui`, retitle
  the README, update live references. Dated CHANGELOG history stays as-is (it's
  a log).
- **`vtui-` prefix for setup-specific utilities; generic tools keep plain
  names.** Quote (guy): "rename some more of the utilities that are specific to
  this setup with the vtui- prefix ... BUT leave vol as vol (since it's generic
  -- not vtui specific)."
  - Rename: `vtvol`→`vtui-vol`, `vtbright`→`vtui-bright`,
    `fbterm-session`→`vtui-fbterm-session`, `fbterm-genbg`→`vtui-fbterm-genbg`
    (the latter two touch the boot chain: `~/.profile` exec, autologin drop-in,
    README map — guy: "i'm good to rename, too, for the consistent naming").
  - Keep plain: `vol`, `bright`, `clip*`, `lnotify`, `vt-capture` (generic
    VT-framebuffer capture, useful for debugging any console).
  - Update the tracked `.tmux.conf` binds (`vtvol`→`vtui-vol` etc.), guarded by
    `command -v` as now.

## 6. Homes & file layout

- `vtui-patch-font` + its fontTools fix module (and the fbterm-placement
  formula) live in `~/code/sh/bin` (+ `lib`), symlinked into `~/projects/vtui/bin`
  — same "map, not fork" pattern as the other utilities.
- The current `patch-fbterm-boxdrawing.py` logic folds into the tool. Quote
  (guy): "i would just retire the old script after validating the new one
  works." So: build, validate parity via the harness, THEN delete the old
  script (and its dotfiles symlink).

## 7. Overview README

New ask (guy): a README listing VTui's shape and components. Structure: the boot
chain (already in the current README) + a component map, each a one-liner + real
location:

- session: `vtui-fbterm-session`, `vtui-fbterm-genbg`
- shell: `~/.profile` gating, `~/.fbtermrc`, tmux config
- keys/feedback: `vtui-vol`, `vtui-bright`, `lnotify`/`lnotifyd`
- utilities: `vt-capture`, `vtui-patch-font`
- generic building blocks it leans on: `vol`, `bright`, `clip`

## 8. Rollout

fontforge install → build `vtui-patch-font` (stages 2+4 first, pure fontTools) →
derive fbterm formula for stage 3 → wire stage 1 (powerline patcher) → validate
against the current font via the harness (parity) → retire old script → do the
rename + `vtui-` sweep (utilities, tmux binds, boot chain, README) → write the
overview README.

## 9. Decision log

- **Generalize to arbitrary mono fonts + share it** — Accepted. Rationale
  quoted §1. Raises the bar on dependencies/UX/robustness.
- **Borrow an existing powerline patcher (fontforge), don't reinvent** —
  Accepted. Rationale quoted §2. fontforge becomes a declared dep.
- **Derive fbterm's placement formula for the junction fix** rather than
  hardcode 2px or always self-calibrate — Accepted. Portability for a shared
  tool (§3); self-calibration demoted to an optional `--verify`.
- **`vtui-` prefix for setup-specific tools, plain names for generic ones** —
  Accepted. Rationale quoted §5.
- **Retire the old script only after harness-verified parity** — Accepted.
  Rationale quoted §6.
