from __future__ import annotations
from dataclasses import dataclass, field
from pathlib import Path

TYPE_MAP: dict[str, type] = {
    "str": str,
    "int": int,
    "float": float,
    "bool": bool,
    "pathlib.Path": Path,
}


@dataclass
class Arg:
    name: str
    positional: bool = False
    parameter: str | None = None   # explicit flag; None = auto-derive
    type: str = "str"
    nargs: int | str = 1

    @property
    def derived_parameter(self) -> str:
        if self.parameter is not None:
            return self.parameter
        return f"-{self.name}" if len(self.name) == 1 else f"--{self.name}"

    @property
    def python_type(self) -> type:
        return TYPE_MAP.get(self.type, str)


@dataclass
class Executable:
    id: str
    name: str
    path: str
    args: list[Arg] = field(default_factory=list)


@dataclass
class Dashboard:
    name: str
    executables: list[str]   # executable ids


@dataclass
class Config:
    executables: list[Executable]
    dashboards: list[Dashboard]
