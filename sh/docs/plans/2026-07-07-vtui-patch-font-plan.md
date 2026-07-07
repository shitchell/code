# vtui-patch-font Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build `vtui-patch-font`, a single self-contained Python CLI that turns any monospace font into an fbterm-ready font (add powerline glyphs, fix box-drawing seams + powerline slivers + box-junction alignment, report fbterm-friendly sizes), then rename the `vtcon` setup to VTui with a `vtui-` utility prefix.

**Architecture:** One shareable Python file at `~/code/python/bin/vtui-patch-font` with pure-`fontTools` geometry stages (testable in isolation) plus a `fontforge` subprocess stage for adding glyphs. Junction alignment uses a shove amount derived from fbterm's source, unit-anchored to our measured ground truth (2px @ size 15 on Hasklug) and optionally cross-checked with a spare-VT render harness. Symlinked into `~/projects/vtui/bin` per the "map, not fork" convention.

**Tech Stack:** Python 3, fontTools (RecordingPen/T2CharStringPen/BoundsPen/TTGlyphPen), fontforge (subprocess, for glyph-add), powerline/fontpatcher (vendored), pytest, the spare-VT harness (openvt + fbterm + vt-capture + Pillow).

**Conventions:**
- Tool: `~/code/python/bin/vtui-patch-font` (executable, no extension, `#!/usr/bin/env python3`).
- Tests: `~/code/python/tests/test_vtui_patch_font.py`, loaded via `importlib.util` (single-file tool).
- Run tests: `cd ~/code/python && python3 -m pytest tests/test_vtui_patch_font.py -v`
- Fixtures: stock Hasklug `~/.local/share/fonts/HasklugNerdFont/HasklugNerdFontMono-Regular.otf` (box+powerline present); `/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf` (plain: box present, no E0B0).
- Commits: small, one per task step-group; end message with the Co-Authored-By trailer used elsewhere this session.
- **No worktree**: `~/code` is a multi-project repo with a `sh/lib` submodule; work in the main tree on `main` (as this session has). The Python code is not in the submodule.

**Ground-truth invariants (must stay true):**
- Box bar glyphs (`─ ┬ ┌ ┐`, BoundsPen `ymax < 600` in Hasklug units) share a bar centerline with up-stem junctions (`┼ ┴ ├ ┤ └ ┘`, `ymax ≈ 1000`).
- On fbterm @ size 15, up-stem junctions render ~2px lower; the fix shifts no-up-stem bar glyphs down 133 units (= 2px @ size 15) so all bars unify.
- Powerline separators (E0B0/B2/B8/BA/BC/BE, E0C0–C7) stretch onto U+2588's box `(-400..1000)` vertically, `[0,adv]` horizontally.

---

## Task 1: Tool scaffold + test loader

**Files:**
- Create: `~/code/python/bin/vtui-patch-font`
- Create: `~/code/python/tests/test_vtui_patch_font.py`

**Step 1: Write the failing test** (`tests/test_vtui_patch_font.py`)

```python
import importlib.util, pathlib
TOOL = pathlib.Path.home() / "code/python/bin/vtui-patch-font"

def load():
    spec = importlib.util.spec_from_loader("vtui_patch_font",
        importlib.machinery.SourceFileLoader("vtui_patch_font", str(TOOL)))
    mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
    return mod

def test_module_loads_and_has_version():
    m = load()
    assert isinstance(m.VERSION, str) and m.VERSION
```

**Step 2: Run — expect FAIL** (`FileNotFoundError` / no `VERSION`).
Run: `cd ~/code/python && python3 -m pytest tests/test_vtui_patch_font.py -v`

**Step 3: Minimal implementation** (`bin/vtui-patch-font`)

```python
#!/usr/bin/env python3
"""vtui-patch-font — make any monospace font fbterm-ready.

Pipeline: [add powerline] -> [box seam + powerline geometry] -> [junction
alignment] -> [fbterm-friendly size report]. Single file so it's easy to share.
"""
VERSION = "0.1.0"

def main(argv=None):
    raise SystemExit(0)

if __name__ == "__main__":
    main()
```

**Step 4:** `chmod +x ~/code/python/bin/vtui-patch-font`; rerun test — expect PASS.

**Step 5: Commit**
```bash
cd ~/code && git add python/bin/vtui-patch-font python/tests/test_vtui_patch_font.py
git commit -m "feat(vtui-patch-font): scaffold + importlib test loader"
```

