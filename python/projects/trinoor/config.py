"""
A simple module for loading, manipulating, and saving JSON config files.

Examples:
    >>> import config
    >>> config.get()
    {'key': 'value', 'key2': [1, 2, 3], 'key3': {'key4': 'value4'}}
    >>> config.get('key')
    'value'
    >>> config.get('key3.key4')
    'value4'
    >>> config.remove('key3.key4')
    >>> config.get('key3.key4')
    >>> config.get('key3')
    {}
    >>> config.get('key2')
    [1, 2, 3]
    >>> config.append('key2', 4)
    >>> config.get('key2')
    [1, 2, 3, 4]
    >>> config.pop('key2', 0)
    1
"""

# TODO: remove type: ignore comments
#            check for `except Exception:`

import json as _json
import os as _os
import re as _re

from pathlib import Path as _Path

CONFIG_ROOT: str | _Path = "."
CONFIG_PATH: str | _Path = _Path("settings.json")


class Config:
    def __init__(self, path: str | _Path, indent: int = 4) -> None:
        self._path: _Path = _Path(path)
        self.indent = indent

    @staticmethod
    def _check_serializable(value: object) -> None:
        """
        Raises a TypeError if the value is not JSON serializable.
        """
        if not _is_serializable(value):
            raise TypeError(f"Value '{value}' is not JSON serializable.")

    @staticmethod
    def load(path: str | _Path = None) -> dict[str, object]:
        """
        Loads a config json file and returns a dictionary. If the file does not
        exist, an empty dictionary is returned.
        """
        if path is None:
            path = CONFIG_PATH
        if not _os.path.exists(path):
            return {}
        with open(path) as f:
            data: str = f.read()
            # remove all instances of `//*` outside of quotes
            jsonc_regex = r'//(?=([^"\\]*(\.|"([^"\\]*\.)*[^"\\]*"))*[^"]*$).*'
            data_no_comments: str = _re.sub(jsonc_regex, "", data)
            return _json.loads(data_no_comments, strict=False)

    def save(self, data: dict[str, object]) -> None:
        """
        Saves a config json file.
        """
        Config._check_serializable(data)
        with open(self.path, "w") as f:
            _json.dump(data, f, indent=self.indent)

    @property
    def path(self) -> _Path:
        path: _Path = _Path(CONFIG_ROOT) / _Path(self._path)
        return path

    @property
    def indent(self) -> int:
        return self._indent

    @indent.setter
    def indent(self, value: int) -> None:
        if not isinstance(value, int):
            raise TypeError("Indent must be an integer.")
        if value < 0:
            raise ValueError("Indent must be greater than or equal to 0.")
        self._indent = value

    @staticmethod
    def _get(
        data: dict[str, object], keys: list[str] = [], default: object = None
    ) -> object:
        """
        Given a dictionary and a list of keys, returns the value at the key. If
        the key does not exist, the default value is returned.
        """
        for k in keys:
            try:
                data = data[k]  # type: ignore
            except Exception:
                return default
        return data

    def get(
        self, key: str = None, default: object = None, missing_ok: bool = True
    ) -> object:
        """
        Returns the config object or a specific key using the notation
        "key1.key2.key3".
        """
        config: dict[str, object] = Config.load(self.path)
        keys: list[str] = key.split(".") if isinstance(key, str) else []
        value: object = Config._get(config, keys, default)
        if value is None and not missing_ok:
            raise KeyError(f"Key '{key}' not found.")
        return value

    def set(self, key: str, value: object) -> None:
        """
        Sets a key in the config json file.
        """
        Config._check_serializable(value)
        config: dict[str, object] = Config.load(self.path)
        original_config: dict[str, object] = config
        keys: list[str] = key.split(".")
        config = Config._get(config, keys[:-1])  # type: ignore
        config[keys[-1]] = value
        self.save(original_config)

    def append(self, key: str, value: object) -> None:
        """
        Appends a value to a list in the config json file.
        """
        Config._check_serializable(value)
        config: dict[str, object] = Config.load(self.path)
        original_config = config
        keys = key.split(".")
        config = Config._get(config, keys[:-1])  # type: ignore
        if not isinstance(config[keys[-1]], list):
            raise TypeError(f"Key '{key}' is not a list.")
        config[keys[-1]].append(value)  # type: ignore
        self.save(original_config)

    def pop(self, key: str, index: int = None) -> object:
        """
        Given just a key, removes and returns that key from the config json
        file. Given a key and an index, removes and returns the index'th value
        from the list at that key.
        """
        config: dict[str, object] = Config.load(self.path)
        original_config: dict[str, object] = config
        keys: list[str] = key.split(".")
        config = Config._get(config, keys[:-1])  # type: ignore
        value: object
        if index is None:
            # if an index is not provided, remove the last key
            value = config[keys[-1]]
            del config[keys[-1]]
        else:
            # if an index is given, remove the index'th value from the list
            value = config[keys[-1]].pop(index)  # type: ignore
        self.save(original_config)
        return value

    def remove(self, key: str, value: object = None) -> None:
        """
        Given just a key, removes that key from the config json file. Given a key
        and a value, removes the value from the list at that key.
        """
        config: dict[str, object] = Config.load(self.path)
        original_config: dict[str, object] = config
        keys: list[str] = key.split(".")
        config = Config._get(config, keys[:-1])  # type: ignore
        if value is None:
            # if a value is not provided, remove the last key
            del config[keys[-1]]
        else:
            # if a value is given, remove the value from the list
            config[keys[-1]].remove(value)  # type: ignore
        self.save(original_config)


def _is_serializable(value: object) -> bool:
    """
    Returns True if the value is JSON serializable.
    """
    return isinstance(value, (int, float, str, list, dict, bool, type(None)))


def get(key: str = None, default: object = None) -> object:
    """
    Loads a config json file and returns a dictionary.
    """
    return Config(CONFIG_PATH).get(key, default)


def set(key: str, value: object) -> object:
    """
    Sets a key in the config json file.
    """
    return Config(CONFIG_PATH).set(key, value)


def append(key: str, value: object) -> object:
    """
    Appends a value to a list in the config json file.
    """
    return Config(CONFIG_PATH).append(key, value)


def pop(key: str, index: int = None) -> object:
    """
    Given just a key, removes and returns that key from the config json file.
    Given a key and an index, removes and returns the index'th value from the
    list at that key.
    """
    return Config(CONFIG_PATH).pop(key, index)


def remove(key: str, value: object = None) -> None:
    """
    Given just a key, removes that key from the config json file. Given a key
    and a value, removes the value from the list at that key.
    """
    return Config(CONFIG_PATH).remove(key, value)
