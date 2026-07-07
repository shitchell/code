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
