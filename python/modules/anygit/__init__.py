"""
This module provides an easy-to-use ORM-like interface to git repositories, allowing
you to interact with them in a more pythonic way that is agnostic to the underlying
git implementation or host.

Example:
    >>> from anygit import Repository
    >>> repo: Repository = Repository('github://user/repo')
    >>> clone: Repository = repo.clone('/path/to/clone')
    >>> clone.checkout('master')
    >>> clone.pull()
    >>> clone.commit('Added new feature', empty=True)
    >>> clone.push()
    >>> print(repo.branches.get("master").head.commit.message)
    'Added new feature'

That is, a Repository object can be a local git repository or a remote repository hosted
on any supported platform, and the same interface can be used to interact with it.

Limitations:
Every place where a git repository might live will have some different features to
offer, so a singular interface that works for all of them will have to be limited in
some ways. For example, GitHub allows you to create a lightweight or annotated tag via
their API, but Azure DevOps only permits annotated tags. In this case, calling
`commit.tag('v1.0.0')` to create a lightweight tag in an Azure DevOps repository will
raise a NotImplementedError.

We also don't support literally every platform. As time goes on, we will aim to support
more platforms, but it is impossible for us to support every single one. If you have a
platform you would like to see added, please open a ticket in our GitHub repository <3

Supported Platforms:
- Local repositories
- GitHub
- Azure DevOps

Supported Features:
- Cloning
- Fetching
- Pulling
- Checking out branches
- Creating new branches
- Committing
- Tagging
- Pushing
- Merging
- Rebasing
- Stashing
- Cherry-picking
- Resetting
- Reverting
- Diffing
- Logging
- Blaming
- Listing branches
- Creating Pull Requests (only for hosted repositories, not local)
"""

from .repository import Repository

__all__ = ["Repository"]
