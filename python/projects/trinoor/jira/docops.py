from typing import Literal
from jira import Issue, Project
from jira.exceptions import JIRAError
from . import JIRA as _JIRA, InvalidProjectError, UserPermissionError


class JIRA(_JIRA):
    """
    Extended JIRA class
    """

    # def __init__(
    #     self, project_key: str, email: str, token: str, instance_url: str
    # ) -> None:
    #     self.project_key = project_key
    #     options = {"server": instance_url}
    #     super().__init__(options, basic_auth=(email, token))

    @property
    def project_key(self) -> str:
        """
        Returns the project name
        """
        return self._project_key

    @project_key.setter
    def project_key(self, project_key: str) -> None:
        """
        Sets the documentation project key for this class

        Args:
            project_key (str): The key of the project to use
        """
        try:
            self.project(project_key)
        except JIRAError:
            raise InvalidProjectError(project_key)
        self._project_key = project_key

    def transition_issue_to_status(self, issue_key: str, status: str) -> None:
        """
        Transitions issue to a status

        Args:
            issue_key (str): Issue key/id
            status (str): Status to transition issue to
        """
        issue: Issue = self.issue(issue_key)
        issue_transitions: list[dict] = self.transitions(issue)
        transition_ids: list[str] = [
            transition["id"]
            for transition in issue_transitions
            if transition["to"]["name"] == status
        ]
        if not transition_ids:
            return
            # TODO raise an error for a missing transition
        self.transition_issue(issue_key, transition_ids[0])

    def transition_subtasks_to_parent_status(self, issue_key: str) -> None:
        """
        Transitions the subtasks to the status of the parent

        Args:
            issue_key (str): Issue key/id
        """
        issue: Issue = self.issue(issue_key)
        for subtask in issue.fields.subtasks:
            self.transition_issue_to_status(
                self.issue(subtask.key), issue.fields.status.name
            )

    def get_issue_links(self, issue_key: str, link_type: str) -> list:
        """
        Returns a list of issue links

        Args:
            issue_key (str): Issue key/id
            link_type (str): Type of link to filter for

        Returns:
            list: All of the issue's links of link_type
        """
        issue: Issue = self.issue(issue_key)
        issue_links = [
            issuelink
            for issuelink in issue.fields.issuelinks
            if issuelink.type.name == link_type
        ]
        return issue_links

    def search_for_link_type(self, issue_key: str, link_type: str) -> bool:
        """
        Checks for a link of specified type

        Args:
            issue_key (str): Issue key/id
            link_type (str): Type of link to search for; Eg: "Cloners"

        Returns:
            bool: If the issue has a link of link_type
        """
        issue: Issue = self.issue(issue_key)
        return len(self.get_issue_links(issue.key, link_type)) > 0

    def get_linked_issue(
        self, issue_key: str, link_type: str, direction: Literal["inward", "outward"]
    ) -> None | Issue:
        """
        Returns a linked issue that is of the specified type and direction.
        Checks if issue link of specified type exists

        Args:
            issue_key (str): Issue key/id
            link_type (str): Type of link to search for; Eg: "Cloners"
            direction (str): "inward"/"outward"

        Returns:
            None | Issue: Linked issue
        """
        issue: Issue = self.issue(issue_key)
        if not (issue_links := self.get_issue_links(issue.key, link_type)):
            return None
        issue_link = issue_links[0]
        if direction == "inward":
            if hasattr(issue_link, "inwardIssue"):
                return self.issue(issue_link.inwardIssue.key)
        if direction == "outward":
            if hasattr(issue_link, "outwardIssue"):
                return self.issue(issue_link.outwardIssue.key)

    def is_subtask(self, issue_key: Issue | str) -> bool:
        """
        Checks if an issue is a subtask

        Args:
            issue_key (str): Issue or issue key/id

        Returns:
            bool: True if issue is a subtask
        """
        return self.issue(issue_key).fields.issuetype.hierarchyLevel == -1

    # The outward issue will be the issue that documents/clones/etc... the inward
    # issue which is documented by/cloned by/etc... by the outward issue
    # It is important to note that when searching through links,
    # it is impossible to differentiate documents/documented by because when you
    # .type.outward it will return the same thing regardless of the link of the issue
    # (bc ur using the link object not the issue object)
    # link_type = {"name" : "linktype"}
    def create_link(
        self, inward_issue: str, outward_issue: str, link_type: str
    ) -> None:
        """
        Creates a link between two issues

        Args:
            inward_issue (str): The issue to link from
            outward_issue (str): The issue to link to
            link_type (str): The type of link to create
        """
        self.create_issue_link(self, link_type, inward_issue, outward_issue)

    def clone(self, issue_key: str) -> None:
        """
        Clones description, priority, components and reporter to a new issue

        Args:
            issue_key (str): Issue key/id
        """
        issue: Issue = self.issue(issue_key)
        new_issue: Issue = self.create_issue(
            project=self.project_key,
            summary=f"[{issue.key}] {issue.fields.summary}",
            issuetype={"name": f"{issue.fields.issuetype}"},
        )
        self.create_issue_link("Cloners", new_issue.key, issue.key)

    # create new cloning copy thing
    # TODO +email
    def update_clone(self, issue_key: str) -> None:
        """
        Updates cloned issue assignee and reporter

        Args:
            issue_key (str): Issue key/id

        Raises:
            UserPermissionError: User cannot be assigned issues
        """
        issue: Issue = self.issue(issue_key)
        clone: Issue = self.get_linked_issue(issue.key, "Cloners", "outward")
        clone.update(summary=f"[{issue.key}] {issue.fields.summary}")
        try:
            clone.update(assignee={"assignee": issue.fields.assignee.accountId})
            clone.update(reporter={"reporter": issue.fields.assignee.accountId})
        # assign task to user
        except JIRAError as e:
            if "cannot be assigned issues" in e.args[0]:
                raise UserPermissionError(*e.args)

    def assign_to_project_lead(self, issue_key: str) -> None:
        """
        Assigns issue to project lead

        Args:
            issue_key (str): Issue key/id
        """
        issue: Issue = self.issue(issue_key)
        project: Project = self.project(issue.fields.project.key)
        try:
            self.assign_issue(issue, project.lead)
        # assign task to user
        except JIRAError as e:
            if "cannot be assigned issues" in e.args[0]:
                raise UserPermissionError(*e.args)
