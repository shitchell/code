from pathlib import Path
import pytest
from dashboard.config import Arg, Executable, Dashboard, Config

def test_arg_defaults():
    arg = Arg(name="verbose")
    assert arg.positional is False
    assert arg.parameter is None
    assert arg.type == "str"
    assert arg.nargs == 1

def test_arg_parameter_auto_short():
    arg = Arg(name="v")
    assert arg.derived_parameter == "-v"

def test_arg_parameter_auto_long():
    arg = Arg(name="quality")
    assert arg.derived_parameter == "--quality"

def test_arg_parameter_explicit_overrides():
    arg = Arg(name="verbose", parameter="-V")
    assert arg.derived_parameter == "-V"

def test_executable_defaults():
    exe = Executable(id="foo", name="Foo", path="/usr/bin/foo")
    assert exe.args == []

def test_config_structure():
    config = Config(
        executables=[Executable(id="foo", name="Foo", path="/bin/foo")],
        dashboards=[Dashboard(name="Dev", executables=["foo"])],
    )
    assert len(config.executables) == 1
    assert config.dashboards[0].name == "Dev"
