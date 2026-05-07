from __future__ import annotations
from dashboard.config import Executable


def build_argv(exe: Executable, values: dict[str, object]) -> list[str]:
    """Build argv list from an executable and resolved parameter values."""
    argv = [exe.path]

    positional = [arg for arg in exe.args if arg.positional]
    flags = [arg for arg in exe.args if not arg.positional]

    for arg in positional:
        val = values.get(arg.name)
        if val is not None:
            argv.append(str(val))

    for arg in flags:
        val = values.get(arg.name)
        if val is None:
            continue
        if arg.nargs == 0:
            if val:
                argv.append(arg.derived_parameter)
        elif isinstance(val, list):
            argv.append(arg.derived_parameter)
            argv.extend(str(v) for v in val)
        else:
            argv.extend([arg.derived_parameter, str(val)])

    return argv
