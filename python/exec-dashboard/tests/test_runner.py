import pytest
from dashboard.config import Arg, Executable
from dashboard.runner import build_argv


def test_no_args():
    exe = Executable(id="x", name="X", path="/bin/x")
    assert build_argv(exe, {}) == ["/bin/x"]


def test_positional_arg():
    exe = Executable(
        id="x",
        name="X",
        path="/bin/x",
        args=[
            Arg(name="file", positional=True, type="str", nargs=1),
        ],
    )
    assert build_argv(exe, {"file": "foo.txt"}) == ["/bin/x", "foo.txt"]


def test_flag_with_value():
    exe = Executable(
        id="x",
        name="X",
        path="/bin/x",
        args=[
            Arg(name="quality", positional=False, type="int", nargs=1),
        ],
    )
    assert build_argv(exe, {"quality": 85}) == ["/bin/x", "--quality", "85"]


def test_flag_nargs_zero():
    exe = Executable(
        id="x",
        name="X",
        path="/bin/x",
        args=[
            Arg(name="verbose", positional=False, type="bool", nargs=0, parameter="-v"),
        ],
    )
    assert build_argv(exe, {"verbose": True}) == ["/bin/x", "-v"]
    assert build_argv(exe, {"verbose": False}) == ["/bin/x"]


def test_multi_value_flag():
    exe = Executable(
        id="x",
        name="X",
        path="/bin/x",
        args=[
            Arg(name="files", positional=False, type="str", nargs="*"),
        ],
    )
    assert build_argv(exe, {"files": ["a.txt", "b.txt"]}) == [
        "/bin/x",
        "--files",
        "a.txt",
        "b.txt",
    ]


def test_positional_before_flags():
    exe = Executable(
        id="x",
        name="X",
        path="/bin/x",
        args=[
            Arg(name="output", positional=True, type="str", nargs=1),
            Arg(name="verbose", positional=False, type="bool", nargs=0, parameter="-v"),
        ],
    )
    result = build_argv(exe, {"output": "out.txt", "verbose": True})
    assert result == ["/bin/x", "out.txt", "-v"]
