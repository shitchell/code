"""
Provides authentication for the Trinoor API.
"""
# Token auth adapted from:
# https://gist.github.com/nilsdebruin/a78c5e200e7df014a92580b4fc51c53f

from fastapi import HTTPException, Security
from fastapi.security.api_key import APIKeyQuery, APIKeyCookie, APIKeyHeader, APIKey
from starlette.status import HTTP_403_FORBIDDEN


async def get_api_key(
    value: str,
    api_key_query: str = Security(APIKeyQuery(name="token", auto_error=False)),
    api_key_header: str = Security(APIKeyHeader(name="token", auto_error=False)),
    api_key_cookie: str = Security(APIKeyCookie(name="token", auto_error=False)),
):
    if value == api_key_query:
        return api_key_query
    elif value == api_key_header:
        return api_key_header
    elif value == api_key_cookie:
        return api_key_cookie
    else:
        raise HTTPException(
            status_code=HTTP_403_FORBIDDEN, detail="Could not validate credentials"
        )


class TokenGroup(Security):
    """
    A FastAPI dependency  that accepts a token group (e.g.: "admin", "general", etc.) on
    instantiation and modifies the endpoint to only accept requests from tokens that are
    part of that group.
    """

    default: str = "api"

    def __init__(self, group: str = default, **kwargs):
        """
        Args:
            group (str): The token group to accept.
        """
        self.group = group
        super().__init__(**kwargs)

    def __call__(self, token: str = get_api_key()):
        """
        Args:
            token (str): The token to check.
        """
        if token not in tokens[self.group]:
            raise HTTPException(status_code=HTTP_403_FORBIDDEN, detail="Invalid token")
        return token

    def __repr__(self):
        return f"TokenGroup({self.group})"

    def __str__(self):
        return f"TokenGroup({self.group})"

    def __eq__(self, other):
        return self.group == other.group

    def __hash__(self):
        return hash(self.group)


class Token:
    """
    Stores a token and its group.
    """

    def __init__(self, value: str, group: str = None):
        """
        Args:
            token (str): The token.
            group (str): The token group.
        """
        self.value = value
        self.group = group

    def __repr__(self):
        r: str = f"Token({self.value}"
        if self.group:
            r += f", {self.group}"
        r += ")"
        return r

    def __str__(self):
        s: str = ""
        if self.group:
            s += f"{self.group}:"
        s += self.value
        return s

    def __eq__(self, other: object):
        if not isinstance(other, Token):
            return False
        return self.value == other.value and self.group == other.group

    def __hash__(self):
        return hash(self.value) + hash(self.group)
