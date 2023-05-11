"""
Command line interface for running an instance of the Trinoor API
"""


import argparse
import json
import logging
import os
import sys
import textwrap

from argparse import (
    ArgumentParser,
    _ArgumentGroup as ArgumentGroup,
    Namespace,
    RawDescriptionHelpFormatter,
)
from pathlib import Path
from .. import config  # TODO: replace with updated config class
from ..debug import debug

from fastapi import Depends, Request
from fastapi.openapi.docs import get_swagger_ui_html
from fastapi.openapi.utils import get_openapi

from .core import API
from .annotations import token
from starlette.responses import RedirectResponse, JSONResponse


# Load the config file *first* regardless of where it shows up in the argument list so
# that we can use its values as defaults for the other arguments
config_parser: ArgumentParser = argparse.ArgumentParser(add_help=False)
config_parser.add_argument(
    "-c",
    "--config",
    type=Path,
    default=Path("config/settings.json"),
    help="the path to the settings file to use",
)
config_args = config_parser.parse_known_args()[0]
config.CONFIG_PATH = config_args.config

debug(f"Loaded config '{config.CONFIG_PATH}':", config.get())

# Now the *actual* parser
parser: ArgumentParser = argparse.ArgumentParser(
    prog=__package__, formatter_class=RawDescriptionHelpFormatter
)
api_args: ArgumentGroup = parser.add_argument_group("api options")
uvi_args: ArgumentGroup = parser.add_argument_group("uvicorn options")
api_args.add_argument(
    "-c",
    "--config",
    type=Path,
    default=config.CONFIG_PATH,
    help="the path to the settings file to use",
)
default_config_dir: Path = Path(
    config.get("plugins.config_dir", config.CONFIG_PATH.parent)
)
api_args.add_argument(
    "-C",
    "--config-dir",
    type=Path,
    default=default_config_dir,
    help="the directory containing configuration files",
)
api_args.add_argument(
    "-T",
    "--token-file",
    type=Path,
    default=config.get("server.token_file", default_config_dir / "tokens.json"),
    help="the path to the token file",
)
api_args.add_argument(
    "--enable-tokens",
    action="store_true",
    dest="tokens_enabled",
    default=config.get("server.tokens_enabled", True),
    help="enable token authentication",
)
api_args.add_argument(
    "--disable-tokens",
    action="store_false",
    dest="tokens_enabled",
    help="disable token authentication",
)
api_args.add_argument(
    "-P",
    "--plugin-dir",
    default=config.get("plugins.dir", "plugins"),
    type=Path,
    help="the plugin directory",
)
api_args.add_argument(
    "-W",
    "--whitelist",
    type=str,
    default=config.get("plugins.enabled", []),
    action="append",
    help="load only the specified plugins. can be specified multiple times",
)
api_args.add_argument(
    "-B",
    "--blacklist",
    type=str,
    default=config.get("plugins.disabled", []),
    action="append",
    help="do not load the specified plugins. can be specified multiple times",
)
api_args.add_argument(
    "--title",
    type=str,
    default=config.get("server.title", "DevAPI"),
    help="the title of the API",
)
api_args.add_argument(
    "--description",
    type=str,
    default=config.get("api.description", "A development API"),
    help="the description of the API",
)
api_args.add_argument(
    "--version",
    type=str,
    default=config.get("api.version", "0.0.1"),
    help="the version of the API",
)
api_args.add_argument(
    "--license",
    type=str,
    default=config.get("api.license.name"),
    help="the license of the API",
)
api_args.add_argument(
    "--license-url",
    type=str,
    default=config.get("api.license.url"),
    help="the license URL of the API",
)
api_args.add_argument(
    "--sys-path",
    type=Path,
    default=config.get("plugins.pythonpath", []),
    action="append",
    help="add the specified path to sys.path. can be specified multiple times",
)
api_args.add_argument(
    "--terms-of-service",
    type=str,
    default=config.get("api.terms"),
    help="the terms of service of the API",
)
api_args.add_argument(
    "--contact",
    type=str,
    default=config.get("api.contact"),
    help="the contact information of the API",
)
api_args.add_argument(
    "--docs-url",
    type=str,
    default=config.get("api.docs_url"),
    help="the documentation URL of the API",
)
api_args.add_argument(
    "--openapi-url",
    type=str,
    default=config.get("api.openapi_url"),
    help="the OpenAPI URL of the API",
)
uvi_args.add_argument(
    "-H",
    "--host",
    type=str,
    default=config.get("server.host", "127.0.0.1"),
    help="the host to bind to",
)
uvi_args.add_argument(
    "-p",
    "--port",
    default=config.get("server.port", 5005),
    type=int,
    help="The port to bind to",
)
uvi_args.add_argument(
    "--ssl",
    dest="ssl",
    action="store_const",
    const=True,
    default=config.get("server.ssl.enabled", False),
    help="enable SSL",
)
uvi_args.add_argument(
    "--no-ssl",
    dest="ssl",
    action="store_const",
    const=False,
    default=config.get("server.ssl.enabled", False),
    help="disable SSL",
)
uvi_args.add_argument(
    "--ssl-keyfile",
    type=Path,
    default=config.get("server.ssl.key"),
    help="the SSL keyfile to use",
)
uvi_args.add_argument(
    "--ssl-certfile",
    type=Path,
    default=config.get("server.ssl.cert"),
    help="the SSL certfile to use",
)
uvi_args.add_argument(
    "--header",
    type=str,
    action="append",
    default=list(
        f"{k}: {v}"
        for k, v in config.get(
            "server.response_headers", {"Server": {__package__}}
        ).items()
    ),
    help=textwrap.dedent(
        """a custom header to send with every response.
            e.g. --header 'X-My-Header: value'"""
    ),
)
uvi_args.add_argument(
    "--root-path",
    type=str,
    default=config.get("server.root_path", ""),
    help="prefix for all endpoints",
)
uvi_args.add_argument(
    "--app-dir",
    type=Path,
    default=config.get("server.app_dir", "app"),
    help="the directory containing the app",
)
uvi_args.add_argument(
    "-r",
    "--reload",
    dest="reload",
    action="store_const",
    const=True,
    default=config.get("server.reload.enabled", False),
    help="reload the server on changes to watched files or directories",
)
uvi_args.add_argument(
    "-R",
    "--no-reload",
    dest="reload",
    action="store_const",
    const=False,
    default=config.get("server.reload.enabled", False),
    help="do not reload the server on changes to watched files or directories",
)
uvi_args.add_argument(
    "--reload-dir",
    action="append",
    default=config.get("server.reload.dirs", []),
    type=Path,
    help="a directory to watch for changes. can be specified multiple times",
)
uvi_args.add_argument(
    "--reload-include",
    action="append",
    default=config.get("server.reload.includes", []),
    type=Path,
    help="watch files matching pattern for changes. can be specified multiple times",
)
uvi_args.add_argument(
    "--reload-exclude",
    action="append",
    default=config.get("server.reload.excludes", []),
    type=Path,
    help="don't reload files matching pattern. can be specified multiple times",
)
uvi_args.add_argument(
    "--reload-delay",
    type=float,
    default=config.get("server.reload.delay", 1),
    help="delay between detecting file changes and reloading",
)
uvi_args.add_argument(
    "--workers",
    default=config.get("server.workers", 1),
    type=int,
    help="number of worker processes / threads",
)
uvi_args.add_argument(
    "--log-level",
    default=config.get("server.log_level", "info"),
    type=str,
    help="the log level to use",
)
parser.epilog = textwrap.dedent(
    """
    TODO: add an epilog
"""
)
args: Namespace = parser.parse_args()

