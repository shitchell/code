# Exec Dashboard — Design

## Overview

A Textual TUI button dashboard for running executables. Press a button, fill in any
typed parameters, see streaming output in a shared log panel. Dashboards are defined
in YAML; switch between them via the `^P` command palette.

---

## Directory Layout

```
exec-dashboard/
├── dashboard/
│   ├── __init__.py
│   ├── app.py              # Textual App + layout
│   ├── config.py           # YAML parsing + dataclasses
│   ├── runner.py           # async subprocess
│   └── widgets/
│       ├── param_modal.py  # arg input form (ModalScreen)
│       └── log_panel.py    # shared output area (RichLog)
├── dashboard.yaml          # user's config
└── pyproject.toml
```

Entrypoint: `python -m dashboard [--config PATH]` (defaults to `dashboard.yaml` in cwd).

---

## YAML Schema

```yaml
executables:
  - id: convert-image
    name: Convert Image
    path: /usr/bin/convert
    args:
      - name: input
        positional: true
        type: pathlib.Path
        nargs: 1
      - name: output
        positional: true
        type: pathlib.Path
        nargs: 1
      - name: quality
        positional: false
        type: int
        nargs: 1
        # parameter auto-derives to "--quality"
      - name: verbose
        positional: false
        type: bool
        nargs: 0      # flag only, no value
        parameter: "-v"

  - id: run-tests
    name: Run Tests
    path: pytest
    args: []

dashboards:
  - name: Dev & Testing
    executables: [run-tests, convert-image]

  - name: Code Review
    executables: [lint, run-tests]
```

### Parameter auto-derivation

If `parameter` is omitted:
- `len(name) == 1` → `-{name}`
- otherwise → `--{name}`

### Supported types

| YAML value      | Python type | Widget         |
|-----------------|-------------|----------------|
| `str`           | `str`       | `Input`        |
| `int`           | `int`       | `Input`        |
| `float`         | `float`     | `Input`        |
| `bool`          | `bool`      | `Checkbox`     |
| `pathlib.Path`  | `Path`      | `Input` + browse button → `DirectoryTree` |

### `nargs`

| Value | Meaning                        |
|-------|--------------------------------|
| `0`   | flag only (bool/switch)        |
| `1`   | exactly one value (default)    |
| `"*"` | zero or more                   |
| `"+"` | one or more                    |

---

## Config Dataclasses

```python
@dataclass
class Arg:
    name: str
    positional: bool = False
    parameter: str | None = None   # auto-derived if None
    type: str = "str"              # resolved via TYPE_MAP
    nargs: int | str = 1

@dataclass
class Executable:
    id: str
    name: str
    path: str
    args: list[Arg] = field(default_factory=list)

@dataclass
class Dashboard:
    name: str
    executables: list[str]         # list of executable ids

@dataclass
class Config:
    executables: list[Executable]
    dashboards: list[Dashboard]
```

`TYPE_MAP = {"str": str, "int": int, "float": float, "bool": bool, "pathlib.Path": Path}`

An implicit **"All"** dashboard is always available in the command palette — contains
every executable in definition order, no config needed.

---

## UI Layout

```
┌─────────────────────────────────────────┐
│ ⚡ Dev & Testing              [^P menu] │  ← header w/ current dashboard name
├─────────────────────────────────────────┤
│  [Run Tests]  [Lint]  [Convert Image]   │  ← button grid (wraps automatically)
├─────────────────────────────────────────┤
│ ▼ OUTPUT ─────────────────────────────  │
│ [12:04:01] Run Tests                    │  ← shared RichLog panel
│ pytest collected 42 items               │
│ ...................................     │
│ 42 passed in 3.2s                       │
│ ✓ exited 0                              │
│                                         │
│ [12:05:11] Lint ──────────────────────  │
│ All good!                               │
│ ✓ exited 0                              │
└─────────────────────────────────────────┘
```

### Widgets

- **Button grid** — `Grid` of `Button` widgets, wraps automatically
- **Param modal** — `ModalScreen` with a typed form per arg; validation errors shown inline
- **Log panel** — `RichLog`; each run gets a styled header + footer with exit code
- **Command palette** — extends Textual's built-in `CommandPalette`; dashboard names
  are registered as commands, selecting one switches the button grid

---

## Data Flow

```
Button pressed
    │
    ├─ has args? ──yes──► show ParamModal ──► user fills form ──► submit
    │                                                                │
    └─ no args ───────────────────────────────────────────────────►─┘
                                                                     │
                                                            build argv list
                                                                     │
                                                asyncio.create_subprocess_exec()
                                                                     │
                                               stream stdout+stderr line by line
                                                                     │
                                                    post_message() → RichLog
```

### Subprocess details

- `asyncio.create_subprocess_exec` (not `shell=True`) — argv passed directly
- stdout + stderr merged via `stderr=STDOUT` — preserves interleaved order
- Non-blocking — multiple buttons can run concurrently, each gets its own log section
- Exit code shown as `✓ exited 0` or `✗ exited 1` in run footer

### Argv construction

1. Positional args appended in declaration order
2. Non-positional flags:
   - `nargs: 0` → `["-v"]`
   - `nargs: 1` → `["--quality", "85"]`
   - `nargs: "*"/"+"` → `["--files", "a.txt", "b.txt"]`
3. Type conversion applied before subprocess call; failure shown in modal inline
