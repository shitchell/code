# Sort Modes + Command Palette Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add usage-based sort modes to dashboards, persist click counts to JSON, restore the command palette with Sort/Switch commands, and move the dashboard switcher to `ctrl+d`.

**Architecture:** `UsageTracker` (new `dashboard/usage.py`) handles count persistence; sort logic lives as `SORT_MODES` on `DashboardApp`; `DashboardCommands` provider is restored to `COMMANDS` yielding Sort + Switch commands; `ctrl+d` opens the dashboard switcher.

**Tech Stack:** Python 3.11+, Textual 0.83, PyYAML, stdlib `json`

**Worktree:** `.worktrees/feature-initial-build/python/exec-dashboard` (branch `feature/initial-build`)

**Design doc:** `docs/plans/2026-05-07-sort-and-palette-design.md`

---

## Task 1: UsageTracker

**Files:**
- Create: `dashboard/usage.py`
- Create: `tests/test_usage.py`

**Step 1: Write failing tests**

```python
# tests/test_usage.py
from pathlib import Path
from dashboard.usage import UsageTracker


def test_count_unseen_returns_zero(tmp_path):
    t = UsageTracker(tmp_path / "usage.json")
    assert t.count("foo") == 0


def test_increment_and_count(tmp_path):
    t = UsageTracker(tmp_path / "usage.json")
    t.increment("foo")
    t.increment("foo")
    assert t.count("foo") == 2


def test_persists_across_instances(tmp_path):
    path = tmp_path / "usage.json"
    t1 = UsageTracker(path)
    t1.increment("foo")
    t2 = UsageTracker(path)
    assert t2.count("foo") == 1


def test_missing_file_creates_empty(tmp_path):
    path = tmp_path / "usage.json"
    t = UsageTracker(path)
    assert t.count("anything") == 0
    assert not path.exists()   # file not written until first increment


def test_increment_creates_file(tmp_path):
    path = tmp_path / "usage.json"
    t = UsageTracker(path)
    t.increment("bar")
    assert path.exists()
```

**Step 2: Run to verify failure**

```bash
pytest tests/test_usage.py -v
```

Expected: `ImportError` — module doesn't exist.

**Step 3: Implement `dashboard/usage.py`**

```python
from __future__ import annotations
import json
from pathlib import Path


class UsageTracker:
    """Persist per-executable button-press counts to a JSON file."""

    def __init__(self, path: Path) -> None:
        self._path = path
        self._counts: dict[str, int] = {}
        if path.exists():
            with open(path) as f:
                self._counts = json.load(f)

    def count(self, exe_id: str) -> int:
        return self._counts.get(exe_id, 0)

    def increment(self, exe_id: str) -> None:
        self._counts[exe_id] = self._counts.get(exe_id, 0) + 1
        with open(self._path, "w") as f:
            json.dump(self._counts, f)
```

**Step 4: Run tests**

```bash
pytest tests/test_usage.py -v
```

Expected: all 5 pass.

**Step 5: Commit**

```bash
git add dashboard/usage.py tests/test_usage.py
git commit -m "feat: UsageTracker persists button press counts to JSON"
```

---

## Task 2: Dashboard.default_sort config field

**Files:**
- Modify: `dashboard/config.py`
- Modify: `tests/test_config.py`

**Step 1: Write failing tests**

Add to `tests/test_config.py`:

```python
def test_dashboard_default_sort_defaults_to_config():
    d = Dashboard(name="Dev", executables=["foo"])
    assert d.default_sort == "config"


def test_load_config_dashboard_default_sort():
    import yaml, textwrap
    data = yaml.safe_load(textwrap.dedent("""
        executables:
          - id: foo
            name: Foo
            path: /bin/foo
        dashboards:
          - name: Dev
            executables: [foo]
            default_sort: usage
    """))
    from dashboard.config import load_config
    config = load_config(data)
    assert config.dashboards[0].default_sort == "usage"


def test_load_config_dashboard_sort_default_omitted():
    import yaml, textwrap
    data = yaml.safe_load(textwrap.dedent("""
        executables:
          - id: foo
            name: Foo
            path: /bin/foo
        dashboards:
          - name: Dev
            executables: [foo]
    """))
    from dashboard.config import load_config
    config = load_config(data)
    assert config.dashboards[0].default_sort == "config"
```

