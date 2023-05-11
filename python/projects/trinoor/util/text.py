"""
Text manipulation utilities.
"""
import re as _re


def conjunctify(
    items: list[str] = [],
    *args: str,
    conjunction: str = "and",
    separator: str = ", ",
    oxford: bool = True,
) -> str:
    """
    Join a list of items with a conjunction.

    Args:
        items (list[str]): The items to join.
        *args (str): Additional items to join.
        conjunction (str, optional): The conjunction to use. Defaults to "and".
        separator (str, optional): The separator to use. Defaults to ",".
        oxford (bool, optional): Whether to use an Oxford comma. Defaults to True.

    Examples:
        >>> conjunctify(["a", "b", "c"])
        'a, b, and c'
        >>> conjunctify(["a", "b", "c"], conjunction="or")
        'a, b, or c'
        >>> conjunctify(["a", "b", "c"], conjunction="or", oxford=False)
        'a, b or c'
        >>> conjunctify(["a", "b", "c"], "d", "e", conjunction="or")
        'a, b, c, d, or e'

    Returns:
        str: The joined string.
    """
    items = list(items) + list(args)
    if len(items) == 1:
        return items[0]
    elif len(items) == 2:
        return f"{items[0]} {conjunction} {items[1]}"
    else:
        if oxford:
            return f"{separator.join(items[:-1])}, {conjunction} {items[-1]}"
        else:
            return f"{separator.join(items[:-1])} {conjunction} {items[-1]}"


def is_uuid(s: str) -> bool:
    """
    Check if a string is a UUID.

    Args:
        s (str): The string to check.

    Returns:
        bool: True if the string is a UUID.
    """
    if not isinstance(s, str):
        return False
    return _re.match(
        r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", s
    )
