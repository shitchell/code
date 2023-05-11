"""
Utilities that involve iteration.
"""
from typing import Iterable as _Iterable, Callable as _Callable, Generator as _Generator


def _flatten(
    *args, dict_values: bool = False, function: _Callable = lambda x: x
) -> _Generator | list:
    for arg in args:
        if isinstance(arg, _Iterable) and not isinstance(arg, (str, bytes)):
            for item in arg:
                for x in flatten(item, dict_values=dict_values):
                    yield function(x)
                    if isinstance(arg, dict) and dict_values:
                        value = arg.get(x)
                        for y in flatten(value, dict_values=dict_values):
                            yield function(y)
        else:
            yield function(arg)


def flatten(
    *args,
    dict_values: bool = False,
    function: _Callable = lambda x: x,
    as_list: bool = True
) -> list:
    """
    Returns a one-dimensional array given any number of any types of objects
    at any level of nesting.

    By default, dictionary values are ignored. Setting `dict_values` to True
    will include values after their associated keys.

    Args:
        *args: Any number of any types of objects at any level of nesting.
        dict_values (bool, optional): Whether to include dictionary values.
            Defaults to False.
        function (Callable, optional): A function to apply to each item.
            Defaults to `lambda x: x`.
        as_list (bool, optional): Whether to return the flattened array as a list. If
            False, a generator will be returned. Defaults to True.
    """
    response: _Generator = _flatten(*args, dict_values=dict_values, function=function)
    if as_list:
        response = list(response)
    return response


def obj_types(obj: object) -> object:
    """
    Iterates over a dictionary, list, or tuple and returns a new object with each
    element's or list of elements' type(s).

    Args:
        obj (object): The object to iterate over.

    Returns:
        object: The new object with elements replaced with their type(s).

    Example:
        >>> obj_types({"a": 1, "b": [1, 2, 3], "c": {"d": "e"}})
        {'a': <class 'int'>, 'b': [<class 'int'>], 'c': {'d': <class 'str'>}}
    """
    if isinstance(obj, dict):
        return {k: obj_types(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        if len(obj) == 0:
            return []
        elem_types = [obj_types(elem) for elem in obj]
        if all(elem_types[0] == elem_type for elem_type in elem_types):
            return [elem_types[0]]
        else:
            return [object]
    elif isinstance(obj, tuple):
        return tuple(obj_types(elem) for elem in obj)
    else:
        return type(obj)
