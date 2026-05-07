from __future__ import annotations
from datetime import datetime
from textual.app import ComposeResult
from textual.widgets import RichLog
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
