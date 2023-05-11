"""
APIPlugin is a base class for plugins.
"""

import asyncio as _asyncio
import importlib as _importlib
import inspect as _inspect
import os as _os
import threading as _threading

from fastapi import APIRouter as _APIRouter, FastAPI as _FastAPI
from starlette.routing import Route as _Route
from fastapi.requests import Request as _Request
from fnmatch import fnmatch as _fnmatch
from pathlib import Path as _Path
from functools import wraps as _wraps
from types import ModuleType as _ModuleType, CoroutineType as _CoroutineType

from ..debug import debug


def context(
    condition: callable = None,
    **kwargs,
) -> callable:
    """
    Decorator for APIPlugin methods that handle events. This will perform 2 types of
    checks before running the decorated method:

    1. If a lambda condition is given, it will be called with any arguments from the
       function with the same name(s) as the lambda's arguments. If the lambda returns
       True, the method will be run. If the lambda returns False, the method will not.
    2. If keyword arguments are given, they will be compared to the arguments of the
       function with the same name(s). If all keyword arguments match, the method will
       be run. If any keyword arguments do not match, the method will not.

    Example:
        @context(lambda foo: foo["data"] == "bar", hello="world")
        def my_method(foo, hello="blah", *args, **kwargs):
            ...

        my_method({"data": "bar"}, hello="world", "otherarg")  # Runs
        my_method({"data": "baz"}, hello="world")  # Does not run, foo["data"] != "bar"
        my_method({"data": "bar"})  # Does not run, hello != "world"

    Notes:
        - If both a lambda condition and keyword arguments are given, both must be
          satisfied for the method to run.
        - Any parameters in the lambda function will be matched to the function's
          parameters by name. If the lambda function has a parameter that does not
          match any of the function's parameters, the method will not run.
        - If the function has any parameters that are not specified in the `@context`
          decorator, they will be ignored and not factored into the condition.
        - This decorator can be used for both asynchronous and synchronous methods.
        - If this decorator is used on a FastAPI route, it must be below any
          @router.post or @router.get decorators.

    Args:
        condition (callable): Runs the decorated method if this function returns True.
        **kwargs: Runs the decorated method if the function's arguments match these
            keyword arguments.
        priority (int, optional): The priority of the event handler. Defaults to 0.
    """

    ## print(f"[@context] {condition=}, {kwargs=}")

    def decorator(func: callable) -> callable:
        # Get a dictionary of the function's arguments and their values
        ...
        ## print(f"[@context.decorator] {func=} {dir(func)=}")

        def check_args(*args, **kwargs) -> object:
            ## print(f"[@context.decorator.check_args] {args=}, {kwargs=}")
            # Generate a dictionary of each argument and keyword argument and their
            # values
            arg_dict: dict[str, object] = {
                **{arg: val for arg, val in zip(func.__code__.co_varnames, args)},
                **kwargs,
            }

            # If a condition is provided, check it
            if condition is not None:
                # Determine the arg names that the condition uses
                condition_arg_names: list[str] = condition.__code__.co_varnames[
                    : condition.__code__.co_argcount
                ]
                # Check that the condition's arguments are in the function's arguments
                if not all(arg in arg_dict for arg in condition_arg_names):
                    # If the lambda function requires arguments that are not in the
                    # function's arguments, skip the function
                    ## print("skipping: condition args not in arg_dict")
                    return False
                condition_args: list[object] = [
                    arg_dict[arg] for arg in condition_arg_names
                ]
                # Check the condition
                if not condition(*condition_args):
                    # If the condition does not return a truthy value, skip the function
                    ## print("skipping: condition returned untruthy value")
                    return False

            # If keyword arguments are provided, check each against the function's
            # arguments
            if kwargs:
                # Check that the function's arguments contain all of the keyword
                # arguments
                if not all(arg in arg_dict for arg in kwargs):
                    # If the function does not contain all of the keyword arguments,
                    # skip the function
                    ## print("skipping: kwargs not in arg_dict")
                    return False
                # Check that the function's arguments match the keyword arguments
                if not all(arg_dict[arg] == val for arg, val in kwargs.items()):
                    # If the function's arguments do not match the keyword arguments,
                    # skip the function
                    ## print("skipping: kwargs do not match arg_dict")
                    return False

            return True

        # Determine if the function is a FastAPI route
        is_route: bool = hasattr(func, "dependencies")

        ## print(f"[@context.decorator] {func.__code__.co_name} {is_route=}", flush=True)
        for arg in dir(func.__code__):
            ## print(f"[@context.decorator] {arg}={getattr(func.__code__, arg)}", flush=True)
            ...

        if _asyncio.iscoroutinefunction(func):
            ## print("[@context.decorator] function is asynchronous")

            @_wraps(func)
            async def wrapper(*args, **kwargs) -> object:
                ## print(f"[@context.decorator.wrapper] {func=}, {args=}, {kwargs=}")
                if check_args(*args, **kwargs):
                    return await func(*args, **kwargs)

        else:
            ## print("[@context.decorator] function is synchronous")

            @_wraps(func)
            def wrapper(*args, **kwargs) -> object:
                ## print(f"[@context.decorator.wrapper] {func=}, {args=}, {kwargs=}")
                if check_args(*args, **kwargs):
                    return func(*args, **kwargs)
                return

        return wrapper

    return decorator


