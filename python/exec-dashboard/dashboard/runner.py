from __future__ import annotations
import asyncio
from asyncio.subprocess import PIPE, STDOUT
from collections.abc import AsyncGenerator
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


async def run_executable(
    exe: Executable,
    values: dict[str, object],
) -> AsyncGenerator[tuple[str, str | int], None]:
    """
    Async generator yielding:
      ("stdout", line_str)  for each output line
      ("exit", code)        when process finishes
    """
    argv = build_argv(exe, values)
    proc = await asyncio.create_subprocess_exec(
        *argv,
        stdout=PIPE,
        stderr=STDOUT,   # merge stderr into stdout
    )
    assert proc.stdout is not None
    async for raw in proc.stdout:
        yield ("stdout", raw.decode(errors="replace").rstrip("\n"))
    await proc.wait()
    yield ("exit", proc.returncode)
