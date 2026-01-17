"""
Type checking and type hinting for AnyGit.
"""

from typing import TYPE_CHECKING as _TYPE_CHECKING

if _TYPE_CHECKING:
    from .repository import Repository
    from .objects import (
        GitObject,
        GitFuzzyObject,
        Commit,
        Branch,
        Tag,
        Tree,
        Blob,
        Commitish,
        Branchish,
        Tagish,
        Treeish,
        Blobish,
    )
