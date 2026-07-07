from __future__ import annotations
import json
from pathlib import Path


class UsageTracker:
    """Persist per-executable button-press counts to a JSON file."""

    def __init__(self, path: Path) -> None:
        self._path = path
        self._counts: dict[str, int] = {}
        if path.exists():
            try:
                with open(path) as f:
                    self._counts = json.load(f)
                if not isinstance(self._counts, dict):
                    self._counts = {}
            except (json.JSONDecodeError, ValueError):
                self._counts = {}

    def count(self, exe_id: str) -> int:
        return self._counts.get(exe_id, 0)

    def increment(self, exe_id: str) -> None:
        self._counts[exe_id] = self._counts.get(exe_id, 0) + 1
        tmp = self._path.with_suffix(".tmp")
        with open(tmp, "w") as f:
            json.dump(self._counts, f)
        tmp.rename(self._path)
