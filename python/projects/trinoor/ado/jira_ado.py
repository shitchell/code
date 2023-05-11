import json
import re
from azure.devops.v5_1.git import (
    GitRefUpdate,
    GitPullRequest,
)
from trinoor.jira import JIRA
from trinoor.config import Config
from typing import Callable
from functools import wraps

# from starlette.requests import Request


ado_config = Config("ado.json")
# 2 lines below exist only to satisfy linter
a = GitRefUpdate()
b = GitPullRequest()

config = Config("jira.json")
jira: JIRA = JIRA(config.get("authEmail"), config.get("authToken"))


def jira_login(func: Callable) -> Callable:
    """
    Re-login to Jira

    Args:
        func (Callable): Wrapped function

    Raises:
        JiraError: Raised when authentication fails

    Returns:
        Callable: Returns jira_login_wrapper
    """

    @wraps(func)
    async def jira_login_wrapper(*args, **kwargs) -> Callable:
        global jira

        jira = JIRA(config.get("authEmail"), config.get("authToken"))

        return await func(*args, **kwargs)

    return jira_login_wrapper


@jira_login
async def get_project_name_from_id(project_id: str) -> str:
    project_name = jira.project(project_id).name
    return project_name


async def get_all_branch_name_seperators_from_config_file() -> list:
    branch_enabled_projects = ado_config.get("api.branch_enabled_projects")
    seperators = []
    for project in branch_enabled_projects:
        project_key = str(project).split(".")[1]
        project_org = str(project).split(".")[0]
        seperators.append(
            ado_config.get(
                "api." + project_org + "." + project_key + ".branch_name_seperator"
            )
        )
    return seperators


async def get_org_from_project_key(project_key: str) -> str:
    for project in ado_config.get("api.branch_enabled_projects"):
        if project_key == str(project).split(".")[1]:
            return str(project).split(".")[0]


@jira_login
async def check_jira_issue_exists(issue_key: str) -> bool:
    jql_issues = jira.search_issues("key=" + issue_key)
    if len(jql_issues) == 0:
        return False
    else:
        return True


def convert_markdown_to_jira(markdown: str) -> str:
    regex = r"""\[(?P<label>[^\]]*)\]\((?P<url>[^)]*)\)"""
    out = re.findall(regex, markdown)
    found_all = False
    while not found_all:
        match = re.search(regex, markdown)

        if match is None:
            found_all = True

        else:
            pre_string = markdown[0 : match.start()]
            mid_string = "[" + out[0][0] + "|" + out[0][1] + "]"
            post_string = markdown[match.end() :]
            out.pop(0)
            markdown = pre_string + mid_string + post_string

    return markdown


@jira_login
async def git_push_event(data: json) -> any:
    # jira = create_jira_obj()
    split_str = data["message"]["text"].split("#version=GB")
    branch_name = split_str[len(split_str) - 1][
        0 : len(split_str[len(split_str) - 1]) - 1
    ]
    if branch_name.startswith("releases"):
        split_branch_name = branch_name.split("%2F")
        branch_name = split_branch_name[2]
    nonfocus_branches = ["dev", "development", "main", "master"]
    if branch_name not in nonfocus_branches:
        branch_name_seperator = ""  # leave this as a default for old stuff
        seperators = await get_all_branch_name_seperators_from_config_file()
        for seperator in seperators:
            if str(seperator) in branch_name:
                branch_name_seperator = str(seperator)
        if branch_name_seperator == "":
            return "No branch name seperator found"
        issue_key = branch_name.split(branch_name_seperator)[0]
        if len(issue_key) != len(branch_name):
            if await check_jira_issue_exists(issue_key) is True:
                if "pushed" in data["message"]["text"]:
                    # check jira to see if any issue keys match branch name
                    issue = jira.issue(issue_key)
                    markdown = data["detailedMessage"]["markdown"]
                    split_str = markdown.split("\r\n")
                    return_str = convert_markdown_to_jira(markdown)
                    if (
                        data["resource"]["refUpdates"][0]["oldObjectId"]
                        == "0000000000000000000000000000000000000000"
                    ):
                        # logging.debug("DETECTED new branch")
                        return_str = markdown.replace("pushed a commit to", "created")

                        return_str = convert_markdown_to_jira(return_str)[
                            0 : return_str.index("\r\n")
                        ]

                    jira.add_comment(issue_key, return_str)
                    # check to see if issue is in selected for development state in jira
                    if issue.fields.status.name == "To Do":
                        jira.transition_issue(
                            issue_key, 51
                        )  # 51 is the select for development transition

                    return "New Branch Detected"

                elif "deleted" in data["message"]["text"]:
                    # check jira to see if any issue keys match branch name
                    issue = jira.issue(issue_key)
                    jira.add_comment(
                        issue,
                        convert_markdown_to_jira(data["detailedMessage"]["markdown"]),
                    )
                    return "Branch Deleted"
                else:
                    return "No actions detected"
            else:
                return "No Jira Issue Detected"
        else:
            return "No JIRA Issue Found"
    else:
        return "Non focus branch detected"