---

## Task 2: fbterm-friendly size calculator (pure)

Cell width in px = `size * advance / upm`. fbterm rounds it to a whole cell; a large fractional part leaves a dead column (the font-saga seam). "Friendly" = the fractional dead-space is small. This is the general form (exact-integral is the special case); it handles fonts like DejaVu (0.602em) correctly.

**Files:** Modify `bin/vtui-patch-font`; Modify `tests/test_vtui_patch_font.py`.

**Step 1: Failing tests**

```python
def test_friendly_sizes_hasklug_like():
    m = load()
    # advance 600 / upm 1000 = 0.6em -> multiples of 5 are exact
    sizes = m.friendly_sizes(advance=600, upm=1000, lo=8, hi=26, tol=0.12)
    assert 10 in sizes and 15 in sizes and 20 in sizes and 25 in sizes
    assert 16 not in sizes            # 9.6px -> 0.4 dead, too fuzzy

def test_friendly_sizes_reports_cell_dims():
    m = load()
    rows = m.friendly_sizes(advance=600, upm=1000, lo=8, hi=16, tol=0.12, with_cells=True)
    assert (10, 6) in [(s, w) for (s, w, h) in rows]   # 10px -> 6px cell width
```

**Step 2:** Run — expect FAIL (`friendly_sizes` undefined).

**Step 3: Implementation** (add to tool)

```python
def _cell_metrics(size, advance, upm, ascent, descent):
    w = size * advance / upm
    h = size * (ascent - descent) / upm
    return w, h

def friendly_sizes(advance, upm, lo=8, hi=32, tol=0.12,
                   ascent=None, descent=None, with_cells=False):
    """fbterm sizes whose cell width lands within `tol` px of a whole pixel."""
    out = []
    for size in range(lo, hi + 1):
        w = size * advance / upm
        dead = min(w % 1, 1 - (w % 1))
        if dead <= tol:
            wc = round(w)
            hc = round(size * ((ascent - descent) / upm)) if ascent is not None else None
            out.append((size, wc, hc) if with_cells else size)
    return out
```

**Step 4:** Run — expect PASS.
**Step 5:** Commit `feat(vtui-patch-font): fbterm-friendly size calculator`.

---

## Task 3: Box-drawing seam fix (x-clamp), pure fontTools

Port the existing clamp: for U+2500–25FF, clamp glyph x-extents to `[0, advance]` so bars tile without the antialiased overhang seam.

**Files:** Modify tool + tests.

**Step 1: Failing test** (uses stock Hasklug fixture; patch in-memory, assert bounds)

```python
import pathlib
HASKLUG = pathlib.Path.home()/"code/../.local/share/fonts/HasklugNerdFont/HasklugNerdFontMono-Regular.otf"
HASKLUG = pathlib.Path.home()/".local/share/fonts/HasklugNerdFont/HasklugNerdFontMono-Regular.otf"

def _bounds(font, cp):
    from fontTools.pens.boundsPen import BoundsPen
    gs = font.getGlyphSet(); g = font.getBestCmap()[cp]
    bp = BoundsPen(gs); gs[g].draw(bp); return bp.bounds

def test_box_hline_clamped_to_cell():
    m = load()
    from fontTools.ttLib import TTFont
    f = TTFont(str(HASKLUG))
    adv = f["hmtx"]["uni2500"][0] if "uni2500" in f["hmtx"].metrics else f["hmtx"][f.getBestCmap()[0x2500]][0]
    m.fix_box_seams(f)               # mutates f in place
    xmin, ymin, xmax, ymax = _bounds(f, 0x2500)
    assert xmin >= -0.5 and xmax <= adv + 0.5
```

**Step 2:** Run — expect FAIL.

**Step 3: Implementation** — factor a shared glyph-rewrite helper (DRY, reused by Tasks 4 & 5):

