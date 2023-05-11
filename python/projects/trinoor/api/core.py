"""
This module provides an extensible API using FastAPI. It features a plugin system
and event system by default. Any other functionality can be added via plugins.

# Event System
The event system is allows plugins to either fire events or register functions that
are called when an event is fired.

## Firing and Responding to Events
- `API.fire_event(name: str, *args, **kwargs) -> None`
- `@API.handles(name: str, priority: int = 0)`
Events are fired using `API.fire_event(name: str, *args, **kwargs)`. Other functions can
register to be called when an event is fired using the `@API.handles(event_name: str)`
decorator. When an event is fired, all registered functions are called in order of
priority. The default priority is 0. The higher the priority, the earlier the function
is called. Negative priorities behave similarly to indices in a list. For example, a
function with a priority of -1 will be called last, and a function with a priority of
-2 will be called second to last. If two functions have the same priority, the order is
not guaranteed.

## Requesting Actions
- `API.do(name: str, *args, **kwargs) -> None`
- `@API.does(name: str, priority: int = 0)`
The `API.do(name: str, *args, **kwargs)` function is functionally identical to
`API.fire_event()`. It propagates the named action to all registered functions. This
allows plugins to request actions from other plugins without any strong coupling. i.e.
if a given plugin is not available, rather than throwing an error, the action will
simply not be performed. Functions with the `@API.does(name: str)` decorator
will be called when an action is requested, and the `*args` and `**kwargs` from the
`API.do()` call will be passed to the function.

## Event / Action Context
- `@API.context(foo = "bar", lambda data: data["this'] == "that")`
The `@API.context()` decorator can be used to add context to an event or action. This
context creates a set of conditions that must be met for the event or action to be
performed. All arguments that are provided via `API.fire_event()` or `API.do()` are
passed to the context function. If the context function returns `True`, the event or
action is performed. If the context function returns `False` or throws an exception, the
event or action is not performed.

## Example
: email.py
```python
@does("send_email")
def send_an_email(*args, **kwargs):
    smtp_client.send_email(*args, **kwargs)
```

: azure_devops.py
```python
@router.post("/webhook")
def webhook(request: Request):
    data = await request.json()
    api.do(f"ado:{data['eventType']}", data)
```

: gitlogger.py
```python
@handles("ado:git.push")
@context(lambda data: data["resource"]["refUpdates"][0]["name"] == "refs/heads/master")
def email_on_push(*args, **kwargs):
    api.do(
        "send_email",
        to="devops@business.com",
        subject="Push to master",
        body="Someone pushed to master!"
    )

# Plugin System
The plugin system allows plugins to be loaded dynamically. Plugins are loaded from the
directory specified, in order of highest to lowest priority:
  1. The `plugins` attribute specified at initialization
  2. The `API_PLUGINS` environment variable
  3. The `plugins` directory in the current working directory

In order to be recognized as a plugin, a plugin must do one or more of the following:
  1. Define a `router: APIRouter` attribute
  2. Define a `register(api: API) -> None` function
  3. Subclass `APIPlugin`
"""
import copy as _copy
import importlib as _importlib
import os as _os
from fnmatch import fnmatch as _fnmatch
from functools import wraps as _wraps
from glob import glob as _glob
from pathlib import Path as _Path
from traceback import format_exc as _format_exc
from typing import Generator as _Generator, Callable as _Callable

from fastapi import (
    APIRouter as _APIRouter,
    Depends as _Depends,
    FastAPI as _FastAPI,
    HTTPException as _HTTPException,
    Request as _Request,
    Security as _Security,
)
from fastapi.dependencies.utils import (
    get_body_field as _get_body_field,
    get_parameterless_sub_dependant as _get_parameterless_sub_dependant,
)
from fastapi.openapi.docs import get_swagger_ui_html as _get_swagger_ui_html
from fastapi.openapi.utils import get_openapi as _get_openapi
from fastapi.security.api_key import (
    APIKeyQuery as _APIKeyQuery,
    APIKeyCookie as _APIKeyCookie,
    APIKeyHeader as _APIKeyHeader,
    APIKey as _APIKey,
)

from starlette import status as _status
from starlette.routing import request_response as _request_response

from ..debug import debug

# for custom docs endpoint that doesn't use the default StandardizedJSONResponse class
from fastapi.responses import (
    Response as _Response,
    HTMLResponse as _HTMLResponse,
    JSONResponse as _JSONResponse,
)
from schemas import StandardizedJSONResponse as _StandardizedJSONResponse
from starlette.routing import Route as _Route