@jira_login
async def git_pullrequest_updated_event(data: json) -> any:
    # jira = create_jira_obj()
    if "releases" in data["resource"]["sourceRefName"]:
        source_branch_name = data["resource"]["sourceRefName"].split("/")[4]
    else:
        source_branch_name = data["resource"]["sourceRefName"].split("refs/heads/")[1]
    seperators = await get_all_branch_name_seperators_from_config_file()
    branch_name_seperator = ""
    for seperator in seperators:
        if str(seperator) in source_branch_name:
            branch_name_seperator = seperator
    if branch_name_seperator == "":
        return "No branch name seperator found"
    issue_key = source_branch_name.split(str(branch_name_seperator))[0]
    if len(issue_key) != len(source_branch_name):
        if await check_jira_issue_exists(issue_key):
            if data["message"]["text"].find("completed pull request") != -1:
                issue = jira.issue(issue_key)
                if issue.fields.project.key == "TST":
                    jira.transition_issue(issue_key, 51)  # testops approved state
                elif (
                    issue.fields.project.key == "API"
                    and issue.fields.status.name != "Pre-release"
                ):
                    jira.transition_issue(issue_key, 71)
                else:
                    # check to see if testing is required  - 10225
                    if str(issue.fields.customfield_10225) == "Yes":
                        jira.transition_issue(
                            issue_key, 91
                        )  # 91 is the select for testing transition
                    # check to see if documentation is required  - 10226
                    elif str(issue.fields.customfield_10226) == "Yes":
                        jira.transition_issue(issue_key, 101)
                        # 101 is the select for documentation transition
                    else:
                        jira.transition_issue(
                            issue_key, 71
                        )  # 71 is the pre release transition
            jira.add_comment(
                issue_key, convert_markdown_to_jira(data["detailedMessage"]["markdown"])
            )
            return f"Comment added to {issue_key}"
        else:
            return "No Jira Issue Detected"
    else:
        return "No JIRA Issue Found"


@jira_login
async def git_pullrequest_comment_event(data: json) -> any:
    # jira = create_jira_obj()
    # logging.debug("Pull Request Comment")
    if "releases" in data["resource"]["pullRequest"]["sourceRefName"]:
        source_branch_name = data["resource"]["pullRequest"]["sourceRefName"].split(
            "/"
        )[4]
    else:
        source_branch_name = data["resource"]["pullRequest"]["sourceRefName"].split(
            "refs/heads/"
        )[1]
    seperators = await get_all_branch_name_seperators_from_config_file()
    branch_name_seperator = ""
    for seperator in seperators:
        if str(seperator) in source_branch_name:
            branch_name_seperator = seperator
    if branch_name_seperator == "":
        return "No branch name seperator found"
    issue_key = source_branch_name.split(str(branch_name_seperator))[0]
    if len(issue_key) != len(source_branch_name):
        if await check_jira_issue_exists(issue_key):
            jira.add_comment(
                issue_key, convert_markdown_to_jira(data["detailedMessage"]["markdown"])
            )
            return f"Comment added to {issue_key}"
        else:
            return "No Jira Issue Detected"
    else:
        return "No JIRA Issue Found"


