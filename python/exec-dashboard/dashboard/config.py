from __future__ import annotations
from dataclasses import dataclass, field
from pathlib import Path
import yaml

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
    parameter: str | None = None  # explicit flag; None = auto-derive
    type: str = "str"
    nargs: int | str = 1
    required: bool = True

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
    executables: list[str]  # executable ids


@dataclass
class Config:
    executables: list[Executable]
    dashboards: list[Dashboard]


def load_config(data: dict) -> Config:
    data = data or {}
    executables = [
        Executable(
            id=exe["id"],
            name=exe["name"],
            path=exe["path"],
            args=[
                Arg(
                    name=arg["name"],
                    positional=arg.get("positional", False),
                    parameter=arg.get("parameter", None),
                    type=arg.get("type", "str"),
                    nargs=arg.get("nargs", 1),
                    required=arg.get("required", True),
                )
                for arg in exe.get("args", [])
            ],
        )
        for exe in data.get("executables", [])
    ]
    dashboards = [
        Dashboard(name=d["name"], executables=d.get("executables", []))
        for d in data.get("dashboards", [])
    ]
    return Config(executables=executables, dashboards=dashboards)


def load_config_file(path: Path) -> Config:
    with open(path) as f:
        return load_config(yaml.safe_load(f))