# Load tokens if they exist
tokens: dict[str, dict[str, str]] = {}
if args.tokens_enabled and args.token_file and args.token_file.exists():
    with open(args.token_file, "r") as f:
        tokens = json.load(f)

print(
    f"""
    Creating API instance:
        {os.getcwd()=}
        {args.config=}
        {args.app_dir=}
        {args.plugin_dir=}
        {args.whitelist=}
        {args.blacklist=}
        {args.title=}
        {args.description=}
        {args.version=}
        {args.license=}
        {args.license_url=}
        {args.sys_path=}
        {args.terms_of_service=}
        {args.contact=}
        {args.docs_url=}
        {args.openapi_url=}
        {args.root_path=}
        {args.tokens_enabled=}
        {args.token_file=}
"""
)

# Set the docs url
docs_url: str = args.docs_url or "/docs"
openapi_url: str = args.openapi_url or "/openapi.json"

api: API = API(
    plugin_dir=args.plugin_dir,
    whitelist=args.whitelist,
    blacklist=args.blacklist,
    title=args.title,
    description=args.description,
    version=args.version,
    license_info=(
        {"name": args.license, "url": args.license_url} if args.license else None
    ),
    tokens=tokens,
    tokens_enabled=args.tokens_enabled,
    submodule_paths=args.sys_path,
    root_path=args.root_path,
    terms_of_service=args.terms_of_service,
    contact_info={"email": args.contact} if args.contact else None,
    **{
        "docs_url": args.docs_url
        if (args.docs_url and not args.tokens_enabled)
        else None
    },
    **{
        "openapi_url": args.openapi_url
        if (args.openapi_url and not args.tokens_enabled)
        else None
    },
)

