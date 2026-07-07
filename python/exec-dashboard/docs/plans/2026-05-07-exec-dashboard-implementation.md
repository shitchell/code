# Exec Dashboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Textual TUI button dashboard that runs executables defined in a YAML config, with typed parameter forms and a shared streaming output log.

**Architecture:** YAML config defines executables (with typed args) and named dashboards (lists of executable IDs). The Textual app renders a button grid for the active dashboard, shows a `ModalScreen` param form when an executable has args, then runs the command via `asyncio.create_subprocess_exec` and streams output into a shared `RichLog` panel. Switching dashboards is done via the built-in `^P` command palette.

**Tech Stack:** Python 3.11+, [Textual](https://textual.textualize.io/) (TUI), PyYAML (config), asyncio (subprocess streaming)

**Design doc:** `docs/plans/2026-05-07-exec-dashboard-design.md`

**Worktree:** `.worktrees/feature-initial-build` (branch `feature/initial-build`)

---

## Task 1: Project Scaffolding

**Files:**
- Create: `pyproject.toml`
- Create: `dashboard/__init__.py`
- Create: `dashboard/widgets/__init__.py`
- Create: `tests/__init__.py`

**Step 1: Write pyproject.toml**

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "exec-dashboard"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "textual>=0.80.0",
    "pyyaml>=6.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "pytest-asyncio>=0.23",
    "textual-dev>=0.80.0",
]

[project.scripts]
dashboard = "dashboard.__main__:main"

[tool.pytest.ini_options]
asyncio_mode = "auto"
```

**Step 2: Create package stubs**

```bash
mkdir -p dashboard/widgets tests
touch dashboard/__init__.py dashboard/widgets/__init__.py tests/__init__.py
```

**Step 3: Install**

```bash
pip install -e ".[dev]"
```

Expected: installs cleanly with no errors.

**Step 4: Commit**

```bash
git add pyproject.toml dashboard/ tests/
git commit -m "chore: scaffold project structure"
```

---

## Task 2: Config — Dataclasses

**Files:**
- Create: `dashboard/config.py`
- Create: `tests/test_config.py`

**Step 1: Write failing tests**

```python
# tests/test_config.py
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
```

**Step 2: Run to verify failure**

```bash
pytest tests/test_config.py -v
```

Expected: `ImportError` or `AttributeError` — module doesn't exist yet.

**Step 3: Implement dataclasses**

```python
# dashboard/config.py
from __future__ import annotations
from dataclasses import dataclass, field
from pathlib import Path

TYPE_MAP: dict[str, type] = {
    "str": str,
    "int": int,
    "float": float,
    "bool": bool,
    "pathlib.Path": Path,
}


@dataclass
class Arg:
    name: str
    positional: bool = False
    parameter: str | None = None   # explicit flag; None = auto-derive
    type: str = "str"
    nargs: int | str = 1

    @property
    def derived_parameter(self) -> str:
        if self.parameter is not None:
            return self.parameter
        return f"-{self.name}" if len(self.name) == 1 else f"--{self.name}"

    @property
    def python_type(self) -> type:
        return TYPE_MAP.get(self.type, str)


@dataclass
class Executable:
    id: str
    name: str
    path: str
    args: list[Arg] = field(default_factory=list)


@dataclass
class Dashboard:
    name: str
    executables: list[str]   # executable ids


@dataclass
class Config:
    executables: list[Executable]
    dashboards: list[Dashboard]
```

**Step 4: Run tests**

```bash
pytest tests/test_config.py -v
```

Expected: all pass.

**Step 5: Commit**

```bash
git add dashboard/config.py tests/test_config.py
git commit -m "feat: config dataclasses with derived_parameter and python_type"
```

---

## Task 3: Config — YAML Parsing

**Files:**
- Modify: `dashboard/config.py` (add `load_config`)
- Modify: `tests/test_config.py` (add parsing tests)

**Step 1: Write failing tests**

Add to `tests/test_config.py`:

```python
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
```

**Step 2: Run to verify failure**

```bash
pytest tests/test_config.py -v -k "load"
```

Expected: `ImportError` — `load_config` not defined.

**Step 3: Implement parsing**

Add to `dashboard/config.py`:

```python
import yaml


