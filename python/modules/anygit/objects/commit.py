"""
Commit and Commitish classes for representing git commits and commit-ish objects. The
git docs describe a "commit-ish" object as any object that can be resolved to a commit,
such as a commit, tag, or branch. This module provides classes to represent these
objects and their relationships to each other.
"""

from . import GitFuzzyObject
from .core import GitUser
from datetime import datetime as _datetime

from abc import abstractmethod as _abstractmethod
from typing import Callable as _Callable
from inspect import _empty


class Commitish(GitObject):
    """
    Any git object that resolves to a commit, e.g.: a branch or tag (or a commit itself)
    """


class Commitish(GitFuzzyObject):
    """
    Any git object that resolves to a commit, e.g.: a branch or tag (or a commit itself)
    """

    def __init__(self, sha: str, parents: list[Commit] | None | _empty = _empty):
        """
        Initialize a new Commitish object. If the only argument provided is the SHA-1,
        the object will be fetched using the repository's `get_commit` method.

        Args:
            sha (str): The commit's SHA-1 hash
            parents (list[Commit], None, _empty): The commit's parent commits. If
                explicitly set to None or an empty list, the object will be considered
                a root or orphan commit. If not provided (i.e.: is _empty), the object
                will be fetched using the repository's `get_commit` method. Defaults to
                _empty.
        """
        self.sha = sha
        if parents is _empty:
            self.commit = self.repo.get_commit(sha)
        self.message = message

    def diff(self, other: Commitish) -> GitDiff:
        return self.repo.diff(self, other)

    def log(self, limit: int = None) -> GitLog:
        return self.repo.log(self, limit)

    def contains(self, commitish: Commitish) -> bool:
        """
        Determine whether this commit-ish object has another commit-ish object as an
        ancestor.
        """
        try:
            return self.repo.contains(self, commitish)
        except NotImplementedError:
            return commitish in self.log()
        except Exception as e:
            # If the repo.contains(...) call legitimately failed, re-raise the exception
            raise e

    def exists(self) -> bool:
        """
        Determine whether a commit-ish object exists in the repository
        """
        return self.repo.exists(self)

    def __eq__(self, other: Commitish) -> bool:
        return self.sha == other.sha

    def __ne__(self, other: Commitish) -> bool:
        return self.sha != other.sha

    def __lt__(self, other: Commitish) -> bool:
        return self.commit.author_ts < other.commit.author_ts


class Commit(Commitish):
    """
    A git commit
    """

    def __init__(
        self,
        sha: str,
        message: str | None = None,
        committer: GitUser | None = None,
        committer_ts: _datetime | None = None,
        author: GitUser | None = None,
        author_ts: _datetime | None = None,
        parents: list[Commit] = None,
    ):
        super.__init__(self, sha, parents)

    def commit(self) -> Commit:
        return self


class GitRef(Commit):
    """
    A git reference, such as a branch or tag
    """

    def __init__(self, name: str, commit: Commit):
        self.name = name
        self.commit = commit

    def __str__(self) -> str:
        return self.name

    def __repr__(self) -> str:
        return f"<{self.name}>"


class GitBranch(GitRef):
    """
    A git branch
    """

    def __init__(self, name: str, commit: Commit):
        super().__init__(name, commit)


class GitTag(GitRef):
    """
    A git tag
    """

    def __init__(
        self,
        name: str,
        commit: Commit,
        tagger: GitUser | None = None,
        tagger_ts: _datetime | None = None,
    ):
        super().__init__(name, commit)
        self.tagger = tagger
        self.tagger_ts = tagger_ts
        self.message = message
        self.commit = commit
        self.commitish = commitish


class GitLog:
    """
    Provides access to a commit's history
    """

    def __init__(
        self, start: Commit, end: Commit, filter: GitLogFilter | _Callable | None
    ):
        self.start = start
        self.end = end
        self.filter = filter


class GitLogFilter:
    """
    A simple set of rules for filtering GitLog results
    """
