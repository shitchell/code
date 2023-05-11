"""
A wrapper class around the azure-devops library

TODO:
- Do a search for "git_client" and "_git_client" to ensure none are being passed to
  functions that don't need them
- Above but for "core_client" and "connection"
- Get user id
"""
import re as _re
from azure.devops.v5_1.git import (
    GitRefUpdate as _GitRefUpdate,
    GitPullRequest as _GitPullRequest,
    GitPullRequestSearchCriteria as _GitPullRequestSearchCriteria,
)
from trinoor.config import Config as _Config
from msrest.authentication import BasicAuthentication as _BasicAuthentication
from azure.devops.connection import Connection as _Connection
from azure.devops.released.git.git_client import GitClient as _GitClient
from azure.devops.released.core.core_client import CoreClient as _CoreClient
from typing import Literal as _Literal
from trinoor.util.text import is_uuid as _is_uuid


_organization = "trinoor"


class ADO:
    """
    API for Azure DevOps via the azure-devops library.
    """

    _pat: str
    _project: str
    _repo: str
    _config: _Config

    _git_client: _GitClient = None
    _core_client: _CoreClient = None
    _connection: _Connection = None

    def __init__(
        self,
        pat: str = None,
        organization: str = None,
        project: str = None,
        repo: str = None,
        config: _Config | str = None,
    ) -> None:
        self._pat = None
        self._project = None
        self._repo = None
        self._config = None
        self.organization: str = organization or _organization
        if config is None:
            self._config = config
        else:
            if isinstance(config, str):
                config = _Config(config)
            elif not isinstance(config, _Config):
                raise ValueError("config must be a string or a Config object")
            self._load_config(config)
        if pat:
            self.pat = pat
        if project:
            self._project: str = project
        if repo:
            self._repo: str = repo
        # create the connection, core client, and git client
        if self.pat:
            self._pat: str = pat
            self._initialize_connection()
            self._initialize_core_client()
            self._initialize_git_client()
            self._connection.authenticate()

    def _load_config(self, config: _Config):
        self._config = config
        self.pat = self._config.get(f"api.{self.organization}.personal_access_token")

    @property
    def pat(self) -> str:
        return self._pat

    @pat.setter
    def pat(self, value: str) -> None:
        """
        Sets the personal access token after checking that it is valid

        Args:
            value (str): The personal access token
        """
        self._initialize_connection(value).authenticate
        self._pat = value

    @property
    def org_url(self) -> str:
        if self.organization:
            return f"https://dev.azure.com/{self.organization}"

    def _initialize_git_client(self) -> _GitClient:
        """
        Get a cached git client or create a new one

        Returns:
            any:
        """
        if self._git_client is None:
            connection = self._initialize_connection(self.pat)
            self._git_client = connection.clients.get_git_client()
        return self._git_client

    def _initialize_core_client(self) -> _CoreClient:
        if self._core_client is None:
            connection = self._initialize_connection(self.pat)
            # Get a client (the "core" client provides access to projects, teams, etc)
            self._core_client = connection.clients.get_core_client()
        return self._core_client

    def _initialize_connection(self, pat: str = None) -> _Connection:
        if self._connection is None:
            pat = pat or self.pat
            credentials = _BasicAuthentication("", pat)
            self._connection: _Connection = _Connection(
                base_url=self.org_url, creds=credentials
            )
        return self._connection

    def get_all_pull_requests(
        self,
        project_name: str = None,
        repo: str = None,
        status: str = None,
        creator_id: str = None,
        reviewer_id: str = None,
        source_ref_name: str = None,
        target_ref_name: str = None,
    ) -> list[_GitPullRequest]:
        """
        Get all pull requests using filters.

        Args:
            project_name (str, optional): The name of the project. Defaults to None.
            repo (str, optional): The name or ID of the repo. Defaults to None.
            status (_Literal["Active", "Draft", "Abandoned"], optional): The status of
                the pull request. Defaults to None.
            creator_id (str, optional): The ID of the creator. Defaults to None.
            reviewer_id (str, optional): The ID of the reviewer. Defaults to None.
            source_ref_name (str, optional): The source branch name. Defaults to None.
            target_ref_name (str, optional): The target branch name. Defaults to None.

        Returns:
            list[_GitPullRequest]: A list of pull requests
        """
        project_name: str = project_name or self._project
        # check if repo id is a uuid or a repo name
        if not _is_uuid(repo):
            repo = self.get_repo_id(project_name, repo)
        search_criteria = _GitPullRequestSearchCriteria()
        pull_requests = self._git_client.get_pull_requests_by_project(
            project_name, search_criteria
        )
        return pull_requests

    def get_repo_id(self, project_name: str = None, repo_name: str = None) -> str:
        """
        Get the ID of a repo

        Args:
            project_name (str, optional): The name of the project. Defaults to None.
            repo_name (str, optional): The name of the repo. Defaults to None.

        Returns:
            str: The ID of the repo
        """
        # Check if the name is a uuid or a repo name
        if _is_uuid(repo_name):
            return repo_name

        project_name: str = project_name or self._project
        repo_name: str = repo_name or self._repo

        # Throw an error if the project or repo name is not set
        if not project_name and not repo_name:
            return

        project = self._core_client.get_project(project_name)
        repos = self._git_client.get_repositories(project.id)
        for repo in repos:
            if repo.name == repo_name:
                return repo.id

    def branch_exists(
        self, branch_name: str, project_name: str = None, repo_id: str = None
    ) -> bool:
        """
        Check if a branch exists

        Args:
            branch_name (str): The name of the branch
            project_name (str, optional): The name of the project. Defaults to None.
            repo_id (str, optional): A repo ID. If this is provided, the branch and
                project can be left out. Defaults to None.

        Returns:
            bool: True if the branch exists, False otherwise
        """
        repo_id: str = repo_id or self._repo
        project_name: str = project_name or self._project

        # Check if the repo id is a uuid or a repo name
        if not _is_uuid(repo_id):
            repo_id = self.get_repo_id(project_name, repo_id)

        # check to see if the branch already exists in the repo, if it is break the loop
        branch_exists = False
        branches = self._git_client.get_branches(repo_id)
        for branch in branches:
            if branch.name == branch_name:
                branch_exists = True
                break
        return branch_exists

    def create_branch(
        self,
        source_branch_name: str,
        branch_name: str,
        project_name: str = None,
        repo_name: str = None,
    ) -> str:
        project_name: str = project_name or self._project
        repo_name: str = repo_name or self._repo
        repo_id = self.get_repo_id(project_name, repo_name)

        # check if branch exists
        branch_exists = self.branch_exists(branch_name, project_name, repo_id=repo_id)
        if branch_exists:
            return f"Branch {branch_name} already exists"
            # return BranchExistsError(f"Branch {branch_name} already exists")
        else:
            create_branch_ref_object = _GitRefUpdate()
            create_branch_ref_object.name = "refs/heads/" + branch_name
            # all gitRef objects must have an old_object_id, Below is the case needed
            # for a new branch.
            create_branch_ref_object.old_object_id = (
                "0000000000000000000000000000000000000000"
            )

            source_branch_commit_id = self.get_branch_head(
                repo_id, source_branch_name, project_name
            )
            create_branch_ref_object.new_object_id = source_branch_commit_id

            self._git_client.update_refs([create_branch_ref_object], repo_id)
            return f"{create_branch_ref_object.name} created"

    # Replaces get_source_branch_commit_id
    def get_branch_head(
        self, repo_id: str, branch_name: str, project_name: str = None
    ) -> str:
        """
        Get the commit hash of the HEAD of a branch

        Args:
            repo_id (str): The ID of the repo
            branch_name (str): The name of the branch
            project_name (str, optional): The name of the project. Defaults to None.

        Returns:
            str: The commit hash of the HEAD of the branch
        """
        project_name: str = project_name or self._project
        # check if repo id is a uuid or a repo name
        if not _is_uuid(repo_id):
            repo_id = self.get_repo_id(project_name, repo_id)
        branches = self._git_client.get_branches(repo_id)
        for branch in branches:
            if branch.name == branch_name:
                return branch.commit.commit_id

    def azure_test_check(self, data: dict[str, object]) -> bool:
        """
        Check if a dictionary contains test data from an Azure webhook

        Args:
            data (dict[str, object]): The dictionary to check

        Returns:
            bool: True if the dictionary contains test data, False otherwise
        """
        return_bool = False
        if data["eventType"] == "git.push":
            if data["resource"]["pushedBy"]["displayName"] == "Jamal Hartnett":
                return_bool = True
        elif (
            data["eventType"] == "git.pullrequest.updated"
            or data["eventType"] == "git.pullrequest.created"
        ):
            if data["resource"]["createdBy"]["displayName"] == "Jamal Hartnett":
                return_bool = True
        elif data["eventType"] == "ms.vss-code.git-pullrequest-comment-event":
            if data["resource"]["comment"]["author"]["displayName"] == "Jamal Hartnett":
                return_bool = True
        elif data["eventType"] == "git.pullrequest.merged":
            if data["resource"]["createdBy"]["displayName"] == "Jamal Hartnett":
                return_bool = True
        return return_bool

    def check_pr_exists(
        self,
        source_branch_name: str,
        target_branch_name: str,
        project_name: str = None,
        repo: str = None,
        pull_request_id: str = None,
        status: _Literal["Active", "Draft", "Abandoned"] = None,
        creator_id: str = None,
        reviewer_id: str = None,
    ) -> bool:
        project_name: str = project_name or self._project
        repo: str = repo or self._repo
        pull_requests = self.get_all_pull_requests(project_name)
        pr_exists = False
        for pr in pull_requests:
            if (
                pr.source_ref_name == "refs/heads/" + source_branch_name
                and pr.target_ref_name == "refs/heads/" + target_branch_name
            ):
                pr_exists = True
        return pr_exists

    def create_pull_request(
        self,
        target_branch_name: str,
        source_branch_name: str,
        pull_request_title: str,
        pull_request_description: str,
        project_name: str = None,
        repo_name: str = None,
    ) -> _GitPullRequest:
        """
        Create a pull request

        Args:
            target_branch_name (str): The name of the target branch
            source_branch_name (str): The name of the source branch
            pull_request_title (str): The title of the pull request
            pull_request_description (str): The description of the pull request
            project_name (str, optional): The name of the project. Defaults to None.
            repo_name (str, optional): The name of the repo. Defaults to None.

        Raises:
            BranchNotFoundError: If the source or target branch does not exist

        Returns:
            _GitPullRequest: The pull request object
        """
        project_name: str = project_name or self._project
        repo_name: str = repo_name or self._repo
        repo_id = self.get_repo_id(project_name, repo_name)
        if not self.branch_exists(source_branch_name, project_name, repo_id):
            return f"Source Branch for {source_branch_name} does not exist"
        else:
            pr_exists = self.check_pr_exists(
                source_branch_name, target_branch_name, project_name, repo_name
            )
            # pull_requests = self.get_all_pull_requests()
            # if not pull_requests:
            if not pr_exists:
                pull_request = _GitPullRequest()
                pull_request.title = pull_request_title
                pull_request.description = pull_request_description
                pull_request.source_ref_name = "refs/heads/" + source_branch_name
                pull_request.target_ref_name = "refs/heads/" + target_branch_name
                # in order to get the commits relating to a pull request we must first
                # instantiate the pull request to be able get the pull request id.
                this_pull_request = self._git_client.create_pull_request(
                    pull_request, repo_id
                )
                # Need all the comments from all the commits on that branch here
                pr_commits = self._git_client.get_pull_request_commits(
                    repo_id, this_pull_request.pull_request_id
                )
                update_pull_request = _GitPullRequest()
                update_pull_request.description = this_pull_request.description
                for commit in pr_commits.value:
                    update_pull_request.description = (
                        update_pull_request.description + "\n\n" + commit.comment
                    )
                self._git_client.update_pull_request(
                    update_pull_request, repo_id, this_pull_request.pull_request_id
                )
                return "Pull Request Created"
            else:
                return "Pull request already exists"

                # raise PullRequestExistsError()


class BranchExistsError(Exception):
    pass


class BranchNotFoundError(Exception):
    pass


class PullRequestExistsError(Exception):
    pass
