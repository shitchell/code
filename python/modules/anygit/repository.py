from __future__ import annotations
from ..types import Branch

from abc import ABC as _ABC, abstractmethod as _abstractmethod
from pydantic import BaseModel as _BaseModel, validator as _validator


class Repository(_ABC, _BaseModel):
    """
    A connection to a git repository. This can be a local repository or a remote one
    hosted on a supported cloud service like GitHub.
    """

    url: str
    branch: Branch | None = None
