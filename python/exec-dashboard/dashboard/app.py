from __future__ import annotations
from textual.app import App, ComposeResult
from textual.command import Provider, Hit, Hits
from textual.widgets import Button, Header, Footer
from textual.containers import ScrollableContainer
from dashboard.config import Config, Executable
from dashboard.widgets.log_panel import LogPanel
from dashboard.widgets.param_modal import ParamModal
from dashboard.runner import run_executable


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

    async def switch_dashboard(self, name: str) -> None:
        self._active_dashboard = name
        self.sub_title = name
        container = self.query_one("#buttons", ScrollableContainer)
        await container.remove_children()
        await container.mount(*list(self._build_buttons(name)))

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
                return
        else:
            values = {}

        self.run_worker(self._run(exe, values), exclusive=False)

    async def _run(self, exe: Executable, values: dict[str, object]) -> None:
        log = self.query_one(LogPanel)
        log.begin_run(exe.name)
        async for kind, payload in run_executable(exe, values):
            if kind == "stdout":
                log.append_line(payload)
            elif kind == "exit":
                log.end_run(payload)