**Step 2: Run to verify failure**

```bash
pytest tests/test_config.py -v -k "sort"
```

Expected: `AttributeError` — `Dashboard` has no `default_sort`.

**Step 3: Add `default_sort` to `Dashboard` and `load_config`**

In `dashboard/config.py`, change the `Dashboard` dataclass:

```python
@dataclass
class Dashboard:
    name: str
    executables: list[str]   # executable ids
    default_sort: str = "config"
```

In `load_config`, change the dashboard list comprehension:

```python
    dashboards = [
        Dashboard(
            name=d["name"],
            executables=d.get("executables", []),
            default_sort=d.get("default_sort", "config"),
        )
        for d in data.get("dashboards", [])
    ]
```

**Step 4: Run all tests**

```bash
pytest tests/ -v
```

Expected: all pass (existing + 3 new).

**Step 5: Commit**

```bash
git add dashboard/config.py tests/test_config.py
git commit -m "feat: Dashboard.default_sort field with config/usage values"
```

---

## Task 3: SORT_MODES on DashboardApp + sort wired into button grid

**Files:**
- Modify: `dashboard/app.py`

**Context:** `DashboardApp._exe_ids_for()` currently returns ids in config order. This task adds `SORT_MODES`, `_active_sort`, and `_tracker` to the app, and wires sorting into `_exe_ids_for()`. No tests for Textual app internals — verified by smoke test in Task 5.

**Step 1: Add imports to `dashboard/app.py`**

Add at top:
```python
from typing import Any, ClassVar, Callable
from dashboard.usage import UsageTracker
```

**Step 2: Add class-level attributes to `DashboardApp`**

```python
class DashboardApp(App):
    TITLE = "Exec Dashboard"
    COMMANDS = set()

    SORT_MODES: ClassVar[dict[str, Callable[[str, UsageTracker], Any]]] = {
        "config": lambda exe_id, tracker: 0,
        "usage":  lambda exe_id, tracker: -tracker.count(exe_id),
    }
```

**Step 3: Update `__init__` to accept config path and init tracker**

Change `__init__` signature and body:

```python
    def __init__(self, config: Config, config_path: Path) -> None:
        super().__init__()
        self.config = config
        self._tracker = UsageTracker(config_path.parent / "usage.json")
        self._active_sort: dict[str, str] = {}
        self._active_dashboard: str = (
            config.dashboards[0].name if config.dashboards else "All"
        )
```

**Step 4: Wire sorting into `_exe_ids_for`**

```python
    def _exe_ids_for(self, dashboard_name: str) -> list[str]:
        if dashboard_name == "All":
            ids = [exe.id for exe in self.config.executables]
            default_sort = "config"
        else:
            dashboard = next(
                (d for d in self.config.dashboards if d.name == dashboard_name), None
            )
            if dashboard is None:
                return []
            ids = dashboard.executables
            default_sort = dashboard.default_sort

        mode = self._active_sort.get(dashboard_name, default_sort)
        return sorted(ids, key=lambda i: self.SORT_MODES[mode](i, self._tracker))
```

**Step 5: Track usage on button press**

In `on_button_pressed`, add tracker increment after resolving the exe:

```python
    def on_button_pressed(self, event: Button.Pressed) -> None:
        btn_id = event.button.id or ""
        if not btn_id.startswith("exe_"):
            return
        exe_id = btn_id[4:]
        exe = self._exe_map().get(exe_id)
        if exe is None:
            return
        self._tracker.increment(exe_id)
        self.run_worker(self._handle_exe(exe), exclusive=False)
```

**Step 6: Update `__main__.py` to pass `config_path`**

In `dashboard/__main__.py`, change the `DashboardApp(config)` call:

```python
    DashboardApp(config, args.config).run()
```

**Step 7: Verify imports clean**

```bash
python -c "from dashboard.app import DashboardApp; print('OK')"
python -c "from dashboard.__main__ import main; print('OK')"
```

**Step 8: Run all tests**

```bash
pytest tests/ -v
```

Expected: all pass.

**Step 9: Commit**

```bash
git add dashboard/app.py dashboard/__main__.py
git commit -m "feat: SORT_MODES on DashboardApp, usage tracking on button press, sort wired into button grid"
```

---

## Task 4: Restore command palette with Sort + Switch commands

**Files:**
- Modify: `dashboard/app.py`

