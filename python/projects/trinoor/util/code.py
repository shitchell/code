"""
Inspect code.
"""

from inspect import FrameInfo as _FrameInfo
from inspect import getframeinfo as _getframeinfo
from inspect import stack as _stack
from typing import Callable as _Callable

from lib_programname import get_path_executed_script as get_running_script

__all__ = ["get_running_script"]


def get_stack() -> list[_FrameInfo]:
    """
    Get the stack.

    Returns:
        stack (list[FrameInfo]): The stack.
    """
    return _stack()


def get_frame(index: int = 2) -> _FrameInfo:
    """
    Get the frame of the calling function or at the given index.

    Args:
        index (int): The index of the calling function in the stack. Defaults to 2.

    Returns:
        frame (FrameInfo): The frame of the calling function.
    """
    return get_stack()[index]


def get_caller(index: int = 4) -> _Callable:
    """
    Get the calling function.

    Args:
        index (int): The index of the calling function in the stack.

    Returns:
        caller (Callable): The calling function.
    """
    frame: _FrameInfo = get_frame(index)
    func: _Callable = lambda: ...
    func.__code__ = frame.frame.f_code
    func.__name__ = frame.function
    func.__module__ = frame.filename
    return func


def objdict(obj: object, _tracked: dict[int, object] = {}) -> dict[str, object]:
    """
    Convert an object to a dictionary.

    Args:
        obj (object): The object to convert.

    Returns:
        objdict (dict[str, object]): The object as a dictionary.
    """
    _obj: dict[str, object] = {}
    for key in dir(obj):
        if hasattr(obj, key):
            value: object = getattr(obj, key)
            vhash: int
            try:
                vhash = hash(value)
            except TypeError:
                vhash = id(value)
            if vhash not in _tracked:
                _tracked[vhash] = value
                print("processing", vhash, key, value)
                if isinstance(value, (bool, int, float, str, bytes, bytearray)):
                    # immediately store the value if it's a primitive type
                    _obj[key] = value
                elif isinstance(value, (list, tuple, set, dict)):
                    for v in value:
                        _obj[key] = objdict(v, _tracked)
                # if the value contains builtins, just store the global builtins
                elif key in ["__builtins__", "f_builtins"]:
                    _obj[key] = globals()["__builtins__"]
                elif key in {
                    "__call__",
                    "__delattr__",
                    "__dir__",
                    "__eq__",
                    "__format__",
                    "__ge__",
                    "__getattribute__",
                    "__gt__",
                    "__hash__",
                    "__init__",
                    "__init_subclass__",
                    "__le__",
                    "__lt__",
                    "__ne__",
                    "__new__",
                    "__reduce__",
                    "__reduce_ex__",
                    "__repr__",
                    "__setattr__",
                    "__sizeof__",
                    "__str__",
                    "__subclasshook__",
                }:
                    # immediately store the value
                    _obj[key] = value
                else:
                    _obj[key] = objdict(value, _tracked)
            else:
                print("skipping", vhash, key, value)
                _obj[key] = _tracked[vhash]
        else:
            _obj[key] = None

    return _obj
