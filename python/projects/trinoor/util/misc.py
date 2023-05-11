def dict_diff(dict1: dict, dict2: dict, bidirectional: bool = True) -> dict:
    """
    Returns the difference between two dictionaries as a new dictionary.

    Args:
        dict1 (dict): The first dictionary.
        dict2 (dict): The second dictionary.
        bidirectional (bool, optional): If True, the difference will be
            bidirectional (dict1 - dict2 and dict2 - dict1). Defaults to True.
    """
    diff: dict = {}
    for key, value in dict1.items():
        if key not in dict2:
            diff[key] = value
        elif isinstance(value, dict):
            sub_diff = dict_diff(value, dict2[key])
            if sub_diff:
                diff[key] = sub_diff
        elif value != dict2[key]:
            diff[key] = value
    if bidirectional:
        diff.update(dict_diff(dict2, dict1, bidirectional=False))
    return diff
