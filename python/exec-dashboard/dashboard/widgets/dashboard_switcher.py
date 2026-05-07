from __future__ import annotations
from textual import on
from textual.app import ComposeResult
from textual.screen import ModalScreen
from textual.widgets import Input, Label, ListItem, ListView
from textual.containers import Vertical


class _DashItem(ListItem):
    """ListItem that carries the dashboard name as an attribute."""

    def __init__(self, name: str) -> None:
        super().__init__(Label(name))
        self.dash_name = name


class DashboardSwitcher(ModalScreen[str | None]):
    """Show all dashboards immediately; filter as you type; dismiss with selection."""

    BINDINGS = [("escape", "cancel", "Cancel")]

    DEFAULT_CSS = """
    DashboardSwitcher {
        align: center middle;
    }
    DashboardSwitcher > Vertical {
        width: 50;
        height: auto;
        max-height: 24;
        background: $surface;
        border: solid $accent;
        padding: 1 2;
    }
    DashboardSwitcher #title {
        text-style: bold;
        margin-bottom: 1;
    }
    DashboardSwitcher #filter {
        margin-bottom: 1;
    }
    DashboardSwitcher ListView {
        height: auto;
        max-height: 16;
    }
    """

    def __init__(self, names: list[str]) -> None:
        super().__init__()
        self._names = names

    def compose(self) -> ComposeResult:
        with Vertical():
            yield Label("Switch Dashboard", id="title")
            yield Input(placeholder="Filter...", id="filter")
            yield ListView(*[_DashItem(name) for name in self._names])

    def on_mount(self) -> None:
        self.query_one(Input).focus()

    @on(Input.Changed)
    def on_filter(self, event: Input.Changed) -> None:
        q = event.value.strip().lower()
        for item in self.query(_DashItem):
            item.display = not q or q in item.dash_name.lower()

    @on(ListView.Selected)
    def on_selected(self, event: ListView.Selected) -> None:
        if isinstance(event.item, _DashItem):
            self.dismiss(event.item.dash_name)

    def action_cancel(self) -> None:
        self.dismiss(None)
