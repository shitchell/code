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