@jira_login
async def git_pullrequest_created_event(data: json) -> any:
    # jira = create_jira_obj()
    if "created pull request" in data["message"]["text"]:
        if "releases" in data["resource"]["sourceRefName"]:
            source_branch_name = data["resource"]["sourceRefName"].split("/")[4]
        else:
            source_branch_name = data["resource"]["sourceRefName"].split("refs/heads/")[
                1
            ]
        seperators = await get_all_branch_name_seperators_from_config_file()
        branch_name_seperator = ""
        for seperator in seperators:
            if str(seperator) in source_branch_name:
                branch_name_seperator = seperator
        if branch_name_seperator == "":
            return "No branch name seperator found"
        issue_key = source_branch_name.split(str(branch_name_seperator))[0]
        if len(issue_key) != len(source_branch_name):
            if await check_jira_issue_exists(issue_key):
                issue = jira.issue(issue_key)
                jira.add_comment(
                    issue, convert_markdown_to_jira(data["detailedMessage"]["markdown"])
                )
                #  check to see if issue is in the the
                #  selected for development state in jira
                if issue.fields.status.name == "In Development":
                    jira.transition_issue(issue_key, 61)  # 61 is the review transition
                return f"Comment added to {issue_key}"
            else:
                return "No Jira Issue Detected"
        else:
            return "No JIRA Issue Found"
    return "Pull Request Created"


@jira_login
async def git_pullrequest_merged_event(data: json) -> any:
    # jira = create_jira_obj()
    if "releases" in data["resource"]["sourceRefName"]:
        source_branch_name = data["resource"]["sourceRefName"].split("/")[4]
    else:
        source_branch_name = data["resource"]["sourceRefName"].split("refs/heads/")[1]
    seperators = await get_all_branch_name_seperators_from_config_file()
    branch_name_seperator = ""
    for seperator in seperators:
        if str(seperator) in source_branch_name:
            branch_name_seperator = seperator
    if branch_name_seperator == "":
        return "No branch name seperator found"
    issue_key = source_branch_name.split(str(branch_name_seperator))[0]
    if len(issue_key) != len(source_branch_name):
        if await check_jira_issue_exists(issue_key):
            issue = jira.issue(issue_key)
            # check to see if the merge is active
            if data["resource"]["status"] == "active":
                comment_str = (
                    "Merge conflict check between the "
                    + data["resource"]["sourceRefName"].split("refs/heads/")[1]
                    + " Branch and the "
                    + data["resource"]["targetRefName"].split("refs/heads/")[1]
                    + " Branch has "
                    + data["resource"]["mergeStatus"]
                )

            elif data["resource"]["status"] == "abandoned":
                comment_str = "Merge Abandoned."

            elif data["resource"]["status"] == "completed":
                comment_str = (
                    "Merge "
                    + data["resource"]["mergeStatus"]
                    + " between the "
                    + data["resource"]["sourceRefName"].split("refs/heads/")[1]
                    + " Branch and the "
                    + data["resource"]["targetRefName"].split("refs/heads/")[1]
                    + " Branch."
                )

            jira.add_comment(issue, comment_str)
            return "Pull Request Merged event"
        else:
            return "No Jira Issue Detected"
    else:
        return "No JIRA Issue Found"


def recieve_webhook(data: json) -> any:
    if data["eventType"] == "git.push":
        return_obj = git_push_event(data)
    elif data["eventType"] == "git.pullrequest.updated":
        return_obj = git_pullrequest_updated_event(data)
    elif data["eventType"] == "ms.vss-code.git-pullrequest-comment-event":
        return_obj = git_pullrequest_comment_event(data)
    elif data["eventType"] == "git.pullrequest.created":
        return_obj = git_pullrequest_created_event(data)
    elif data["eventType"] == "git.pullrequest.merged":
        return_obj = git_pullrequest_merged_event(data)
    return return_obj


@jira_login
async def get_project_name_from_issue_key(issue_key: str) -> str:
    project_key = jira.issue(issue_key).fields.project.key
    project_name = ado_config.get("api.trinoor." + project_key + ".project_name")
    return project_name


