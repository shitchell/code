import importlib.util, importlib.machinery, pathlib

TOOL = pathlib.Path.home() / "code/python/bin/vtui-patch-font"


def load():
    loader = importlib.machinery.SourceFileLoader("vtui_patch_font", str(TOOL))
    spec = importlib.util.spec_from_loader("vtui_patch_font", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


def test_module_loads_and_has_version():
    m = load()
    assert isinstance(m.VERSION, str) and m.VERSION


def test_friendly_sizes_hasklug_like():
    m = load()
    # advance 600 / upm 1000 = 0.6em -> multiples of 5 are exact
    sizes = m.friendly_sizes(advance=600, upm=1000, lo=8, hi=26, tol=0.12)
    assert 10 in sizes and 15 in sizes and 20 in sizes and 25 in sizes
    assert 16 not in sizes  # 9.6px -> 0.4 dead, too fuzzy


def test_friendly_sizes_reports_cell_dims():
    m = load()
    rows = m.friendly_sizes(
        advance=600,
        upm=1000,
        lo=8,
        hi=16,
        tol=0.12,
        ascent=800,
        descent=-200,
        with_cells=True,
    )
    assert (10, 6) in [(s, w) for (s, w, h) in rows]  # 10px -> 6px cell width


def _bounds(font, cp):
    from fontTools.pens.boundsPen import BoundsPen

    gs = font.getGlyphSet()
    g = font.getBestCmap()[cp]
    bp = BoundsPen(gs)
    gs[g].draw(bp)
    return bp.bounds


HASKLUG = "/home/guy/.local/share/fonts/HasklugNerdFont/HasklugNerdFontMono-Regular.otf"


def test_box_hline_clamped_to_cell():
    m = load()
    from fontTools.ttLib import TTFont

    f = TTFont(HASKLUG)
    g = f.getBestCmap()[0x2500]
    adv = f["hmtx"][g][0]
    m.fix_box_seams(f)  # mutates f in place
    xmin, ymin, xmax, ymax = _bounds(f, 0x2500)
    assert xmin >= -0.5 and xmax <= adv + 0.5


import os
import pytest

DEJAVU = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
_dejavu = pytest.mark.skipif(
    not os.path.exists(DEJAVU), reason="DejaVu TTF not installed"
)


@_dejavu
def test_box_seams_glyf_clamp_survives_save_reload(tmp_path):
    m = load()
    from fontTools.ttLib import TTFont

    f = TTFont(DEJAVU)
    g = f.getBestCmap()[0x2500]
    adv = f["hmtx"][g][0]
    m.fix_box_seams(f)
    out = tmp_path / "dejavu-patched.ttf"
    f.save(str(out))
    f2 = TTFont(str(out))
    xmin, ymin, xmax, ymax = _bounds(f2, 0x2500)  # AFTER save+reload
    assert xmin >= -0.5 and xmax <= adv + 0.5


@_dejavu
def test_box_seams_preserves_composite_block_glyph():
    m = load()
    from fontTools.ttLib import TTFont

    f = TTFont(DEJAVU)
    m.fix_box_seams(f)
    b = _bounds(f, 0x2580)  # upper-half block, a composite in DejaVu
    assert b is not None  # not blanked


def test_powerline_separator_fills_cell_box():
    m = load()
    from fontTools.ttLib import TTFont

    f = TTFont(HASKLUG)
    if 0xE0B0 not in f.getBestCmap():
        import pytest

        pytest.skip("fixture has no powerline glyphs")
    g = f.getBestCmap()[0xE0B0]
    adv = f["hmtx"][g][0]
    m.fix_powerline(f)
    xmin, ymin, xmax, ymax = _bounds(f, 0xE0B0)
    assert abs(xmin) < 2 and abs(xmax - adv) < 2  # spans full width
    assert ymin <= -395 and ymax >= 995  # spans U+2588 box (-400..1000)


def test_junction_classes_split_by_ymax():
    m = load()
    from fontTools.ttLib import TTFont

    f = TTFont(HASKLUG)
    cm = f.getBestCmap()
    up, plain = m.junction_classes(f)
    assert cm[0x253C] in up and cm[0x2534] in up  # ┼ ┴ up-stem
    assert cm[0x2500] in plain and cm[0x252C] in plain  # ─ ┬ no-up-stem
    assert cm[0x253C] not in plain and cm[0x2500] not in up


def test_default_shove_px():
    m = load()
    assert m.default_shove_px(15) == 2  # measured ground truth
    assert m.default_shove_px(30) == 4  # ~scales
    assert m.default_shove_px(7) >= 1  # never zero


def test_junction_shift_units_2px_at_15():
    m = load()
    from fontTools.ttLib import TTFont

    f = TTFont(HASKLUG)
    units = m.junction_shift_units(f, size=15, shove_px=2)  # font units, DOWN
    assert units < 0  # font y is up, so down = negative
    px = abs(units) / (f["head"].unitsPerEm / 15)
    assert abs(px - 2.0) < 0.3  # ~2px -> ~-133 units


def test_align_shifts_plain_bars_not_up_stems():
    m = load()
    from fontTools.ttLib import TTFont

    f = TTFont(HASKLUG)
    before_hline = _bounds(f, 0x2500)[1]  # ymin of ─
    before_cross = _bounds(f, 0x253C)[1]  # ymin of ┼
    m.align_box_junctions(f, size=15, shove_px=2)
    after_hline = _bounds(f, 0x2500)[1]
    after_cross = _bounds(f, 0x253C)[1]
    assert after_hline < before_hline - 100  # ─ moved down ~133 units
    assert abs(after_cross - before_cross) < 1  # ┼ (up-stem) untouched


def test_recommend_size_prefers_midrange():
    m = load()
    # 0.6em font: friendly sizes 10,15,20,25; recommend one in ~14-18
    assert m.recommend_size([5, 10, 15, 20, 25]) == 15
    assert m.recommend_size([8, 12, 16, 20]) == 16


def test_end_to_end_cli_patches_and_renames(tmp_path, capsys):
    m = load()
    from fontTools.ttLib import TTFont

    out = tmp_path / "out.otf"
    rc = m.main([HASKLUG, "--size", "15", "-o", str(out)])
    assert rc in (0, None)
    assert out.exists()
    f = TTFont(str(out))
    # family renamed to a VTui variant
    fam = f["name"].getDebugName(1)
    assert "VTui" in fam
    # box seam applied (U+2500 within cell)
    g = f.getBestCmap()[0x2500]
    adv = f["hmtx"][g][0]
    xmin, ymin, xmax, ymax = _bounds(f, 0x2500)
    assert xmin >= -0.5 and xmax <= adv + 0.5
    # progress + size report printed
    captured = capsys.readouterr().out
    assert "done" in captured and "FbTerm-friendly sizes" in captured
