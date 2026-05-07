from __future__ import annotations
from typing import Any, ClassVar, Callable
from pathlib import Path
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.command import DiscoveryHit, Provider, Hit, Hits
from textual.events import Key
from textual.widgets import Button, Header, Footer
from textual.containers import ScrollableContainer
from dashboard.config import Config, Executable
from dashboard.widgets.log_panel import LogPanel
from dashboard.widgets.param_modal import ParamModal
from dashboard.widgets.dashboard_switcher import DashboardSwitcher
from dashboard.runner import run_executable
from dashboard.usage import UsageTracker


class DashboardCommands(Provider):
    """Command palette: Sort by mode and Switch to dashboard."""

    async def discover(self) -> Hits:
        """Show all commands before the user types anything."""
        app: DashboardApp = self.app  # type: ignore[assignment]
        for mode in app.SORT_MODES:
            yield DiscoveryHit(
                command=lambda m=mode: app.set_sort(m),
                display=f"Sort: {mode}",
                help=f"Sort current dashboard by {mode}",
            )
        names = ["All"] + [d.name for d in app.config.dashboards]
        for name in names:
            yield DiscoveryHit(
                command=lambda n=name: app.switch_dashboard(n),
                display=f"Switch: {name}",
                help=f"Switch to {name} dashboard",
            )

    async def search(self, query: str) -> Hits:
        app: DashboardApp = self.app  # type: ignore[assignment]
        q = query.lower()

        # Sort commands — one per SORT_MODES key
        for mode in app.SORT_MODES:
            label = f"Sort: {mode}"
            if not q or q in label.lower():
                yield Hit(
                    score=1.0,
                    match_display=label,
                    command=lambda m=mode: app.set_sort(m),
                    help=f"Sort current dashboard by {mode}",
                )

        # Switch commands — All + named dashboards
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


class DashboardApp(App):
    TITLE = "Exec Dashboard"
    COMMANDS = {DashboardCommands}
    BINDINGS = [Binding("ctrl+d", "open_switcher", "Dashboards", show=True)]

    SORT_MODES: ClassVar[dict[str, Callable[[str, UsageTracker], Any]]] = {
        "config": lambda exe_id, tracker: 0,
        "usage": lambda exe_id, tracker: -tracker.count(exe_id),
    }

    CSS = """
    #buttons {
        height: auto;
        layout: grid;
        grid-size: 4;
        grid-gutter: 1;
        padding: 1;
    }
    Button:focus {
        text-style: bold;
        background: $accent-darken-1;
    }
    """

    def __init__(self, config: Config, config_path: Path) -> None:
        super().__init__()
        self.config = config
        self._tracker = UsageTracker(config_path.parent / "usage.json")
        self._active_sort: dict[str, str] = {}
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

    GRID_COLS = 4  # must match grid-size in CSS

    def on_key(self, event: Key) -> None:
        if event.key not in ("up", "down", "left", "right"):
            return
        buttons = list(self.query("#buttons Button"))
        if not buttons:
            return
        if self.focused not in buttons:
            buttons[0].focus()
            event.prevent_default()
            return
        idx = buttons.index(self.focused)
        if event.key == "right":
            idx = min(idx + 1, len(buttons) - 1)
        elif event.key == "left":
            idx = max(idx - 1, 0)
        elif event.key == "down":
            idx = min(idx + self.GRID_COLS, len(buttons) - 1)
        elif event.key == "up":
            idx = max(idx - self.GRID_COLS, 0)
        buttons[idx].focus()
        event.prevent_default()

    def _exe_map(self) -> dict[str, Executable]:
        return {exe.id: exe for exe in self.config.executables}

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
        # fall back to "config" if mode is unrecognised
        key_fn = self.SORT_MODES.get(mode, self.SORT_MODES["config"])
        return sorted(ids, key=lambda i: key_fn(i, self._tracker))

    def _build_buttons(self, dashboard_name: str):
        exe_map = self._exe_map()
        for exe_id in self._exe_ids_for(dashboard_name):
            exe = exe_map.get(exe_id)
            if exe:
                yield Button(exe.name, id=f"exe_{exe.id}")

    # ── Dashboard switching ───────────────────────────────────────────────────

    def action_open_switcher(self) -> None:
        names = ["All"] + [d.name for d in self.config.dashboards]
        self.push_screen(DashboardSwitcher(names), self._on_switcher_result)

    def _on_switcher_result(self, name: str | None) -> None:
        if name is not None:
            self.run_worker(self.switch_dashboard(name))

    def set_sort(self, mode: str) -> None:
        self._active_sort[self._active_dashboard] = mode
        self.run_worker(self.switch_dashboard(self._active_dashboard))

    async def switch_dashboard(self, name: str) -> None:
        self._active_dashboard = name
        self.sub_title = name
        container = self.query_one("#buttons", ScrollableContainer)
        await container.remove_children()
        await container.mount(*list(self._build_buttons(name)))

    # ── Button press → run ────────────────────────────────────────────────────

    def on_button_pressed(self, event: Button.Pressed) -> None:
        btn_id = event.button.id or ""
        if not btn_id.startswith("exe_"):
            return
        exe_id = btn_id[4:]
        exe = self._exe_map().get(exe_id)
        if exe is None:
            return
        self.run_worker(self._handle_exe(exe), exclusive=False)

    async def _handle_exe(self, exe: Executable) -> None:
        """Runs inside a worker so push_screen_wait and subprocess are both safe."""
        if exe.args:
            values = await self.push_screen_wait(ParamModal(exe))
            if values is None:
                return  # cancelled — don't count as a run
        else:
            values = {}
        self._tracker.increment(exe.id)
        log = self.query_one(LogPanel)
        log.begin_run(exe.name)
        async for kind, payload in run_executable(exe, values):
            if kind == "stdout":
                log.append_line(payload)
            elif kind == "exit":
                log.end_run(payload)
