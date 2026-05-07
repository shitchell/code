from __future__ import annotations
from pathlib import Path
from textual import on
from textual.app import ComposeResult
from textual.screen import ModalScreen
from textual.widgets import Button, Checkbox, Input, Label, Static
from textual.containers import Vertical, Horizontal
from dashboard.config import Executable


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
