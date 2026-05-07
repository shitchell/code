# Sort Modes + Command Palette Design

## Overview

Three interrelated additions:

1. **`default_sort` on dashboards** — `"config"` (default) or `"usage"`
2. **`UsageTracker`** — persists button press counts to `usage.json`; sort logic lives on `DashboardApp`
3. **Command palette restored (`^P`)** — real commands: Sort and Switch; dashboard switcher moves to `ctrl+d`

---

## Config Schema

```yaml
dashboards:
  - name: System Tools
    default_sort: usage        # optional; defaults to "config"
    executables: [show-date, list-files, disk-usage]
```

`Dashboard.default_sort: str = "config"` — new field, parsed by `load_config`.

---

## UsageTracker

`dashboard/usage.py` — tracks counts only, no sort logic.

```python
class UsageTracker:
    def __init__(self, path: Path) -> None: ...   # loads usage.json; creates empty if missing
    def increment(self, exe_id: str) -> None: ... # +1 and save
    def count(self, exe_id: str) -> int: ...      # → count for exe_id (0 if unseen)
```

Storage: `usage.json` in the same directory as the config file.
Format: `{"exe_id": count, ...}`

---

## Sort Modes

`DashboardApp.SORT_MODES` — class-level registry, extensible:

```python
SORT_MODES: ClassVar[dict[str, Callable[[str, UsageTracker], Any]]] = {
    "config": lambda exe_id, tracker: 0,
    "usage":  lambda exe_id, tracker: -tracker.count(exe_id),
}
```

Applied in `_exe_ids_for()`:

```python
def _exe_ids_for(self, dashboard_name: str) -> list[str]:
    ...
    mode = self._active_sort.get(dashboard_name) or dashboard.default_sort
    return sorted(ids, key=lambda i: self.SORT_MODES[mode](i, self._tracker))
```

`_active_sort: dict[str, str]` — session-only overrides; keyed by dashboard name.

---

## Command Palette

`DashboardCommands(Provider)` restored in `COMMANDS`. Yields:

- **Sort commands** — one per `SORT_MODES` key, prefixed `"Sort: "`:
  `Sort: config`, `Sort: usage`
  → sets `_active_sort[active_dashboard] = mode`, rebuilds buttons

- **Switch commands** — one per dashboard (+ All), prefixed `"Switch: "`:
  `Switch: All`, `Switch: System Tools`, ...
  → calls `switch_dashboard(name)`

---

## Key Bindings

| Key | Action |
|-----|--------|
| `^P` | Command palette (Sort + Switch commands) |
| `ctrl+d` | Dashboard switcher modal (browse + filter) |

---

## Data Flow

```
Button pressed
    → tracker.increment(exe_id)
    → save usage.json
    → handle exe (modal → run)

Sort command selected via ^P
    → _active_sort[dashboard] = mode
    → rebuild button grid with new sort

Dashboard switched (^P or ctrl+d)
    → _active_dashboard = name
    → rebuild buttons using active sort mode for new dashboard
```

---

## Files

| File | Change |
|------|--------|
| `dashboard/usage.py` | New — `UsageTracker` |
| `dashboard/config.py` | Add `default_sort` to `Dashboard` dataclass + parsing |
| `dashboard/app.py` | Add `SORT_MODES`, `_active_sort`, `_tracker`; restore `COMMANDS`; rebind `ctrl+d` |
| `dashboard.yaml` | Add `default_sort: usage` to one dashboard as example |
| `tests/test_usage.py` | New — `UsageTracker` unit tests |
| `tests/test_config.py` | Add `default_sort` parsing tests |
