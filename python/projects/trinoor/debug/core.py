import os as _os
import traceback as _traceback
import inspect as _inspect
import sys as _sys
import time as _time
from enum import Enum as _Enum
from types import FrameType as _Frame


class LogLevel(_Enum):
    """
    Enum for logging levels
    """

    DEBUG = 0
    INFO = 1
    WARNING = 2
    ERROR = 3
    CRITICAL = 4
    DISABLED = 5

    def __gt__(self, other: object) -> bool:
        return self.value > other.value

    def __ge__(self, other: object) -> bool:
        return self.value >= other.value

    def __lt__(self, other: object) -> bool:
        return self.value < other.value

    def __le__(self, other: object) -> bool:
        return self.value <= other.value

    def __eq__(self, other: object) -> bool:
        return self.value == other.value

    def __ne__(self, other: object) -> bool:
        return self.value != other.value


LEVEL: LogLevel = LogLevel.DEBUG


def set_level(level: LogLevel | int) -> None:
    """
    Set the logging level

    Args:
        level (LogLevel | int): Logging level
    """
    global LEVEL
    # Verify that the level is valid
    try:
        if isinstance(level, int):
            level = LogLevel(level)
        elif isinstance(level, str):
            level = LogLevel[level.upper()]
        else:
            raise ValueError(f"Invalid logging level '{level}'")
    except (ValueError, KeyError) as e:
        valid_levels: str = ", ".join([l.name for l in LogLevel])
        raise ValueError(
            f"Invalid logging level '{level}', must be one of {valid_levels}"
        ) from e
    LEVEL = LogLevel(level)


def log(
    *args: object,
    sep: str = " ",
    end: str = "\n",
    file: object = _sys.stderr,
    flush: bool = True,
    level: LogLevel = LogLevel.DEBUG,
    expand_tb: bool = True,
    include_stack: bool = False,
    include_caller: bool = True,
    include_fullpath: bool = True,
    strftime: str = "%Y-%m-%d %H:%M:%S",
    _stack_offset: int = 1,
) -> None:
    """
    Print a message to stderr if the logging level is set to DEBUG

    Args:
        *args (object): Objects / strings to print.
        sep (str, optional): Separator between objects. Defaults to " ".
        end (str, optional): End of line character. Defaults to "\n".
        file (object, optional): File to print to. Defaults to sys.stderr.
        flush (bool, optional): Flush the file after printing. Defaults to False.
        level (LogLevel, optional): Logging level. Defaults to LogLevel.DEBUG.
        expand_tb (bool, optional): If there are any exceptions passed as arguments,
            expand them to their full traceback. Defaults to False.
        include_stack (bool, optional): Include the stack trace. Defaults to False.
        include_caller (bool, optional): Include the caller. Defaults to True.
        include_fullpath (bool, optional): Include the full filepath to the caller.
            Defaults to True.
        strftime (str, optional): Format string for the timestamp. Defaults to
            "%Y-%m-%d %H:%M:%S".
    """
    if level >= LEVEL:
        timestamp: str = _time.strftime(strftime)
        if include_caller:
            # Get the caller's filename, function name, and line number
            frame: _Frame = _inspect.stack()[_stack_offset].frame
            try:
                info: _inspect.FrameInfo = _inspect.getframeinfo(frame)
                filename: str = info.filename
                if not include_fullpath:
                    filename = filename.split(_os.path.sep)[-1]
                funcname: str = info.function
                lineno: int = info.lineno
            finally:
                del frame
            # Print the caller's filename, function name, and line number
            print(
                f"[{timestamp}] {filename}:{funcname}:{lineno}",
                end="",
                file=file,
                flush=flush,
            )
        # Convert any tracebacks to full strings if expand_tb is True
        if expand_tb:
            _args: list[object] = []
            for arg in args:
                if isinstance(arg, Exception):
                    _args.append(
                        "".join(
                            _traceback.format_exception(
                                type(arg), arg, arg.__traceback__
                            )
                        )
                    )
                else:
                    _args.append(arg)
            args = _args
        # Print the message, prefixing every line with a timestamp if there is more than
        # one line
        lines: list[str] = str(sep.join(map(str, args))).splitlines()
        if len(lines) > 1:
            lines = [f"[{timestamp}] {line}" for line in lines]
            print("", file=file, flush=flush)
        else:
            print("", end=" -- ", file=file, flush=flush)
        print(*lines, sep="\n", end=end, file=file, flush=flush)
        if include_stack:
            # Get the stack *excluding* this function call
            stack = _traceback.extract_stack()
            stack = stack[:-_stack_offset]
            # Print the stack
            print("Debug Stack:", file=file)
            _traceback.print_list(stack, file=file)


def debug(*args: object, **kwargs: object) -> None:
    """
    Print a message to stderr with the DEBUG level

    Args:
        *args (object): Objects / strings to print.
        **kwargs (object): Keyword arguments to pass to debug()
    """
    log(*args, level=LogLevel.DEBUG, _stack_offset=2, **kwargs)


def info(*args: object, **kwargs: object) -> None:
    """
    Print a message to stderr with the INFO level

    Args:
        *args (object): Objects / strings to print.
        **kwargs (object): Keyword arguments to pass to debug()
    """
    log(*args, level=LogLevel.INFO, _stack_offset=2, **kwargs)


def warn(*args: object, **kwargs: object) -> None:
    """
    Print a message to stderr with the WARNING level

    Args:
        *args (object): Objects / strings to print.
        **kwargs (object): Keyword arguments to pass to debug()
    """
    log(*args, level=LogLevel.WARNING, _stack_offset=2, **kwargs)


def error(*args: object, **kwargs: object) -> None:
    """
    Print a message to stderr with the ERROR level

    Args:
        *args (object): Objects / strings to print.
        **kwargs (object): Keyword arguments to pass to debug()
    """
    log(*args, level=LogLevel.ERROR, _stack_offset=2, **kwargs)


def critical(*args: object, **kwargs: object) -> None:
    """
    Print a message to stderr with the CRITICAL level

    Args:
        *args (object): Objects / strings to print.
        **kwargs (object): Keyword arguments to pass to debug()
    """
    log(*args, level=LogLevel.CRITICAL, _stack_offset=2, **kwargs)


def _test():
    debug("hello world")