**Context:** Restore `DashboardCommands(Provider)` in `COMMANDS`. It yields Sort commands (one per `SORT_MODES` key) and Switch commands (one per dashboard + All). Selecting Sort sets `_active_sort` and rebuilds buttons; selecting Switch calls `switch_dashboard`.

**Step 1: Add provider import**

In `dashboard/app.py`:
```python
from textual.command import Provider, Hit, Hits
```

**Step 2: Add `DashboardCommands` class above `DashboardApp`**

```python
class DashboardCommands(Provider):
    """Command palette: Sort and Switch commands."""

    async def search(self, query: str) -> Hits:
        app: DashboardApp = self.app  # type: ignore[assignment]
        q = query.lower()

        # Sort commands
        for mode in app.SORT_MODES:
            label = f"Sort: {mode}"
            if not q or q in label.lower():
                yield Hit(
                    score=1.0,
                    match_display=label,
                    command=lambda m=mode: app.set_sort(m),
                    help=f"Sort current dashboard by {mode}",
                )

        # Switch commands
        names = ["All"] + [d.name for d in app.config.dashboards]
        for name in names:
            label = f"Switch: {name}"
            if not q or q in label.lower():
                yield Hit(
                    score=0.9,
                    match_display=label,
                    command=lambda n=name: app.switch_dashboard(n),
                    help=f"Switch to {name} dashboard",
                )
```

**Step 3: Update `DashboardApp`**

Replace `COMMANDS = set()` with:
```python
    COMMANDS = {DashboardCommands}
```

Add `action_command_palette` override removed (it's no longer needed — Textual's default will run with our provider). Remove the `action_command_palette` method entirely.

Add `set_sort` method:
```python
    def set_sort(self, mode: str) -> None:
        self._active_sort[self._active_dashboard] = mode
        self.run_worker(self.switch_dashboard(self._active_dashboard))
```

**Step 4: Verify import**

```bash
python -c "from dashboard.app import DashboardApp, DashboardCommands; print('OK')"
```

**Step 5: Run all tests**

```bash
pytest tests/ -v
```

Expected: all pass.

**Step 6: Commit**

```bash
git add dashboard/app.py
git commit -m "feat: restore command palette with Sort and Switch commands"
```

---

## Task 5: Move dashboard switcher to ctrl+d

**Files:**
- Modify: `dashboard/app.py`

**Context:** `action_command_palette` was overriding `^P` — now removed. Add `ctrl+d` binding for the dashboard switcher instead.

**Step 1: Add binding**

In `DashboardApp`:

```python
    BINDINGS = [Binding("ctrl+d", "open_switcher", "Dashboards", show=True)]

    def action_open_switcher(self) -> None:
        names = ["All"] + [d.name for d in self.config.dashboards]
        self.push_screen(DashboardSwitcher(names), self._on_switcher_result)
```

**Step 2: Verify import**

```bash
python -c "from dashboard.app import DashboardApp; print('OK')"
```

**Step 3: Run all tests**

```bash
pytest tests/ -v
```

Expected: all pass.

**Step 4: Commit**

```bash
git add dashboard/app.py
git commit -m "feat: ctrl+d opens dashboard switcher, ^P restored for command palette"
```

---

## Task 6: Update example config

**Files:**
- Modify: `dashboard.yaml`

**Step 1: Add `default_sort: usage` to one dashboard**

```yaml
  - name: Quick Tests
    default_sort: usage
    executables: [echo-hello, show-date]
```

**Step 2: Verify parse**

```bash
python -c "
from dashboard.config import load_config_file
from pathlib import Path
config = load_config_file(Path('dashboard.yaml'))
for d in config.dashboards:
    print(d.name, '->', d.default_sort)
"
```

Expected:
```
System Tools -> config
Quick Tests -> usage
File Ops -> config
```

**Step 3: Commit**

```bash
git add dashboard.yaml
git commit -m "chore: add default_sort: usage to Quick Tests dashboard in example"
```

---

## Task 7: Full test suite

**Step 1: Run all tests**

```bash
pytest tests/ -v
```

Expected: all pass (26 tests: 12 config + 9 runner + 5 usage).

**Step 2: Fix any failures before proceeding.**

**Step 3: Commit if fixes needed**

```bash
git add -p
git commit -m "fix: address failures in full suite run"
```