def load_config(data: dict) -> Config:
    executables = [
        Executable(
            id=exe["id"],
            name=exe["name"],
            path=exe["path"],
            args=[
                Arg(
                    name=arg["name"],
                    positional=arg.get("positional", False),
                    parameter=arg.get("parameter", None),
                    type=arg.get("type", "str"),
                    nargs=arg.get("nargs", 1),
                )
                for arg in exe.get("args", [])
            ],
        )
        for exe in data.get("executables", [])
    ]
    dashboards = [
        Dashboard(name=d["name"], executables=d.get("executables", []))
        for d in data.get("dashboards", [])
    ]
    return Config(executables=executables, dashboards=dashboards)


def load_config_file(path: Path) -> Config:
    with open(path) as f:
        return load_config(yaml.safe_load(f))
```

**Step 4: Run tests**

```bash
pytest tests/test_config.py -v
```

Expected: all pass.

**Step 5: Commit**

```bash
git add dashboard/config.py tests/test_config.py
git commit -m "feat: YAML config parsing with load_config and load_config_file"
```

---

## Task 4: Runner — Argv Building

**Files:**
- Create: `dashboard/runner.py`
- Create: `tests/test_runner.py`

**Step 1: Write failing tests**

```python
# tests/test_runner.py
import pytest
from dashboard.config import Arg, Executable
from dashboard.runner import build_argv

def test_no_args():
    exe = Executable(id="x", name="X", path="/bin/x")
    assert build_argv(exe, {}) == ["/bin/x"]

def test_positional_arg():
    exe = Executable(id="x", name="X", path="/bin/x", args=[
        Arg(name="file", positional=True, type="str", nargs=1),
    ])
    assert build_argv(exe, {"file": "foo.txt"}) == ["/bin/x", "foo.txt"]

def test_flag_with_value():
    exe = Executable(id="x", name="X", path="/bin/x", args=[
        Arg(name="quality", positional=False, type="int", nargs=1),
    ])
    assert build_argv(exe, {"quality": 85}) == ["/bin/x", "--quality", "85"]

def test_flag_nargs_zero():
    exe = Executable(id="x", name="X", path="/bin/x", args=[
        Arg(name="verbose", positional=False, type="bool", nargs=0, parameter="-v"),
    ])
    # True = include flag, False = omit
    assert build_argv(exe, {"verbose": True}) == ["/bin/x", "-v"]
    assert build_argv(exe, {"verbose": False}) == ["/bin/x"]

def test_multi_value_flag():
    exe = Executable(id="x", name="X", path="/bin/x", args=[
        Arg(name="files", positional=False, type="str", nargs="*"),
    ])
    assert build_argv(exe, {"files": ["a.txt", "b.txt"]}) == [
        "/bin/x", "--files", "a.txt", "b.txt"
    ]

def test_positional_before_flags():
    exe = Executable(id="x", name="X", path="/bin/x", args=[
        Arg(name="output", positional=True, type="str", nargs=1),
        Arg(name="verbose", positional=False, type="bool", nargs=0, parameter="-v"),
    ])
    result = build_argv(exe, {"output": "out.txt", "verbose": True})
    assert result == ["/bin/x", "out.txt", "-v"]
```

**Step 2: Run to verify failure**

```bash
pytest tests/test_runner.py -v
```

Expected: `ImportError`.

**Step 3: Implement `build_argv`**

```python
# dashboard/runner.py
from __future__ import annotations
from dashboard.config import Executable


def build_argv(exe: Executable, values: dict[str, object]) -> list[str]:
    """Build argv list from an executable and resolved parameter values."""
    argv = [exe.path]

    positional = [arg for arg in exe.args if arg.positional]
    flags = [arg for arg in exe.args if not arg.positional]

    for arg in positional:
        val = values.get(arg.name)
        if val is not None:
            argv.append(str(val))

    for arg in flags:
        val = values.get(arg.name)
        if val is None:
            continue
        if arg.nargs == 0:
            if val:
                argv.append(arg.derived_parameter)
        elif isinstance(val, list):
            argv.append(arg.derived_parameter)
            argv.extend(str(v) for v in val)
        else:
            argv.extend([arg.derived_parameter, str(val)])

    return argv
```

**Step 4: Run tests**

```bash
pytest tests/test_runner.py -v
```

Expected: all pass.

**Step 5: Commit**

```bash
git add dashboard/runner.py tests/test_runner.py
git commit -m "feat: build_argv constructs subprocess argv from executable + values"
```

---

## Task 5: Runner — Async Subprocess

**Files:**
- Modify: `dashboard/runner.py` (add `run_executable`)
- Modify: `tests/test_runner.py` (add async tests)

**Step 1: Write failing tests**

Add to `tests/test_runner.py`:

```python
import asyncio
from dashboard.runner import run_executable
from dashboard.config import Executable