def handles(event: str, priority: int = 0) -> callable:
    """
    Decorator for APIPlugin methods that handle events. This simply adds a `__handles__`
    attribute to the method with a dictionary of events and priorities that it handles.

    This works in tandem with `API.fire_event()` to allow plugins to interact with each
    other.

    Args:
        event (str): The name of the event to handle.
        priority (int, optional): The priority of the event handler. Defaults to 0.
    """

    @_wraps(handles)
    def decorator(func: callable) -> callable:
        if not hasattr(func, "__handles__"):
            func.__handles__ = {}
        func.__handles__[event] = priority
        ## print(f"setup event handler for function {func.__name__}:", priority, func.__handles__,)
        return func

    return decorator


def does(action: str, priority: int = 0) -> callable:
    """
    Decorator for APIPlugin methods that do actions. This simply adds a `__does__`
    attribute to the method with a dictionary of actions and priorities that it does.

    This works in tandem with `API.do()` to allow plugins to request actions from other
    plugins.

    Args:
        action (str): The name of the action to do.
        priority (int, optional): The priority of the action. Defaults to 0.
    """

    @_wraps(does)
    def decorator(func: callable) -> callable:
        if not hasattr(func, "__does__"):
            func.__does__ = {}
        func.__does__[action] = priority
        ## print(f"setup action handler for function {func.__name__}:", priority, func.__does__)
        return func

    return decorator


class Handler:
    def __init__(self, name: str, handler: callable, priority: int = 0) -> None:
        self.name: str = name
        self.handler: callable = handler
        self.priority: int = priority
        self.signature: _inspect.Signature = _inspect.signature(handler)

    def _start_event_loop(self, coroutine: _CoroutineType):
        """
        Starts an event loop for asynchronous handlers.
        """
        loop = _asyncio.new_event_loop()
        _asyncio.set_event_loop(loop)
        try:
            loop.run_until_complete(coroutine)
        finally:
            loop.stop()

    def __call__(self, *args, **kwargs) -> object:
        func: callable
        debug(f"calling handler {self.name} with {args=} {kwargs=}")
        if _asyncio.iscoroutinefunction(self.handler):
            # Handle asynchronous functions
            debug("async event loop?", _asyncio.get_running_loop().is_running())
            loop_thread = _threading.Thread(
                target=self._start_event_loop, args=(self.handler(*args, **kwargs),)
            )
            loop_thread.start()
            return loop_thread.join()
        # Handle synchronous functions
        return self.handler(*args, **kwargs)

    def __repr__(self) -> str:
        cls: str = self.__class__.__name__
        name: str = self.name
        priority: int = self.priority
        func: str = self.handler.__name__
        signature: str = str(self.signature)
        return f"<{cls}:{name}:{priority} {func}{signature}>"

    def __gt__(self, other: object) -> bool:
        if hasattr(other, "priority"):
            return self.priority > other.priority
        return NotImplemented

    def __lt__(self, other: object) -> bool:
        if hasattr(other, "priority"):
            return self.priority < other.priority
        return NotImplemented

    def __eq__(self, other: object) -> bool:
        if hasattr(other, "priority") and hasattr(other, "name"):
            return self.priority == other.priority and self.name == other.name
        return NotImplemented


