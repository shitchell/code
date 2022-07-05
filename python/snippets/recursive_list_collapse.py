#!/usr/bin/env python3

from typing import Iterable, Callable

def flatten(*args, dict_values: bool = False, function: Callable = lambda x: x):
    '''
    Yields a one-dimensional array given any number of any types of objects
    at any level of nesting.

    By default, dictionary values are ignored. Setting `dict_values` to True
    will include values after their associated keys.

    Optionally, a function can be passed it that will be called on each item.
    '''
    for arg in args:
        if isinstance(arg, Iterable) and not isinstance(arg, str):
            for item in arg:
                for x in flatten(item, dict_values=dict_values):
                    yield function(x)
                    if isinstance(arg, dict) and dict_values:
                        value = arg.get(x)
                        for y in flatten(value, dict_values=dict_values):
                            yield function(y)
        else:        
            yield function(arg)