async def test_run_captures_stdout():
    exe = Executable(id="echo", name="Echo", path="/bin/echo", args=[
        __import__('dashboard.config', fromlist=['Arg']).Arg(
            name="msg", positional=True, type="str", nargs=1
        )
    ])
    lines = []
    async for line in run_executable(exe, {"msg": "hello"}):
        lines.append(line)
    assert lines == [("stdout", "hello")]

async def test_run_returns_exit_code():
    exe = Executable(id="true", name="True", path="/bin/true")
    lines = []
    async for item in run_executable(exe, {}):
        lines.append(item)
    assert ("exit", 0) in lines

async def test_run_nonzero_exit():
    exe = Executable(id="false", name="False", path="/bin/false")
    items = [item async for item in run_executable(exe, {})]
    assert ("exit", 1) in items
```

**Step 2: Run to verify failure**

```bash
pytest tests/test_runner.py -v -k "run"
```

Expected: `ImportError` — `run_executable` not defined.

**Step 3: Implement `run_executable`**

Add to `dashboard/runner.py`:

```python
import asyncio
from asyncio.subprocess import PIPE, STDOUT
from collections.abc import AsyncGenerator


async def run_executable(
    exe: Executable,
    values: dict[str, object],
) -> AsyncGenerator[tuple[str, str | int], None]:
    """
    Async generator yielding:
      ("stdout", line_str)  for each output line
      ("exit", code)        when process finishes
    """
    argv = build_argv(exe, values)
    proc = await asyncio.create_subprocess_exec(
        *argv,
        stdout=PIPE,
        stderr=STDOUT,   # merge stderr into stdout
    )
    assert proc.stdout is not None
    async for raw in proc.stdout:
        yield ("stdout", raw.decode(errors="replace").rstrip("\n"))
    await proc.wait()
    yield ("exit", proc.returncode)
```

**Step 4: Run tests**

```bash
pytest tests/test_runner.py -v
```

Expected: all pass.

**Step 5: Commit**

```bash
git add dashboard/runner.py tests/test_runner.py
git commit -m "feat: async run_executable streams stdout+stderr, yields exit code"
```

---

## Task 6: Log Panel Widget

**Files:**
- Create: `dashboard/widgets/log_panel.py`

No unit tests for Textual widgets — they're integration-tested via the running app.

**Step 1: Implement**

```python
# dashboard/widgets/log_panel.py
from __future__ import annotations
from datetime import datetime
from textual.app import ComposeResult
from textual.widgets import RichLog, Static
from textual.widget import Widget


class LogPanel(Widget):
    """Shared scrollable output log. Append run sections via begin_run / append_line / end_run."""

    DEFAULT_CSS = """
    LogPanel {
        height: 1fr;
        border-top: solid $accent;
    }
    """

    def compose(self) -> ComposeResult:
        yield RichLog(highlight=True, markup=True, wrap=True)

    def _log(self) -> RichLog:
        return self.query_one(RichLog)

    def begin_run(self, name: str) -> None:
        ts = datetime.now().strftime("%H:%M:%S")
        self._log().write(f"\n[bold cyan][{ts}] {name}[/bold cyan] {'─' * 40}")

    def append_line(self, line: str) -> None:
        self._log().write(line)

    def end_run(self, exit_code: int) -> None:
        if exit_code == 0:
            self._log().write(f"[bold green]✓ exited {exit_code}[/bold green]")
        else:
            self._log().write(f"[bold red]✗ exited {exit_code}[/bold red]")
```

**Step 2: Commit**

```bash
git add dashboard/widgets/log_panel.py
git commit -m "feat: LogPanel widget with begin_run/append_line/end_run"
```

---

## Task 7: Param Modal Widget

**Files:**
- Create: `dashboard/widgets/param_modal.py`

**Step 1: Implement**

```python
# dashboard/widgets/param_modal.py
from __future__ import annotations
from pathlib import Path
from textual import on
from textual.app import ComposeResult
from textual.screen import ModalScreen
from textual.widgets import Button, Checkbox, Input, Label, Static
from textual.containers import Vertical, Horizontal
from dashboard.config import Arg, Executable