class EventHandler(Handler):
    def __init__(self, event: str, handler: callable, priority: int = 0) -> None:
        super().__init__(event, handler, priority)


class ActionHandler(Handler):
    def __init__(self, action: str, handler: callable, priority: int = 0) -> None:
        super().__init__(action, handler, priority)


class APIPlugin:
    """
    A plugin is any python file that defines either a router: APIRouter variable or a
    register(api: FastAPI) function. The router variable will be added to the API's
    routes, and the register function will be called with the API as an argument.

    Upon loading a file, this class will collect all of the methods that are decorated
    with `@handles` or `@does` to be used by the API.
    """

    filepath: str | _Path
    name: str
    short_description: str
    description: str
    _submodule_paths: list[str | _Path] | str | _Path
    _event_handlers: list[EventHandler]
    _action_handlers: list[ActionHandler]
    _router: _APIRouter
    _register: callable
    _unregister: callable
    _module: _ModuleType

    def __init__(
        self,
        filepath: str | _Path,
        name: str = None,
        short_description: str = None,
        description: str = None,
        submodule_paths: list[str | _Path] | str | _Path = [],
        use_full_name: bool = False,
        trim_base: str | _Path = None,
        autoload: bool = True,
        fail_silently: bool = False,
    ) -> None:
        """
        Args:
            filepath (str | Path): The path to the plugin file.
            name (str, optional): The name of the plugin. Defaults to the filename
                without the .py extension, unless the file is an __init__.py file, in
                which case the name of the parent directory is used.
            short_description (str, optional): A short description of the plugin. By
                default, this is the first line of the plugin module's docstring. If
                passed as a parameter, this will override that docstring.
            description (str, optional): A longer description of the plugin. By default,
                this will be loaded from the plugin module's docstring. If passed as a
                parameter at initialization, this will override that docstring
                description.
            submodule_paths (list[str | Path] | str | Path, optional): A list of paths
                that can be used for importing submodules within the plugin. Defaults to
                [].
            use_full_name (bool, optional): Whether to use the full path to the plugin
                file, with directory separators replaced with periods, as the plugin
                name. Defaults to False.
            trim_base (str, optional): A string to trim from the beginning of the
                plugin's name. Defaults to None.
            autoload (bool, optional): Whether to automatically load the plugin. If
                False, the plugin will not be loaded until `load()` is called. Defaults
                to True.
            fail_silently (bool, optional): Whether to fail silently if the plugin
                cannot be loaded. Defaults to False.
        """
        self.filepath: _Path = _Path(filepath)
        self._name = APIPlugin._determine_name(filepath, name, use_full_name, trim_base)
        self.short_description: str = short_description
        self.description: str = description
        self._submodule_paths = submodule_paths or []
        self._event_handlers: list[EventHandler] = []
        self._action_handlers: list[ActionHandler] = []
        self._router: _APIRouter = None
        self._register: callable = None
        self._unregister: callable = None
        self._loaded: bool = False
        self._module: _ModuleType = None
        if autoload:
            self.load(fail_silently=fail_silently)

    @staticmethod
    def _determine_name(
        filepath: str | _Path,
        name: str = None,
        use_full_name: bool = False,
        trim_base: str | _Path = None,
    ) -> str:
        if name:
            # if a name was given, just use that
            ...
        else:
            # Make sure the filepath is a Path object
            filepath = _Path(filepath)

            # If the filename is __init__.py, use parent directory as the filepath
            if filepath.name == "__init__.py":
                filepath = filepath.parent
            if use_full_name:
                # Use the full path to the plugin file, minus the extension
                # e.g. "plugins/my_plugin.py" -> "plugins/my_plugin"
                name = filepath.with_suffix("").as_posix()
            else:
                # Use the filename without the extension as the plugin name
                # e.g. "plugins/my_plugin.py" -> "my_plugin"
                name = filepath.stem
        if trim_base:
            trim_base: str = str(trim_base)
            # Remove the trim_base from the beginning of the plugin name
            # e.g. trim_base="plugins/": "plugins/my_plugin" -> "my_plugin"
            if name.startswith(trim_base):
                name = name[len(trim_base) :]

        # Replace any directory separators with periods in the plugin name
        name = name.replace(_os.path.sep, ".")

        # Remove any leading/trailing periods
        name = name.strip(".")

        return name

    def load(self, fail_silently: bool = False) -> bool:
        """
        Loads the plugin file and collects all of the methods that are decorated with
        `@handles` or `@does`.

        Args:
            fail_silently (bool, optional): If False, throws an exception when the
                plugin fails to load properly. If True, returns a boolean with whether
                it loaded successfully. Defaults to False.
        """
        # Load the plugin file
        ## print(f"Loading plugin: {self.name=} {self.filepath=} {self._submodule_paths=}")
        spec = _importlib.util.spec_from_file_location(
            name=self.name,
            location=self.filepath,
            submodule_search_locations=self._submodule_paths,
        )
        self._module = _importlib.util.module_from_spec(spec)
        try:
            spec.loader.exec_module(self._module)
        except Exception as e:
            if fail_silently:
                ## print(f"Failed to load plugin: {self.name=} {self.filepath=}")
                ## print(e)
                return False
            else:
                raise PluginLoadError(
                    f"Error loading plugin '{self.name}': {e}: {e.args}"
                )

        # If a short_description or description were not provided, try to get them from
        # the module docstring, using the FastAPI convention of a short description
        # followed by a blank line followed by a longer description and removing
        # anything after a \f (form feed) character.
        if self.short_description is None or self.description is None:
            docstring = self._module.__doc__
            if docstring:
                docstring = docstring.split("\f")[0]
                if self.short_description is None:
                    self.short_description = docstring.splitlines()[0].strip()
                if self.description is None:
                    self.description = docstring.strip()

        # Collect any event handlers, action handlers, routers, and register functions
        for name in dir(self._module):
            if name.startswith("_"):
                # Skip private methods and attributes
                continue

            obj = getattr(self._module, name)

            # Check for event handlers
            if hasattr(obj, "__handles__"):
                ## print(f"found event handler: {obj}.{obj.__name__}")
                for event, priority in obj.__handles__.items():
                    self._event_handlers.append(EventHandler(event, obj, priority))

            # Check for action handlers
            if hasattr(obj, "__does__"):
                ## print(f"found action handler: {obj}.{obj.__name__}")
                for action, priority in obj.__does__.items():
                    self._action_handlers.append(ActionHandler(action, obj, priority))

            # Check for routers and register functions
            if name == "router" and isinstance(obj, _APIRouter):
                self._router = obj

                # If the router does not have a prefix, set it to the plugin name with
                # any periods replaced with slashes
                if not self._router.prefix:
                    self._router.prefix = "/" + self.name.replace(".", "/")
            elif name == "register" and callable(obj):
                self._register = obj
            elif name == "unregister" and callable(obj):
                self._unregister = obj

        self._loaded = True
        return True

    @property
    def loaded(self) -> bool:
        """Whether the plugin has been loaded."""
        return self._loaded

    @property
    def name(self) -> str:
        return self._name

    @property
    def submodule_paths(self) -> list[_Path]:
        return self._submodule_paths

    @submodule_paths.setter
    def submodule_paths(self, value: list[str | _Path] | str | _Path) -> None:
        # Only set the submodule path if it's not already set
        if self._submodule_paths is None:
            # If a single string or Path is passed, convert it to a list
            if isinstance(value, (str, _Path)):
                value = [value]

            # Convert all of the paths to Path objects
            self._submodule_paths = [_Path(v) for v in value]

    def has_routes(self) -> bool:
        """
        Returns True if the plugin has a router, False otherwise.
        """
        return self._router is not None

    @property
    def router(self) -> _APIRouter:
        """
        Returns the router for the plugin.
        """
        return self._router

    @property
    def routes(self) -> list[_Route]:
        """
        Returns the routes for the plugin.
        """
        return self._router.routes if self.has_routes() else []

    def register(self, api: _FastAPI) -> None:
        """
        Calls the register function for the plugin.

        Args:
            api (FastAPI): The FastAPI instance to register the plugin with.
        """
        return self._register(api)

    def unregister(self, api: _FastAPI) -> None:
        """
        Calls the unregister function for the plugin.

        Args:
            api (FastAPI): The FastAPI instance to unregister the plugin from.
        """
        return self._unregister(api)

    def has_register_function(self) -> bool:
        """
        Returns True if the plugin has a register function, False otherwise.
        """
        return self._register is not None

    def has_unregister_function(self) -> bool:
        """
        Returns True if the plugin has an unregister function, False otherwise.
        """
        return self._unregister is not None

    def get_event_handlers(self, event: str = None) -> list[EventHandler]:
        """
        Returns a list of event handlers for the given event or all event handlers if
        no event is given.

        Args:
            event (str, optional): The event to get handlers for. If no event is given,
                all event handlers are returned. Supports glob matching. Defaults to
                None.
        """
        if event is None:
            return self._event_handlers
        return [h for h in self._event_handlers if _fnmatch(h.name, event)]

    def get_action_handlers(self, action: str = None) -> list[ActionHandler]:
        """
        Returns a list of action handlers for the given action.

        Args:
            action (str, optional): The action to get handlers for. If no action is
                given, all action handlers are returned. Supports glob matching.
                Defaults to None.
        """
        if action is None:
            return self._action_handlers
        return [h for h in self._action_handlers if _fnmatch(h.name, action)]

    def fire_event(self, event: str, *args, **kwargs) -> None:
        """
        Fires the given event.

        Args:
            event (str): The event to fire.
        """
        handlers: list[EventHandler] = self.get_event_handlers(event)
        if handlers:
            # Sort the handlers by priority
            handlers.sort(key=lambda handler: handler.priority)

            # Call each handler
            for handler in handlers:
                ## print(f"calling event handler {handler} for event {event}")
                handler(*args, **kwargs)

    def do(self, action: str, *args, **kwargs) -> object:
        """
        Fires the given action.

        Args:
            action (str): The action to fire.
        """
        handlers: list[ActionHandler] = self.get_action_handlers(action)
        if handlers:
            # Sort the handlers by priority
            handlers.sort(key=lambda handler: handler.priority)

            # Call each handler
            for handler in handlers:
                ## print(f"calling action handler {handler} for action {action}")
                handler(*args, **kwargs)

    def __repr__(self) -> str:
        rep: str = f"APIPlugin({self.name}"
        handled_events: list[str] = [x.name for x in self._event_handlers]
        if handled_events:
            rep += f", handles={handled_events}"
        handled_actions: list[str] = [x.name for x in self._action_handlers]
        if handled_actions:
            rep += f", does={handled_actions}"
        rep += ")"
        return rep


