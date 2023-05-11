import re as _re
import textwrap
import time

from jira import JIRA as _JIRA
from jira import Issue as _Issue
from typing import Literal, Iterator

_instance_url: str = "https://trinoorsupport.atlassian.net"


class JIRA(_JIRA):
    def __init__(
        self, email: str, token: str, instance_url: str = _instance_url
    ) -> None:
        super().__init__({"server": instance_url}, basic_auth=(email, token))

    def get_custom_field_id(self, field_name: str) -> str:
        """
        Return the custom field id for the given field name.

        Args:
            field_name (str): The custom field name.

        Raises:
            ValueError: The custom field does not exist.

        Returns:
            str: The custom field id.
        """
        for field in self.fields():
            if field["name"] == field_name:
                return field["id"]
        raise ValueError(f"Could not find custom field with name '{field_name}'")

    def get_custom_field_name(self, field_id: str | int) -> str:
        """
        Return the name of the field with the given id.

        Args:
            field_id (str | int): The field id as either `"customfield_123"` or `123`.

        Returns:
            str: The field name.

        Raises:
            ValueError: The field id does not exist.
        """
        if isinstance(field_id, int):
            field_id = f"customfield_{field_id}"
        for field in self.fields():
            if field["id"] == field_id:
                return field["name"]
        raise ValueError(f"Could not find custom field with id '{field_id}'")

    def get_custom_field(
        self, issue: _Issue, field_name: str, default: object = None
    ) -> object:
        """
        Return the value of the custom field with the given name.

        Args:
            issue (Issue): The jira issue object to get the custom field value from.
            field_name (str): The issue's custom field name.

        Returns:
            str: The custom field value.
        """
        field_id: str = self.get_custom_field_id(field_name)
        value: object = issue.raw["fields"][field_id]
        return value or default

    def get_field(self, issue: _Issue, field_name: str, default: object = None) -> str:
        """
        Return the value of the built-in or custom field with the given name.

        Args:
            issue (Issue): The jira issue object to get the field value from.
            field_name (str): The issue's field name.

        Returns:
            str: The field value.
        """
        value: object
        try:
            # try to get the field name as a built-in field
            value = issue.raw["fields"][field_name]
        except KeyError:
            try:
                # try to get the field name as a custom field
                value = self.get_custom_field(issue, field_name)
            except ValueError:
                # return the default value if provided
                if default is not None:
                    value = default
                else:
                    # field does not exist and no default return value was provided
                    raise ValueError(f"Could not find field with name '{field_name}'")
        return value

    def search_all_issues(
        self,
        jql_str: str,
        raw: bool = False,
        **kwargs: object,
    ) -> Iterator[dict[str, object]]:
        """
        Return all issues matching a JQL query. Unlike `jira.search_issues`, this will
        return all issues matching the query, not just the first 50, and it is limited
        to only returning a list of jira.Issue objects rather than a `jira.ResultList`.
        Warning: for large queries, this can take a long time to run and use a lot of
        memory with no progress indicator.

        Args:
            jql_str (str): The JQL query string.
            raw (bool): If True, return each issue as a dict rather than a jira.Issue
            **kwargs (object): Extra parameters to pass to `jira.search_issues`.

        Returns:
            Iterator[dict[str, object]]: An iterator of issues.
        """
        start_at = 0
        while True:
            results = self.search_issues(
                jql_str,
                startAt=start_at,
                maxResults=50,
                **kwargs,
            )
            if len(results) == 0:
                break
            for result in results:
                if raw:
                    yield result.raw
                else:
                    yield result
            start_at += 50

    def generate_release_notes(
        self,
        issues: list[_Issue],
        version: str = "",
        title: str = "",
        date_format: str = "%B %d, %Y",
        format: Literal["html", "markdown"] = "markdown",
    ) -> str:
        """
        Generate release notes from a list of issues.

        Args:
            issues (list[Issue]): The issues to generate release notes for.
            format (Literal["html", "markdown"], optional): The format to generate the
                release notes in. Defaults to "markdown".

        Returns:
            str: The release notes.
        """
        release_notes: str

        # Add the title
        if not title and version:
            title = f"Release Notes for {version}"
        else:
            title = "Release Notes"
        release_notes = f"{title}\n---\n"

        # Add the date
        release_notes += f"*{time.strftime(date_format)}* | "

        # Sort the issues by issue type
        issues_by_type: dict[str, list[_Issue]] = {}
        for issue in issues:
            issue_type: str = issue.fields.issuetype.name
            if issue_type not in issues_by_type:
                issues_by_type[issue_type] = []
            issues_by_type[issue_type].append(issue)

        counts: list[str] = []
        nicknames: dict[str, str] = {"Story": "Features", "Bug": "Bug Fixes"}
        for nickname in nicknames:
            if nickname in issues_by_type:
                counts.append(
                    f"**{len(issues_by_type[nickname])} {nicknames[nickname].lower()}**"
                )
        release_notes += " & ".join(counts) + "\n\n"

        # Start with Stories
        is_first: bool = True
        for issue_type in issues_by_type:
            if is_first:
                is_first = False
            else:
                release_notes += "\n"
            release_notes += f"## {nicknames.get(issue_type, issue_type)}\n\n"
            # Remove the stories from the issues_by_type dict
            sub_issues: list[_Issue] = issues_by_type[issue_type]
            for issue in sub_issues:
                # Standardize the summaries:
                # - Remove leading/trailing whitespace
                # - Remove trailing periods
                # - Capitalize the first letter
                summary: str = issue.fields.summary.strip().rstrip(".").capitalize()
                # Wrap the line at 80 chars per markdown spec
                release_notes += (
                    textwrap.fill(
                        f"* **[{issue.key}]** {summary}\n",
                        width=78,
                        subsequent_indent="  ",
                    )
                    + "  \n"
                )
                if issue_type in ["Story", "Bug"]:
                    issue_notes: str
                    if issue_type == "Story":
                        issue_notes = self.get_field(issue, "Release Notes")
                    elif issue_type == "Bug":
                        issue_notes = self.get_field(issue, "Bug Notes")
                    if issue_notes:
                        # Wrap the line at 80 chars per markdown spec, adding an extra
                        # 2 spaces to each indent to account the italic asterisks that
                        # will be added to each line
                        issue_notes_lines: list[str] = textwrap.fill(
                            issue_notes,
                            width=80,
                            initial_indent="    ",
                            subsequent_indent="    ",
                        ).split("\n")
                        # Italicize each line of the release notes
                        issue_notes_lines = [
                            f"  *{line[4:]}*" for line in issue_notes_lines
                        ]
                        release_notes += "\n".join(issue_notes_lines) + "\n"
        return release_notes

    # TODO: Make sure that this converts to jira markdown
    def convert_markdown_to_jira(self, markdown: str) -> str:
        """
        Convert markdown to jira markup.

        Args:
            markdown (str): The markdown to convert.

        Returns:
            str: The converted jira markup.
        """
        # Convert markdown to html
        regex = r"""\[(?P<label>[^\]]*)\]\((?P<url>[^)]*)\)"""
        out = _re.findall(regex, markdown)
        found_all = False
        while not found_all:
            match = _re.search(regex, markdown)

            if match is None:
                found_all = True

            else:
                pre_string = markdown[0 : match.start()]
                mid_string = "[" + out[0][0] + "|" + out[0][1] + "]"
                post_string = markdown[match.end() :]
                out.pop(0)
                markdown = pre_string + mid_string + post_string

        return markdown


class UserPermissionError(Exception):
    """
    Exception for when a user is missing permissions
    """


class InvalidProjectError(Exception):
    """
    Exception for when a project is invalid or doesn't exist
    """


class InvalidIssueError(Exception):
    """
    Exception for when a issue is invalid or doesn't exist
    """


class CustomFieldNotFoundError(Exception):
    """
    Exception for when a custom field is not found
    """
