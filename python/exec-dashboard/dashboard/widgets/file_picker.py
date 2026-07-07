from __future__ import annotations
from pathlib import Path
from textual import on
from textual.app import ComposeResult
from textual.screen import ModalScreen
from textual.widgets import Button, DirectoryTree, Label
from textual.containers import Vertical, Horizontal


class FilePickerModal(ModalScreen[Path | None]):
    """Browse the filesystem and return a selected path."""

    DEFAULT_CSS = """
    FilePickerModal {
        align: center middle;
    }
    FilePickerModal > Vertical {
        width: 70;
        height: 30;
        background: $surface;
        border: solid $accent;
        padding: 1 2;
    }
    FilePickerModal DirectoryTree {
        height: 1fr;
    }
    FilePickerModal #selected-label {
        height: 1;
        color: $text-muted;
    }
    FilePickerModal .actions {
        height: auto;
        margin-top: 1;
    }
    """

    def __init__(self, start: Path | None = None) -> None:
        super().__init__()
        self._start = start or Path.home()
        self._selected: Path | None = None

    def compose(self) -> ComposeResult:
        with Vertical():
            yield Label("Select a file or directory:", id="picker-title")
            yield DirectoryTree(str(self._start))
            yield Label("", id="selected-label")
            with Horizontal(classes="actions"):
                yield Button("Select", variant="primary", id="select", disabled=True)
                yield Button("Cancel", id="fp-cancel")

    @on(DirectoryTree.FileSelected)
    def on_file_selected(self, event: DirectoryTree.FileSelected) -> None:
        self._selected = Path(event.path)
        self.query_one("#selected-label", Label).update(str(self._selected))
        self.query_one("#select", Button).disabled = False

    @on(DirectoryTree.DirectorySelected)
    def on_directory_selected(self, event: DirectoryTree.DirectorySelected) -> None:
        self._selected = Path(event.path)
        self.query_one("#selected-label", Label).update(str(self._selected))
        self.query_one("#select", Button).disabled = False

    @on(Button.Pressed, "#select")
    def on_select(self) -> None:
        self.dismiss(self._selected)

    @on(Button.Pressed, "#fp-cancel")
    def on_cancel(self) -> None:
        self.dismiss(None)
