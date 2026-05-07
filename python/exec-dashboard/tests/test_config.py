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


import textwrap
import yaml
from dashboard.config import load_config

SAMPLE_YAML = textwrap.dedent("""
    executables:
      - id: foo
        name: Foo Tool
        path: /usr/bin/foo
        args:
          - name: input
            positional: true
            type: pathlib.Path
            nargs: 1
          - name: verbose
            positional: false
            type: bool
            nargs: 0
            parameter: "-v"

    dashboards:
      - name: Dev
        executables: [foo]
""")

def test_load_config_executables():
    config = load_config(yaml.safe_load(SAMPLE_YAML))
    assert len(config.executables) == 1
    exe = config.executables[0]
    assert exe.id == "foo"
    assert exe.name == "Foo Tool"
    assert exe.path == "/usr/bin/foo"
    assert len(exe.args) == 2

def test_load_config_arg_positional():
    config = load_config(yaml.safe_load(SAMPLE_YAML))
    arg = config.executables[0].args[0]
    assert arg.name == "input"
    assert arg.positional is True
    assert arg.type == "pathlib.Path"
    assert arg.nargs == 1

def test_load_config_arg_flag():
    config = load_config(yaml.safe_load(SAMPLE_YAML))
    arg = config.executables[0].args[1]
    assert arg.name == "verbose"
    assert arg.nargs == 0
    assert arg.derived_parameter == "-v"

def test_load_config_dashboards():
    config = load_config(yaml.safe_load(SAMPLE_YAML))
    assert len(config.dashboards) == 1
    assert config.dashboards[0].name == "Dev"
    assert config.dashboards[0].executables == ["foo"]

def test_load_config_from_file(tmp_path):
    config_file = tmp_path / "dashboard.yaml"
    config_file.write_text(SAMPLE_YAML)
    from dashboard.config import load_config_file
    config = load_config_file(config_file)
    assert config.executables[0].id == "foo"