```python
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.boundsPen import BoundsPen

def _is_cff(font): return "CFF " in font

def _rewrite_glyph(font, gname, adv, xform):
    """Redraw one glyph through xform. Handles CFF (.otf) and glyf (.ttf)."""
    gs = font.getGlyphSet()
    rec = RecordingPen(); gs[gname].draw(rec)
    def apply(pen):
        for op, args in rec.value:
            if op in ("moveTo", "lineTo"): getattr(pen, op)(xform(args[0]))
            elif op == "curveTo": pen.curveTo(*[xform(p) for p in args])
            elif op == "qCurveTo": pen.qCurveTo(*[xform(p) if p else None for p in args])
            elif op in ("closePath", "endPath"): getattr(pen, op)()
    if _is_cff(font):
        cff = font["CFF "].cff; td = cff[cff.fontNames[0]]
        pen = T2CharStringPen(adv, gs); apply(pen)
        td.CharStrings[gname] = pen.getCharString(td.Private)
    else:
        pen = TTGlyphPen(gs); apply(pen)
        font["glyf"][gname] = pen.glyph()

def _adv(font, gname): return font["hmtx"][gname][0]

def fix_box_seams(font):
    cmap = font.getBestCmap(); gs = font.getGlyphSet(); n = 0
    for cp in range(0x2500, 0x2600):
        g = cmap.get(cp)
        if not g: continue
        adv = _adv(font, g); bp = BoundsPen(gs); gs[g].draw(bp)
        if bp.bounds is None: continue
        xmin, _, xmax, _ = bp.bounds
        if xmin >= 0 and xmax <= adv: continue
        _rewrite_glyph(font, g, adv, lambda p: (max(0, min(adv, p[0])), p[1])); n += 1
    return n
```

Note the `.ttf` path (`glyf` + `TTGlyphPen`) — required because arbitrary input fonts are often TrueType, unlike Hasklug's CFF. Add a `.ttf` fixture assertion in a later task.

**Step 4:** Run — expect PASS. **Step 5:** Commit `feat(vtui-patch-font): box-drawing seam x-clamp (CFF+glyf)`.

---

## Task 4: Powerline separator stretch, pure fontTools

**Files:** Modify tool + tests.

**Step 1: Failing test**

```python
def test_powerline_separator_fills_cell_box():
    m = load()
    from fontTools.ttLib import TTFont
    f = TTFont(str(HASKLUG))
    if 0xE0B0 not in f.getBestCmap(): import pytest; pytest.skip("no powerline")
    adv = _adv(f, f.getBestCmap()[0xE0B0])
    m.fix_powerline(f)
    xmin, ymin, xmax, ymax = _bounds(f, 0xE0B0)
    assert abs(xmin) < 2 and abs(xmax - adv) < 2      # spans full width
    assert ymin <= -395 and ymax >= 995               # spans U+2588 box
```

**Step 2:** Run — FAIL.

**Step 3: Implementation**

```python
STRETCH = {0xE0B0,0xE0B2,0xE0B8,0xE0BA,0xE0BC,0xE0BE} | set(range(0xE0C0,0xE0C8))
CELL_Y = (-400, 1000)   # U+2588 FULL BLOCK y-bounds == fbterm cell box

def fix_powerline(font):
    cmap = font.getBestCmap(); gs = font.getGlyphSet(); n = 0
    for cp in STRETCH:
        g = cmap.get(cp)
        if not g: continue
        adv = _adv(font, g); bp = BoundsPen(gs); gs[g].draw(bp)
        if bp.bounds is None: continue
        xmin, ymin, xmax, ymax = bp.bounds
        if xmax == xmin or ymax == ymin: continue
        sx = adv / (xmax - xmin); sy = (CELL_Y[1]-CELL_Y[0]) / (ymax - ymin)
        _rewrite_glyph(font, g, adv,
            lambda p, _x=xmin, _y=ymin, _sx=sx, _sy=sy: ((p[0]-_x)*_sx, (p[1]-_y)*_sy + CELL_Y[0]))
        n += 1
    return n
```

**Step 4:** PASS. **Step 5:** Commit `feat(vtui-patch-font): powerline separator stretch`.

---

## Task 5: Box-junction alignment (the size-coupled stage)

### Task 5a: Derive the fbterm shove formula (investigation)