def should_ignore_plugin(name: str, whitelist: list[str], blacklist: list[str]) -> bool:
    """
    Returns True if the plugin should be ignored, False otherwise.

    Args:
        name (str): The name of the plugin.
        whitelist (list[str | Path]): A list of glob patterns to whitelist. Any plugin
            that does not match one of these patterns will be ignored.
        blacklist (list[str | Path]): A list of glob patterns to blacklist. Any plugin
            that matches one of these patterns will be ignored.

    Returns:
        bool: True if the plugin should be ignored, False otherwise.
    """
    # If the plugin is in the blacklist, ignore it
    if any(_fnmatch(name, pattern) for pattern in blacklist):
        return True

    # If the whitelist is empty, the plugin is not ignored
    if not whitelist:
        return False

    # If the plugin is not in the whitelist, ignore it
    if not any(_fnmatch(name, pattern) for pattern in whitelist):
        return True

    # The plugin is not ignored
    return False


def load_plugins(
    sources: list[str | _Path] | str | _Path,
    recursive: bool = True,
    whitelist: list[str] = [],
    blacklist: list[str] = [],
    submodule_paths: list[str | _Path] = [],
    autoload: bool = True,
    fail_silently: bool = False,
    _root_location: str | _Path = None,
) -> list[APIPlugin]:
    """
    Load plugins from a directory, file, or list of directories/files.

    Args:
        sources (list[str | Path] | str | Path): The location(s) to load plugins from.
            This can be a directory, file, or list of directories/files.
        recursive (bool, optional): If True, subdirectories will be searched for
            plugins. Defaults to True.
        whitelist (list[str], optional): A list of plugins to load, using glob patterns.
            If this is specified, only plugins that match a pattern in this list will be
            loaded. Defaults to [].
        blacklist (list[str], optional): A list of plugins to ignore, using glob
            patterns. If this is specified, plugins that match a pattern in this list
            will not be loaded. Defaults to [].
        submodule_paths (list[str | Path], optional): A list of paths to add to each
            plugin's sys.path. This is useful if the plugin needs to import modules from
            the main application. Defaults to [].
        autoload (bool, optional): If True, the plugin module will be loaded on
            instantiation. Defaults to True.
        fail_silently (bool, optional): If True, any errors that occur while
            auto-loading a plugin will be ignored. Defaults to False.

    Returns:
        list[type[APIPlugin]]: A list of loaded plugins.
    """
    debug(
        f"""
    Loading plugins from {sources}:
        {recursive=}
        {whitelist=}
        {blacklist=}
        {submodule_paths=}
        {autoload=}
        {fail_silently=}
        {_root_location=}
    """
    )
    plugins: list[APIPlugin] = []

    if isinstance(sources, str) or isinstance(sources, _Path):
        sources = [sources]

    for loc in sources:
        debug("processing:", loc)
        if isinstance(loc, str):
            loc = _Path(loc)
            debug(f"converted to {loc=}")

        debug("wtf", loc.is_dir(), loc.is_file())
        if loc.is_dir():
            debug(f"{loc} is a directory")
            for file in loc.iterdir():
                debug(f"processing file: {file}")
                if (file.is_file() and file.suffix == ".py") or (
                    file.is_dir() and recursive
                ):
                    # Load all .py files *except* for files that start with an
                    # underscore, except for __init__.py -- still load that one
                    if file.name.startswith("_") and file.name != "__init__.py":
                        continue
                    if file.is_dir():
                        debug("recursing using root", _root_location or loc)
                        ...

                    plugins.extend(
                        load_plugins(
                            file,
                            recursive=recursive,
                            whitelist=whitelist,
                            blacklist=blacklist,
                            submodule_paths=submodule_paths,
                            autoload=autoload,
                            fail_silently=fail_silently,
                            _root_location=_root_location or loc,
                        )
                    )
        elif loc.is_file():
            debug("hit file", loc)
            if loc.suffix == ".py":
                # Load all .py files *except* for files that start with an
                # underscore, except for __init__.py -- still load that one
                if loc.name.startswith("_") and loc.name != "__init__.py":
                    continue

                # And no *.example.py files
                if loc.name.endswith(".example.py"):
                    continue

                # Load the plugin, trimming the root directory from the plugin name
                debug(f"Loading plugin {loc}: {_root_location=} {fail_silently=}")
                plugin: APIPlugin = APIPlugin(
                    loc,
                    submodule_paths=submodule_paths,
                    use_full_name=True,
                    trim_base=_root_location,
                    autoload=False,
                    fail_silently=fail_silently,
                )

                # If the plugin is not ignored, add it to the list
                if not should_ignore_plugin(plugin.name, whitelist, blacklist):
                    if autoload:
                        plugin.load()
                    plugins.append(plugin)
        else:
            debug("no idea what loc is")
            ...

    return plugins


class PluginLoadError(Exception):
    """
    Raised when a plugin fails to load.
    """
