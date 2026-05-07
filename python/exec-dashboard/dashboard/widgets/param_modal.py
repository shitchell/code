from __future__ import annotations
from pathlib import Path
from textual import on
from textual.app import ComposeResult
from textual.screen import ModalScreen
from textual.widgets import Button, Checkbox, Input, Label, Static
from textual.containers import Vertical, Horizontal
from dashboard.config import Executable
from dashboard.widgets.file_picker import FilePickerModal


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
    ParamModal .path-row {
        height: auto;
    }
    ParamModal .path-row Input {
        width: 1fr;
    }
    ParamModal .path-row Button {
        width: auto;
        min-width: 10;
        margin-left: 1;
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
                    if arg.nargs == 0:
                        label_text = arg.name
                    elif arg.required:
                        label_text = f"{arg.name} [bold red]*[/bold red]"
                    else:
                        label_text = f"{arg.name} [dim](optional)[/dim]"
                    yield Label(label_text, markup=True)
                    if arg.nargs == 0:
                        yield Checkbox(arg.name, id=f"arg_{arg.name}")
                    elif arg.python_type is Path:
                        with Horizontal(classes="path-row"):
                            yield Input(
                                placeholder="path",
                                id=f"arg_{arg.name}",
                            )
                            yield Button("Browse", id=f"browse_{arg.name}")
                    else:
                        yield Input(
                            placeholder=f"{arg.type} {'(positional)' if arg.positional else arg.derived_parameter}",
                            id=f"arg_{arg.name}",
                        )
            with Horizontal(classes="actions"):
                yield Button("Run", variant="primary", id="run")
                yield Button("Cancel", id="cancel")

    @on(Button.Pressed)
    async def on_button_pressed(self, event: Button.Pressed) -> None:
        btn_id = event.button.id or ""

        if btn_id.startswith("browse_"):
            arg_name = btn_id[len("browse_"):]
            input_widget = self.query_one(f"#arg_{arg_name}", Input)
            start = Path(input_widget.value).expanduser() if input_widget.value else None
            picked = await self.app.push_screen_wait(FilePickerModal(start=start))
            if picked is not None:
                input_widget.value = str(picked)

        elif btn_id == "run":
            self._submit()

        elif btn_id == "cancel":
            self.dismiss(None)

    def _submit(self) -> None:
        values: dict[str, object] = {}
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
                self.notify(
                    f"Invalid value for '{arg.name}': expected {arg.type}",
                    severity="error",
                )
                return
        self.dismiss(values)
