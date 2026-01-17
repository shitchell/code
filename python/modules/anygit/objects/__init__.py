"""
Git supports 4 types of objects: blobs, trees, commits, and tags. This module provides
classes to represent these objects, as well as the relationships between them and
groupings of similar objects (e.g.: git calls an object that can be a commit, tag, or
branch "commit-ish"). These classes are used by the Repository class to provide a more
pythonic interface to git repositories.
"""
from __future__ import annotations as _annotations
from .blob import Blob
from .tree import Treeish, Tree
from .commit import Commitish, Commit, Branch, Tag
from ..types import Repository

import re as _re
from enum import Enum as _Enum
from abc import ABC as _ABC, abstractmethod as _abstractmethod
from pydantic import BaseModel as _BaseModel, validator as _validator


class GitObjectType(_Enum):
    BLOB = Blob
    TREE = Tree
    COMMIT = Commit
    BRANCH = Branch
    TAG = Tag

    @staticmethod
    def from_str(type_str: str):
        return GitObjectType[type_str.upper()]

    def __call__(self, *args, **kwargs):
        return self.value(*args, **kwargs)

    def __str__(self):
        return self.name.lower()

    def __repr__(self):
        return f"<GitObjectType.{self.name}>"


class GitHash(_BaseModel):
    value: str

    @_validator("value")
    def validate(cls, value):
        if not isinstance(value, str):
            raise TypeError("Hash must be a string")
        if not re.fullmatch(r"[0-9a-f]{40}", value):
            raise ValueError("Hash must be a 40-character hexadecimal string")
        return value

    def short(self, length: int = 8) -> str:
        return self.value[:length]

    @staticmethod
    def from_bytes(value: bytes) -> GitHash:
        return cls(value.hex())

    @staticmethod
    def to_bytes() -> bytes:
        return bytes.fromhex(self.value)

    @staticmethod
    def generate() -> GitHash:
        return cls(os.urandom(20).hex())

    @staticmethod
    def __str__(self):
        return self.oid

    def __repr__(self):
        return f"<GitOID {self.oid}>"


class GitObject(_ABC, _BaseModel):
    """
    Any git object, such as a blob, tree, commit, branch, or tag. This class is not
    intended to be instantiated directly, but rather to be subclassed by the more
    specific object types.
    """

    # oid is the SHA-1 hash of the object in the git object database
    oid: str
    repo: Repository

    @_abstractmethod
    def get_contents(self) -> object:
        """
        Get the contents of this object.

        Returns:
            Any: The contents of this object.
        """

    def __str__(self):
        return f"{self.type} {self.oid}"

    def __repr__(self):
        return f"<{self.type} {self.oid}>"

    def __eq__(self, other):
        return self.oid == other.oid

    def __ne__(self, other):
        return self.oid != other.oid

    def __hash__(self):
        return hash(self.oid)

    def __bool__(self):
        return bool(self.oid)


class GitFuzzyObject(GitObject):
    """
    Used in places where similar types of objects are expected, e.g.: when checking out,
    any "commit-ish" object -- a branch, tag, or commit -- can be used.
    """

    @abstractmethod
    def resolve(self) -> GitObject:
        """
        Returns the resolved object
        """