**No code yet.** Fetch fbterm 1.7 source (`WebFetch`/clone `github.com/izmntuk/fbterm` or the sf.net mirror). Read the glyph-drawing path (Screen/Font: how a glyph bitmap's vertical position in the cell is computed, esp. handling of glyphs whose bitmap exceeds the cell). Produce a written formula:
`shove_px(font_box_metrics, size) -> pixels the up-stem glyphs move down`.
Record it as a comment block in the tool. **Acceptance:** the formula, evaluated for Hasklug at size 15, yields **2px** (our measured ground truth). If the source proves inscrutable, fall back to the empirical model: shove = 2px whenever box up-stem ink overflows the cell top; expose `--calibrate` (Task 5c) as the accurate path and document the assumption.

### Task 5b: Implement + unit-test the junction shift

**Step 1: Failing test**

```python
def test_junction_shift_hasklug_size15_is_2px():
    m = load()
    from fontTools.ttLib import TTFont
    f = TTFont(str(HASKLUG))
    units = m.junction_shift_units(f, size=15)   # font units to move no-up-stem bars DOWN
    px = units / (f["head"].unitsPerEm / 15)
    assert abs(abs(px) - 2.0) < 0.35             # ~2px down @ size 15
    assert units < 0                              # negative = down (font y-up)

def test_junction_classes_split_by_ymax():
    m = load()
    from fontTools.ttLib import TTFont
    f = TTFont(str(HASKLUG))
    up, plain = m.junction_classes(f)
    cm = f.getBestCmap()
    assert cm[0x253C] in up and cm[0x2534] in up      # ┼ ┴ up-stem
    assert cm[0x2500] in plain and cm[0x252C] in plain # ─ ┬ no-up-stem
```

**Step 2:** FAIL.

**Step 3: Implementation** — classify by ink-top relative to the bar, shift the plain class down by the formula. Threshold is derived per-font (midpoint between the two ymax clusters), NOT hardcoded 600:

```python
def junction_classes(font):
    """Return (up_stem_glyphnames, no_up_stem_bar_glyphnames) among U+2500-257F."""
    cmap = font.getBestCmap(); gs = font.getGlyphSet()
    upm = font["head"].unitsPerEm
    up, plain = set(), set()
    for cp in range(0x2500, 0x2580):
        g = cmap.get(cp)
        if not g: continue
        bp = BoundsPen(gs); gs[g].draw(bp)
        if bp.bounds is None: continue
        xmin, ymin, xmax, ymax = bp.bounds
        # up-stem: ink reaches near the em top (cell top). Scale threshold by upm.
        if ymax >= 0.85 * upm: up.add(g)
        elif ymax <= 0.55 * upm: plain.add(g)   # bar-only / down-only
    return up, plain

def junction_shift_units(font, size):
    upm = font["head"].unitsPerEm
    shove_px = fbterm_shove_px(font, size)      # from Task 5a formula
    return -round(shove_px * upm / size)        # negative = down

def align_box_junctions(font, size):
    up, plain = junction_classes(font)
    dy = junction_shift_units(font, size)
    for g in plain:
        adv = _adv(font, g)
        _rewrite_glyph(font, g, adv, lambda p, _dy=dy: (p[0], p[1] + _dy))
    return dy
```

**Step 4:** PASS. **Step 5:** Commit `feat(vtui-patch-font): box-junction alignment (source-derived shove)`.

### Task 5c: `--verify` harness cross-check (integration, optional at runtime)

Wrap the spare-VT harness (from 2026-07-07: throwaway `fbterm` on a free VT via `openvt`+`runuser`, `vt-capture`, per-column bar-centroid measurement) as a function `verify_alignment(font_path, size, vt=8) -> residual_px`. Auto-skip (return `None` + note) if `/dev/fb0` is absent or `openvt` unavailable. Test: mark `@pytest.mark.skipif(no framebuffer)`, assert residual `< 0.5px` on the patched Hasklug. Commit `feat(vtui-patch-font): --verify spare-VT alignment check`.

---

## Task 6: Add powerline glyphs from a donor (fontforge stage)

**Prereq (one system change, confirm with user first):** `sudo apt install -y fontforge`; vendor powerline/fontpatcher into `~/code/python/vendor/powerline-fontpatcher/` (git clone, pinned).

**Files:** Modify tool + tests.

**Step 1: Failing integration test**

```python
import shutil, pytest
DEJAVU = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"

@pytest.mark.skipif(not shutil.which("fontforge"), reason="fontforge not installed")
def test_add_powerline_to_plain_font(tmp_path):
    m = load()
    from fontTools.ttLib import TTFont
    assert 0xE0B0 not in TTFont(DEJAVU).getBestCmap()
    out = m.add_powerline(DEJAVU, tmp_path)      # returns path to glyph-added font
    assert 0xE0B0 in TTFont(out).getBestCmap()
```

**Step 2:** FAIL.

**Step 3: Implementation** — `add_powerline(src, workdir)` shells out to the vendored fontpatcher via `fontforge -script`, returns the output path. If the font already has E0B0, copy through unchanged (no-op). Keep the subprocess call and script path in one small function.

**Step 4:** PASS (or SKIP if fontforge absent). **Step 5:** Commit `feat(vtui-patch-font): add powerline glyphs via fontforge patcher`.

---

## Task 7: CLI orchestration + progress UX + naming

Wire `main()` with `argparse`: `input`, `--size N` (default = top `friendly_sizes` pick), `--nerd`, `--verify`, `-o/--output`. Orchestrate: detect-powerline → (add if missing) → `fix_box_seams` → `fix_powerline` → `align_box_junctions` → rename family to "<Name> VTui" → save `<stem>-VTui<ext>` → print the size report. Emit the `* stage ... done` progress lines and the final summary from the mockup.

**Test:** `test_end_to_end_cli(tmp_path)` invokes `main(["<hasklug>", "--size", "15", "-o", out])`, asserts output exists, family name contains "VTui", box seams clamped, junctions classified/shifted. Commit `feat(vtui-patch-font): CLI orchestration + progress output`.

---

## Task 8: Parity validation + retire old script

- Run `vtui-patch-font <stock-hasklug> --size 15 --verify`; confirm residual `< 0.5px` and that the box-seam/powerline results match the current `HasklugNerdFontMono-Regular-FbTerm.otf` (compare BoundsPen on 0x2500/0xE0B0/0x253C between the two outputs).
- Only then delete `~/.fonts/patches/patch-fbterm-boxdrawing.py` and its `~/projects/vtcon/font/` symlink. Commit `chore(vtui): retire patch-fbterm-boxdrawing.py (superseded by vtui-patch-font)`.

---

## Task 9: Rename sweep — vtcon → VTui, `vtui-` prefix

Mechanical, but wide. Do as one reviewed change:
- `git mv`/`mv` `~/projects/vtcon` → `~/projects/vtui`.
- Rename scripts in `~/code/sh/bin` (+ their `~/projects/vtui/bin` symlinks): `vtvol`→`vtui-vol`, `vtbright`→`vtui-bright`, `fbterm-session`→`vtui-fbterm-session`, `fbterm-genbg`→`vtui-fbterm-genbg`. Keep `vol`, `bright`, `clip*`, `lnotify`, `vt-capture` unchanged.
- Update internal references: `vtui-vol`/`vtui-bright` call `vol`/`bright` (unchanged); `vtui-fbterm-session` references to `fbterm-genbg` → `vtui-fbterm-genbg`.
- Boot chain: `~/.profile` exec of `fbterm-session` → `vtui-fbterm-session`; autologin drop-in if it names the script; `~/.local/bin` any copies.
- Tracked `.tmux.conf`: `vtvol`→`vtui-vol`, `vtbright`→`vtui-bright` in binds + `command -v` guards.
- `vtui-patch-font` symlink into `~/projects/vtui/bin`.
- Verify: `command -v vtui-vol vtui-bright vtui-fbterm-session vtui-patch-font`; reload tmux, confirm binds resolve; sanity-check `~/.profile` gate still execs the renamed session script (do NOT trigger a live fbterm restart under the user).
- Commit `refactor(vtui): rename vtcon->VTui + vtui- prefix for setup-specific utils`.

---

## Task 10: VTui overview README

Rewrite `~/projects/vtui/README.md` as the project map: retitle VTui; keep the boot-chain diagram; add a component table (session `vtui-fbterm-session`/`vtui-fbterm-genbg`; shell `~/.profile` gate, `~/.fbtermrc`, tmux config; keys/feedback `vtui-vol`/`vtui-bright`/`lnotify`; utilities `vt-capture`/`vtui-patch-font`; generic building blocks `vol`/`bright`/`clip`), each a one-liner + real location; fold the font-saga notes under `vtui-patch-font`. Commit `docs(vtui): overview README with component map`.

---

## Notes for the executor
- Commit after every green task; never bundle unrelated changes.
- The `.ttf` (glyf) path in `_rewrite_glyph` is load-bearing for arbitrary fonts — add a DejaVu-based geometry test if any glyf-path bug is suspected.
- Do not restart the user's live tty6 fbterm; validation uses the spare-VT harness (tty8).
- fontforge install (Task 6) is the only system change — confirm with the user before running apt.