class ParamModal(ModalScreen[dict[str, object] | None]):
    """
    Shows a form for filling in args before running an executable.
    Dismisses with a dict of {arg_name: converted_value} or None if cancelled.
    """

    DEFAULT_CSS = """
    ParamModal {
        align: center middle;
    }
    ParamModal > Vertical {
        width: 60;
        height: auto;
        background: $surface;
        border: solid $accent;
        padding: 1 2;
    }
    ParamModal .field {
        height: auto;
        margin-bottom: 1;
    }
    ParamModal .actions {
        height: auto;
        margin-top: 1;
    }
    """

    def __init__(self, exe: Executable) -> None:
        super().__init__()
        self.exe = exe

    def compose(self) -> ComposeResult:
        with Vertical():
            yield Static(f"[bold]{self.exe.name}[/bold]", markup=True)
            for arg in self.exe.args:
                with Vertical(classes="field"):
                    yield Label(arg.name)
                    if arg.nargs == 0:
                        yield Checkbox(arg.name, id=f"arg_{arg.name}")
                    else:
                        yield Input(
                            placeholder=f"{arg.type} {'(positional)' if arg.positional else arg.derived_parameter}",
                            id=f"arg_{arg.name}",
                        )
            with Horizontal(classes="actions"):
                yield Button("Run", variant="primary", id="run")
                yield Button("Cancel", id="cancel")

    @on(Button.Pressed, "#run")
    def on_run(self) -> None:
        values: dict[str, object] = {}
        error: str | None = None
        for arg in self.exe.args:
            widget_id = f"arg_{arg.name}"
            if arg.nargs == 0:
                values[arg.name] = self.query_one(f"#{widget_id}", Checkbox).value
                continue
            raw = self.query_one(f"#{widget_id}", Input).value.strip()
            try:
                python_type = arg.python_type
                if python_type is Path:
                    values[arg.name] = Path(raw)
                else:
                    values[arg.name] = python_type(raw)
            except (ValueError, TypeError):
                error = f"Invalid value for '{arg.name}': expected {arg.type}"
                break
        if error:
            self.notify(error, severity="error")
            return
        self.dismiss(values)

    @on(Button.Pressed, "#cancel")
    def on_cancel(self) -> None:
        self.dismiss(None)
```

**Step 2: Commit**

```bash
git add dashboard/widgets/param_modal.py
git commit -m "feat: ParamModal collects and type-converts arg inputs before run"
```

---

## Task 8: Main App

**Files:**
- Create: `dashboard/app.py`
- Create: `dashboard/__main__.py`

**Step 1: Implement app**

```python
# dashboard/app.py
from __future__ import annotations
import asyncio
from pathlib import Path
from textual.app import App, ComposeResult
from textual.command import Provider, Hit, Hits
from textual.widgets import Button, Header, Footer
from textual.containers import ScrollableContainer, Vertical
from dashboard.config import Config, Executable, load_config_file
from dashboard.widgets.log_panel import LogPanel
from dashboard.widgets.param_modal import ParamModal
from dashboard.runner import run_executable


# ── Command palette provider ──────────────────────────────────────────────────

class DashboardCommands(Provider):
    """Lists dashboards (including 'All') in the command palette."""

    async def search(self, query: str) -> Hits:
        app: DashboardApp = self.app  # type: ignore[assignment]
        names = ["All"] + [d.name for d in app.config.dashboards]
        for name in names:
            if query.lower() in name.lower():
                yield Hit(
                    score=1.0,
                    match_display=name,
                    command=lambda n=name: app.switch_dashboard(n),
                    help=f"Switch to {name} dashboard",
                )


# ── Main app ──────────────────────────────────────────────────────────────────