# If tokens are enabled, protect the docs and openapi endpoints
if args.tokens_enabled:
    api.foobar = "baz"

    print("Tokens are enabled, protecting docs and openapi endpoints")

    @api.get("/open-api.json", tags=["documentation"], include_in_schema=False)
    @token()
    async def _get_openapi(
        token_value: str = Depends(api._token_dependency()),
    ) -> JSONResponse:
        print("Custom openapi endpoint, using token", token_value, flush=True)
        response = JSONResponse(
            get_openapi(title=args.title, version=args.version, routes=api.routes)
        )
        return response

    @api.get(
        "/documentation",
        tags=["documentation"],
        include_in_schema=False,
    )
    @token()
    async def _get_docs(
        request: Request, token_value: str = Depends(api._token_dependency())
    ) -> JSONResponse:
        print("Custom docs endpoint, using token", token_value, flush=True)
        response = get_swagger_ui_html(openapi_url="/open-api.json", title="docs")
        response.set_cookie(
            api.token_name,
            value=token_value,
            domain=request.url.hostname,
            httponly=True,
            max_age=1800,
            expires=1800,
        )
        return response


# Create

# Load plugins separately from the API instansiation so that we can loop over
# them and print out information about each as it is loaded.
plugins = []
print(
    f"""
    Loading plugins:
        {args.plugin_dir=}
        {args.whitelist=}
        {args.blacklist=}
        {args.sys_path=}
"""
)
for plugin in api.load_plugins(
    args.plugin_dir, args.whitelist, args.blacklist, args.sys_path
):
    plugins.append(plugin)
    print(f"Loaded plugin: {plugin}")
print("Loaded:", plugins)

# Process the --header arguments
headers: list[tuple[str, str]] = []
for header in args.header:
    name, value = header.split(":", 1)
    headers.append((name.strip(), value.strip()))

print(
    f"""
    Starting server:
        {args.host=}
        {args.port=}
        {headers=}
        {args.ssl=}
        {args.ssl_keyfile=}
        {args.ssl_certfile=}
        {args.token_file=}
        {args.tokens_enabled=}
        {args.reload=}
        {args.reload_dir=}
        {args.reload_include=}
        {args.reload_exclude=}
        {args.reload_delay=}
        {args.workers=}
        {args.log_level=}
        {args.app_dir=}
        {args.root_path=}
"""
)

if __name__ == "__main__":
    api.run(
        f"trinoor.api.__main__:api",
        host=args.host,
        port=args.port,
        headers=headers,
        ssl=args.ssl,
        ssl_keyfile=args.ssl_keyfile if args.ssl else None,
        ssl_certfile=args.ssl_certfile if args.ssl else None,
        workers=args.workers,
        log_level=args.log_level,
        reload=args.reload,
        reload_dirs=args.reload_dir if args.reload else None,
        reload_includes=args.reload_include if args.reload else None,
        reload_excludes=args.reload_exclude if args.reload else None,
        reload_delay=args.reload_delay if args.reload else None,
        # root_path=args.root_path,
        # app_dir=args.app_dir,
    )