@jira_login
async def get_repo_name_from_issue_key(issue_key: str) -> str:
    project_key = jira.issue(issue_key).fields.project.key
    component = await get_compononent_name_from_issue_key(issue_key)
    repo_name = ado_config.get(
        "api.trinoor." + project_key + "." + component + ".repo_name"
    )
    return repo_name


@jira_login
async def get_compononent_name_from_issue_key(issue_key: str) -> str:
    components = jira.issue(issue_key).fields.components
    if len(components) == 1:
        component = components[0].name
    elif len(components) == 0:
        return "No Component Selected"
    elif len(components) > 1:
        return "Too Many Components Selected"
    return component


async def get_personal_access_token() -> str:
    return ado_config.get("api.trinoor.personalAccessToken")


async def get_organization_url() -> str:
    return ado_config.get("api.trinoor.org_url")


@jira_login
async def get_source_branch_name_from_issue_key(issue_key: str) -> str:
    project_key = jira.issue(issue_key).fields.project.key
    component = await get_compononent_name_from_issue_key(issue_key)
    source_branch_name = ado_config.get(
        "api.trinoor." + project_key + "." + component + ".dev_branch"
    )
    return source_branch_name


@jira_login
async def get_pr_source_branch_from_issue_key(issue_key: str) -> str:
    project_key = jira.issue(issue_key).fields.project.key
    issue_title = jira.issue(issue_key).fields.summary.replace(" ", "_")
    org_name = await get_org_from_project_key(project_key)
    branch_name_seperator = ado_config.get(
        "api." + org_name + "." + project_key + ".branch_name_seperator"
    )
    source_branch_name = issue_key + branch_name_seperator + issue_title
    return source_branch_name


@jira_login
async def get_branch_name_from_issue_key(issue_key: str) -> str:
    issue_title = jira.issue(issue_key).fields.summary
    project_key = jira.issue(issue_key).fields.project.key
    org_name = await get_org_from_project_key(project_key)
    branch_name_seperator = ado_config.get(
        f"api.{org_name}.{project_key}.branch_name_seperator"
    )
    branch_name = (
        issue_key + str(branch_name_seperator) + (issue_title.replace(" ", "_"))
    )
    return branch_name


@jira_login
async def get_target_branch_name_from_issue_key(issue_key: str) -> str:
    project_key = jira.issue(issue_key).fields.project.key
    component = await get_compononent_name_from_issue_key(issue_key)
    target_branch_name = ado_config.get(
        "api.trinoor." + project_key + "." + component + ".dev_branch"
    )
    return target_branch_name


async def get_pull_request_title_from_issue_key(issue_key: str) -> str:
    pull_request_title = "Merge: " + issue_key
    return pull_request_title


async def get_pull_request_description_from_issue_key(issue_key: str) -> str:
    target_branch_name = await get_target_branch_name_from_issue_key(issue_key)
    pull_request_description = (
        "Pull request to merge " + issue_key + " into " + target_branch_name
    )
    return pull_request_description


async def get_repo_name_from_project_key_and_component(
    project_key: str, component: str
) -> str:
    repo_name = ado_config.get(
        "api.trinoor." + project_key + "." + component + "." + "repo_name"
    )
    return repo_name


@jira_login
async def get_project_key_from_id(project_id: str) -> str:
    project_key = jira.project(project_id).key
    return project_key


@jira_login
async def get_issue_type_from_issue_key(issue_key: str) -> str:
    issue_type = jira.issue(issue_key).fields.issuetype.name
    return issue_type


@jira_login
async def get_fix_version_from_issue_key(issue_key: str) -> str:
    fix_version = ""
    fix_versions = jira.issue(issue_key).fields.fixVersions
    if len(fix_versions) == 1:
        fix_version = fix_versions[0].name
    return fix_version


@jira_login
async def get_all_versions(project_key: str) -> list:
    versions = jira.project_versions(project_key)
    return versions


@jira_login
async def get_project_key_from_jira_issue_key(issue_key: str) -> str:
    project_key = jira.issue(issue_key).fields.project.key
    return project_key