class DashboardApp(App):
    TITLE = "Exec Dashboard"
    COMMANDS = {DashboardCommands}

    CSS = """
    #buttons {
        height: auto;
        layout: grid;
        grid-size: 4;
        grid-gutter: 1;
        padding: 1;
    }
    """

    def __init__(self, config: Config) -> None:
        super().__init__()
        self.config = config
        self._active_dashboard: str = (
            config.dashboards[0].name if config.dashboards else "All"
        )

    # ── Layout ────────────────────────────────────────────────────────────────

    def compose(self) -> ComposeResult:
        yield Header()
        with ScrollableContainer(id="buttons"):
            yield from self._build_buttons(self._active_dashboard)
        yield LogPanel()
        yield Footer()

    def _exe_map(self) -> dict[str, Executable]:
        return {exe.id: exe for exe in self.config.executables}

    def _exe_ids_for(self, dashboard_name: str) -> list[str]:
        if dashboard_name == "All":
            return [exe.id for exe in self.config.executables]
        for d in self.config.dashboards:
            if d.name == dashboard_name:
                return d.executables
        return []

    def _build_buttons(self, dashboard_name: str):
        exe_map = self._exe_map()
        for exe_id in self._exe_ids_for(dashboard_name):
            exe = exe_map.get(exe_id)
            if exe:
                yield Button(exe.name, id=f"exe_{exe.id}")

    # ── Dashboard switching ───────────────────────────────────────────────────

    def switch_dashboard(self, name: str) -> None:
        self._active_dashboard = name
        self.sub_title = name
        container = self.query_one("#buttons", ScrollableContainer)
        container.remove_children()
        for btn in self._build_buttons(name):
            container.mount(btn)

    # ── Button press → run ────────────────────────────────────────────────────

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        btn_id = event.button.id or ""
        if not btn_id.startswith("exe_"):
            return
        exe_id = btn_id[4:]
        exe = self._exe_map().get(exe_id)
        if exe is None:
            return

        if exe.args:
            values = await self.push_screen_wait(ParamModal(exe))
            if values is None:
                return   # cancelled
        else:
            values = {}

        asyncio.create_task(self._run(exe, values))

    async def _run(self, exe: Executable, values: dict[str, object]) -> None:
        log = self.query_one(LogPanel)
        log.begin_run(exe.name)
        async for kind, payload in run_executable(exe, values):
            if kind == "stdout":
                log.append_line(payload)
            elif kind == "exit":
                log.end_run(payload)
```

**Step 2: Implement entrypoint**

```python
# dashboard/__main__.py
from __future__ import annotations
import argparse
from pathlib import Path
from dashboard.app import DashboardApp
from dashboard.config import load_config_file


def main() -> None:
    parser = argparse.ArgumentParser(description="Exec Dashboard")
    parser.add_argument(
        "--config", type=Path, default=Path("dashboard.yaml"),
        help="Path to dashboard YAML config (default: dashboard.yaml)"
    )
    args = parser.parse_args()
    config = load_config_file(args.config)
    DashboardApp(config).run()


if __name__ == "__main__":
    main()
```

**Step 3: Commit**

```bash
git add dashboard/app.py dashboard/__main__.py
git commit -m "feat: main Textual app with button grid, log panel, command palette"
```

---

## Task 9: Example Config

**Files:**
- Create: `dashboard.yaml`

**Step 1: Write example config**

```yaml
# dashboard.yaml — example config, edit freely
executables:
  - id: echo-hello
    name: Echo Hello
    path: /bin/echo
    args:
      - name: message
        positional: true
        type: str
        nargs: 1

  - id: list-files
    name: List Files
    path: /bin/ls
    args:
      - name: path
        positional: true
        type: pathlib.Path
        nargs: 1
      - name: long
        positional: false
        type: bool
        nargs: 0
        parameter: "-l"
      - name: all
        positional: false
        type: bool
        nargs: 0
        parameter: "-a"

  - id: show-date
    name: Show Date
    path: /usr/bin/date

  - id: disk-usage
    name: Disk Usage
    path: /usr/bin/du
    args:
      - name: path
        positional: true
        type: pathlib.Path
        nargs: 1
      - name: human-readable
        positional: false
        type: bool
        nargs: 0
        parameter: "-h"

dashboards:
  - name: System Tools
    executables: [show-date, list-files, disk-usage]

  - name: Quick Tests
    executables: [echo-hello, show-date]
```

**Step 2: Smoke test**

```bash
python -m dashboard --config dashboard.yaml
```

Expected: Textual UI launches, buttons visible, `^P` opens command palette with "All", "System Tools", "Quick Tests".

- Press "Show Date" → output appears in log
- Press "Echo Hello" → param modal appears → type a message → Run → output appears
- Press "List Files" → modal appears → type `/tmp` → check Long → Run → output appears
- `^P` → type "Quick" → select "Quick Tests" → button grid updates

**Step 3: Commit**

```bash
git add dashboard.yaml
git commit -m "chore: add example dashboard.yaml config"
```

---

## Task 10: Run Full Test Suite

**Step 1: Run all tests**

```bash
pytest tests/ -v
```

Expected: all pass.

**Step 2: If failures exist** — fix before proceeding.

**Step 3: Final commit if any fixes made**

```bash
git add -p
git commit -m "fix: address test failures found in full suite run"
```