from .plugins import (
    APIPlugin,
    EventHandler,
    ActionHandler,
    should_ignore_plugin,
    load_plugins as _load_plugins,
    PluginLoadError,
)
from .log import Logger


class API(_FastAPI):
    """
    This class extends FastAPI with a plugin/event based system.
    """

    def __init__(
        self,
        *args,
        plugin_dir: _Path | str = None,
        whitelist: list[str] | None = None,
        blacklist: list[str] | None = None,
        title: str = "API",  # fastAPI options
        description: str = "",
        version: str = "0.0.1",
        license_info: dict[str, str] = None,
        default_response_class: type[_Response] = _StandardizedJSONResponse,
        submodule_paths: list[_Path | str] = [],
        tokens: dict[str, dict[str, str]] | _Path = {},
        token_name: str = "token",
        tokens_enabled: bool = False,
        **kwargs,
    ) -> None:
        """
        This class extends FastAPI with support for plugins and event handlers.

        Args:
            plugin_dir (Path | str, optional): The directory to load plugins from.
                Defaults to "plugins" or the API_PLUGINS environment variable.
            whitelist (list[str], optional): A list of plugins to load, using glob
                patterns. If this is specified, only plugins that match a pattern in
                this list will be loaded. Defaults to None.
            blacklist (list[str], optional): A list of plugins to ignore, using glob
                patterns. If this is specified, plugins that match a pattern in this
                list will not be loaded. Defaults to None.
            title (str, optional): The title of the API. Defaults to "API".
            description (str, optional): The description of the API. Defaults to "".
            version (str, optional): The version of the API. Defaults to "0.0.1".
            license_info (dict[str, str], optional): The license information for the
                API. Defaults to None.
            default_response_class (type[StandardizedJSONResponse], optional): The
                default response class to use for the API. Defaults to
                StandardizedJSONResponse.
            submodule_paths (list[Path | str], optional): A list of paths that plugins
                can use to import libraries and submodules. Defaults to [].
            tokens (dict[str, dict[str, str]] | Path, optional): A dictionary of
                tokens to use for authentication. If a Path is provided, the file at
                that path will be loaded as a JSON file. Defaults to {}.
            token_name (str, optional): The name of the token as a query parameter,
                cookie, or header. Defaults to "token".
            tokens_enabled (bool, optional): Whether or not to enable token-based
                authentication. Defaults to False.
            *args: Additional arguments to pass to FastAPI.
            **kwargs: Additional keyword arguments to pass to FastAPI().
        """
        super().__init__(
            title=title,
            description=description,
            version=version,
            license_info=license_info,
            default_response_class=default_response_class,
            openapi_tags=[],  # we'll add these ourselves
            *args,
            **kwargs,
        )

        if plugin_dir:
            self._plugin_dir = _Path(plugin_dir)
            self.load_plugins()
        else:
            self._plugin_dir = _os.environ.get("API_PLUGINS", "plugins")
        self._whitelist = whitelist
        self._blacklist = blacklist
        self._submodule_paths = submodule_paths
        if isinstance(tokens, _Path):
            with open(tokens) as f:
                self.tokens = _json.load(f)
        else:
            self.tokens = tokens
        self.token_name = token_name
        self.tokens_enabled = tokens_enabled
        self.logger = Logger(title.lower().replace(" ", "_"))

    def _check_token_group(self, token: str, group: str | list[str] = None) -> bool:
        """
        Checks if a token is in the specified group(s). If the group is None, will check
        if the token is in any existing group.

        Args:
            token (str): The token to check.
            group (str | list[str]): The group to check.

        Returns:
            bool: True if the token is in the group, False otherwise.
        """
        if group is None:
            for group, tokens in self.tokens.items():
                for label, value in tokens.items():
                    if token == value:
                        return True
        else:
            if isinstance(group, str):
                group = [group]
            for g in group:
                for label, value in self.tokens.get(g, {}).items():
                    if token == value:
                        return True
        return False

    def _token_dependency(
        self, group: list[str] | str = None, token_name: list[str] | str = None
    ) -> callable:
        """
        A FastAPI Security dependency that checks if a token is valid.
        """
        if token_name is None:
            token_name = self.token_name

        async def get_validated_token(
            api_key_query: str = _Security(
                _APIKeyQuery(name=token_name, auto_error=False)
            ),
            api_key_header: str = _Security(
                _APIKeyHeader(name=token_name, auto_error=False)
            ),
            api_key_cookie: str = _Security(
                _APIKeyCookie(name=token_name, auto_error=False)
            ),
        ) -> str:
            print(f"{api_key_query=} {api_key_header=} {api_key_cookie=}")
            token_value = api_key_query or api_key_header or api_key_cookie
            print(f"{token_value=}")
            print(f"checking token {token_value} in group {group}")
            if self.tokens_enabled and not self._check_token_group(token_value, group):
                print("token invalid, throwing HTTP 403")
                raise _HTTPException(
                    status_code=_status.HTTP_403_FORBIDDEN,
                    detail="Could not validate credentials",
                )
            print("token valid, returning")
            return token_value

        print("returning generated token dependency function")
        return get_validated_token

    def load_plugins(
        self,
        plugin_dir: _Path | str = None,
        whitelist: list[str] = None,
        blacklist: list[str] = None,
        submodule_paths: list[_Path | str] = None,
        fail_silently: bool = False,
    ) -> _Generator[APIPlugin, None, None]:
        """
        Loads plugins from the plugin directory.
        """
        # load plugins
        debug("loading plugins from", plugin_dir)
        self._plugins: list[APIPlugin] = _load_plugins(
            plugin_dir or self._plugin_dir,
            whitelist=whitelist or self._whitelist,
            blacklist=blacklist or self._blacklist,
            submodule_paths=submodule_paths or self._submodule_paths,
            autoload=False,
            recursive=True,
        )

        # register plugins
        for plugin in self._plugins:
            try:
                self.load_plugin(plugin, fail_silently=False)
                yield plugin
            except Exception as e:
                if fail_silently:
                    self.logger.error(f"Failed to load plugin {plugin.name}: {e}")
                else:
                    raise e
                continue

        if self.tokens_enabled:
            # Inject token dependency into routes which require it
            for route in self.routes:
                if hasattr(route.endpoint, "__token_group__") or hasattr(
                    route.endpoint, "__token_name__"
                ):
                    print(f"injecting token dependency for {route.path}")
                    group = getattr(route.endpoint, "__token_group__", None)
                    token_name = getattr(route.endpoint, "__token_name__", None)
                    route.dependant.dependencies.insert(
                        0,
                        _get_parameterless_sub_dependant(
                            depends=_Depends(self._token_dependency(group, token_name)),
                            path=route.path_format,
                        ),
                    )
                    route.body_field = _get_body_field(
                        dependant=route.dependant, name=route.unique_id
                    )
                    print(
                        f"route {route} dependant dependencies:",
                        route.dependant.dependencies,
                    )

                    # self._inject_token_dependency(route, group, token_name)

    def load_plugin(
        self, plugin: APIPlugin, fail_silently: bool = False
    ) -> tuple[callable, _APIRouter]:
        """
        Loads a single plugin.

        Args:
            plugin (APIPlugin): The plugin to load.

        Returns:
            [callable, _APIRouter]: The plugin's register function (if it has one) that
                was used to register the plugin, and the plugin's router (if it has one)
        """
        register_func: callable = None
        router: _APIRouter = None

        # Determine if the plugin should be ignored
        if should_ignore_plugin(plugin.name, self._whitelist, self._blacklist):
            return

        # Make sure the plugin is loaded
        if not plugin.loaded:
            try:
                plugin.load()
            except Exception as e:
                if fail_silently:
                    return None, None
                else:
                    raise PluginLoadError(
                        f"Error loading plugin {plugin.name}: {e}"
                    ) from e

        if plugin.has_register_function():
            # Run the plugin's register function and pass it this API instance
            plugin.register(self)
            register_func = plugin.register

        if plugin.has_routes():
            # Update our openapi tags with the plugin name and description
            openapi_tag: dict[str, str] = {
                "name": plugin.name,
                "description": plugin.description,
            }
            self.openapi_tags.append(openapi_tag)
            for route in plugin.router.routes:
                if plugin.name not in route.tags:
                    route.tags.append(plugin.name)

            # TODO: Next time on Banging Your Head Against a Wall: look into
            # TODO: FastAPI.include_router and figure out why it's not adding the above
            # TODO: dependencies

            # If the plugin doesn't have a prefix, use its name
            prefix = plugin.router.prefix or f"/{plugin.name.replace('.', '/')}"
            self.include_router(plugin.router, prefix=prefix)

            # Set the plugin's router to be returned
            router = plugin.router

        return register_func, router

    def unload_plugin(self, plugin: APIPlugin | str) -> APIPlugin:
        """
        Unloads a plugin.

        Args:
            plugin (APIPlugin | str): A plugin or the name of a plugin to unload.

        Returns:
            APIPlugin: The plugin that was unloaded.
        """
        if isinstance(plugin, str):
            plugin = self.get_plugin(plugin)
        elif isinstance(plugin, APIPlugin):
            # Search to make sure the plugin is in the API's list of plugins
            plugin = self.get_plugin(plugin.name)

        # Make sure the plugin is actually in the API
        if plugin is None:
            raise ValueError(f"Plugin '{plugin.name}' not found.")

        # Make sure the plugin is loaded
        if not plugin.loaded:
            return plugin

        if plugin.has_routes():
            # Remove the plugin's routes from the API
            for route in plugin.router.routes:
                try:
                    self.routes.remove(route)
                except ValueError:
                    continue

            # Remove the plugin's openapi tag
            self.openapi_tags = [
                tag for tag in self.openapi_tags if tag["name"] != plugin.name
            ]

        if plugin.has_unregister_function():
            # Run the plugin's unregister function
            plugin.unregister(self)

        # Remove the plugin from the list of plugins
        self._plugins.remove(plugin)

        return plugin

    def unload_plugins(self, *args, **kwargs) -> list[APIPlugin]:
        """
        Pass the given arguments to `get_plugins()` and unload all plugins that match.

        Args:
            *args: Arguments to pass to `get_plugins()`.
            **kwargs: Keyword arguments to pass to `get_plugins()`.

        Returns:
            list[APIPlugin]: A list of plugins that were unloaded.
        """
        for plugin in self.get_plugins(*args, **kwargs):
            self.unload_plugin(plugin)

    def get_plugin(self, name: str) -> APIPlugin:
        """
        Return a plugin by name.

        Args:
            name (str): The name of the plugin to get.

        Returns:
            APIPlugin: The plugin with the given name.
        """
        for plugin in self.plugins:
            if plugin.name == name:
                return plugin

    def get_plugins(
        self,
        func: callable = None,
        attr: dict[str, object] = None,
        match_all: bool = False,
        **kwargs,
    ) -> list[APIPlugin]:
        """
        Return a list of plugins that match the given criteria.

        Args:
            func (callable, optional): A function to run on each plugin. If the
                function returns True, the plugin will be returned. Defaults to None.
            attr (dict[str, object]): A dictionary of attributes and values to match
                against. If a plugin has an attribute that matches the given attributes,
                and the plugin's attribute's value matches the given value, the plugin
                will be returned.
            match_all (bool, optional): If True, all attributes and functions must
                match for a plugin to be returned. Otherwise, only one attribute or
                function must match. Defaults to False.
            **kwargs: Additional keyword arguments to match against. If a plugin has
                an attribute that matches the given keyword arguments, and the plugin's
                attribute's value matches the given value, the plugin will be returned.

        Returns:
            list[APIPlugin]: A list of plugins that match the given criteria.
        """
        plugins = []
        attr.extend(kwargs)

        for plugin in self.plugins:
            attr_matches: list[bool] = []
            func_match = True

            if attr:
                for k, v in attr.items():
                    if not hasattr(plugin, k):
                        attr_matches.append(False)
                    elif getattr(plugin, k) != v:
                        attr_matches.append(False)
                    else:
                        attr_matches.append(True)

            if func:
                func_match = func(plugin)

            if match_all:
                if all(attr_matches) and func_match:
                    plugins.append(plugin)
            else:
                if any(attr_matches) or func_match:
                    plugins.append(plugin)

        return plugins

    @property
    def plugins(self) -> list[APIPlugin]:
        """
        Returns a list of all loaded plugins.
        """
        if hasattr(self, "_plugins"):
            return self._plugins
        else:
            return []

    def get_event_handlers(
        self, event: str = None, sort: callable = None
    ) -> list[EventHandler]:
        """
        Returns a list of all event handlers for the given event.

        Args:
            event (str, optional): The event to get handlers for. If no event is
                given, all event handlers will be returned. Defaults to None.
            sort (callable, optional): A function to use to sort the event handlers.
                Defaults to None.

        Returns:
            list[EventHandler]: A list of event handlers.
        """
        event_handlers: list[EventHandler] = []
        for plugin in self.plugins:
            event_handlers.extend(plugin.get_event_handlers(event))
        if sort:
            event_handlers.sort(key=sort)
        return event_handlers

    def get_action_handlers(
        self, action: str = None, sort: callable = None
    ) -> list[ActionHandler]:
        """
        Returns a list of all action handlers for the given action.

        Args:
            action (str, optional): The action to get handlers for. If no action is
                given, all action handlers will be returned. Defaults to None.
            sort (callable, optional): A function to use to sort the event handlers.
                Defaults to None.

        Returns:
            list[ActionHandler]: A list of action handlers.
        """
        action_handlers: list[ActionHandler] = []
        for plugin in self.plugins:
            action_handlers.extend(plugin.get_action_handlers(action))
        if sort:
            action_handlers.sort(key=sort)
        return action_handlers

    def fire_event(self, name: str, *args, **kwargs) -> None:
        """
        Fires an event.

        Args:
            name (str): The name of the event to fire.
        """
        for handler in self.get_event_handlers(name, sort=lambda h: h.priority):
            print("Firing event handler", handler)
            handler(*args, **kwargs)

    def do(self, action: str, *args, **kwargs) -> None:
        """
        Runs an action.

        Args:
            action (str): The name of the action to run.
        """
        for handler in self.get_action_handlers(action, sort=lambda h: h.priority):
            print("Running action handler", handler)
            handler(*args, **kwargs)

    def run(
        self,
        *args,
        host: str = "127.0.0.1",
        port: int = 8000,
        headers: list[tuple[str, str]] = [],
        ssl: bool = False,
        ssl_keyfile: str = "key.pem",
        ssl_certfile: str = "cert.pem",
        reload: bool = False,
        reload_dirs: list[str] | None = None,
        workers: int = 1,
        log_level: str = "info",
        **kwargs,
    ) -> None:
        """
        Runs the API.

        Args:
            host (str, optional): The host to run the API on. Defaults to "127.0.0.1".
            port (int, optional): The port to run the API on. Defaults to 8000.
            headers (list[tuple[str, str]], optional): A list of headers to add to
                every response. Defaults to [].
            ssl (bool, optional): Whether to run the API with SSL. Defaults to False.
            ssl_keyfile (str, optional): The path to the SSL key file. Defaults to
                "key.pem".
            ssl_certfile (str, optional): The path to the SSL cert file. Defaults to
                "cert.pem".
            reload (bool, optional): Whether to reload the API on file changes. Defaults
                to False.
            reload_dirs (list[str], optional): A list of directories to watch for file
                changes. Defaults to None.
            workers (int, optional): The number of worker threads to run the API with.
                Defaults to 1.
            log_level (str, optional): The log level to use. Defaults to "info".
            *args: Additional arguments to pass to uvicorn.run().
            **kwargs: Additional arguments to pass to uvicorn.run().

        Notes:
            See https://github.com/encode/uvicorn/blob/master/uvicorn/main.py#L453 for
            a list of arguments that can be passed to uvicorn.run().
        """
        import uvicorn
        import __main__ as main

        # Set up the logger to use uvicorn's logger
        self.logger.default_name = "uvicorn.asgi"
        self.logger.error_name = "uvicorn.error"

        ssl_opts: dict[str, str] = {}
        if ssl:
            ssl_opts = {"ssl_keyfile": ssl_keyfile, "ssl_certfile": ssl_certfile}

        uvicorn.run(
            *args,
            host=host,
            port=port,
            headers=headers,
            reload=reload,
            reload_dirs=reload_dirs,
            workers=workers,
            log_level=log_level,
            **ssl_opts,
            **kwargs,
        )


def require_token(group: str | list[str] = None, token_name: str = "token") -> callable:
    """
    Decorator for APIPlugin methods to require a token when accessing the endpoint.
    Tokens can be passed as a query parameter, a header, or a cookie.

    Args:
        group (str, list[str], optional): A token group that must be used when accessing
            the endpoint, e.g.: "admin" or ["admin", "user"]. If no group is given, any
            token will be accepted. Defaults to None.
        token_name (str, optional): The name of the token to use. Defaults to "token".
    """
    if isinstance(group, str):
        group = [group]

    @_wraps(require_token)
    def decorator(func: callable) -> callable:
        nonlocal group, token_name
        func.__token_name__ = token_name
        func.__token_group__ = group
        print(
            f"setup token for function {func.__name__}:",
            func.__token_name__,
            func.__token_group__,
        )
        return func

    return decorator
