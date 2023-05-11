from jira import JIRA
from trinoor.config import Config


ado_config = Config("ado.json")
jira_config = Config("jira.json")


def create_jira_obj() -> JIRA:
    jira_options = {"server": "https://trinoorsupport.atlassian.net"}
    jira = JIRA(
        options=jira_options,
        basic_auth=(jira_config.get("authEmail"), jira_config.get("authToken")),
    )
    return jira


def check_testops_for_prexisting_issue(issue_key: str) -> bool:
    issue_exits = False
    jira = create_jira_obj()
    issue = jira.issue(issue_key)
    if len(issue.fields.issuelinks) > 0:
        for link in issue.fields.issuelinks:
            if link.type.name == "Parent/Child":
                if link.outwardIssue.fields.project.key == "TST":
                    issue_exits = True
    return issue_exits


def check_jira_auth(user_id: str, user_key: str) -> bool:
    jira_auth = False
    if user_id == user_key:
        jira_auth = True
    return jira_auth


def update_components_from_originating_parent_story(
    issue_key: str,
) -> any:
    jira = create_jira_obj()
    issue = jira.issue(issue_key)
    if len(issue.fields.issuelinks) > 0:
        parent_link = issue.fields.issuelinks[0]
        parent = jira.issue(str(parent_link.outwardIssue.key))
        existing_components = []
        for component in parent.fields.components:
            existing_components.append({"name": component.name})
        if len(existing_components) > 0:
            issue.update(fields={"components": existing_components})


def get_state_value_from_parent(issue_key: str) -> any:
    jira: JIRA = create_jira_obj()
    issue = jira.issue(issue_key)
    if len(issue.fields.issuelinks) > 0:
        parent_link = issue.fields.issuelinks[0]
        parent = jira.issue(str(parent_link.outwardIssue.key))
        issue.update(fields={"customfield_10212": parent.fields.customfield_10212})


def create_issue_in_testops_project(issue_key: str, user_id: str, user_key: str) -> any:
    if check_testops_for_prexisting_issue(issue_key) is False:
        if check_jira_auth(user_id, user_key) is False:
            return "Some kind of problem"
        jira = create_jira_obj()
        issue = jira.issue(issue_key)
        # new_issue = jira.create_issue(Project={'key':'TST'}, fields=issue.fields)
        reporter2 = {"accountId": issue.fields.reporter.accountId}
        fields_dict = {
            "project": {"key": "TST"},
            "summary": "Testing for " + issue.fields.summary,
            "description": issue.fields.description,
            "issuetype": {"name": "Task"},
            "reporter": reporter2,
            "duedate": issue.fields.duedate,
            "priority": {"name": issue.fields.priority.name},
            "customfield_10212": "Not ready for testing",
        }
        #

        new_issue = jira.create_issue(fields=fields_dict)
        for comment in issue.fields.comment.comments:
            jira.add_comment(new_issue, comment.body)
        jira.create_issue_link("Parent/Child", new_issue, issue)
        for label in issue.fields.labels:
            jira.add_label(new_issue, label)
        for attachment in issue.fields.attachment:
            jira.add_attachment(new_issue, attachment.get(), attachment.filename)
        # print("looking at fixVersions")
        # for fix_version in issue.fields.fixVersions:
        #     jira.add_version(new_issue, fix_version.name)

        existing_components = []
        for component in issue.fields.components:
            existing_components.append({"name": component.name})
        if len(existing_components) > 0:
            issue.update(fields={"components": existing_components})

        update_components_from_originating_parent_story(new_issue.key)
        return "TestOps issue created"
    else:
        return "TestOps issue already exists"


def set_ready_for_testing(issue_key: str, user_id: str, user_key: str) -> any:
    if check_jira_auth(user_id, user_key) is False:
        return "Some kind of problem"
    jira = create_jira_obj()
    issue = jira.issue(issue_key)
    # get child link
    if len(issue.fields.issuelinks) > 0:
        for link in issue.fields.issuelinks:
            if link.type.name == "Parent/Child":
                if link.inwardIssue.key.startswith("TST"):
                    child = jira.issue(str(link.inwardIssue.key))
                    child.update(fields={"customfield_10212": "Ready for testing"})
                    jira.transition_issue(child, "11")
                    # 11 is the id of the "Ready for Testing" transition
                    return "TestOps issue updated"
    return "No TestOps issue found"


# transition the issues parent to the next available transition
def test_complete(issue_key: str, user_id: str, user_key: str) -> any:
    # check to see if the issue has a parent
    jira = create_jira_obj()
    issue = jira.issue(issue_key)
    if len(issue.fields.issuelinks) > 0:
        # look for the parent link
        for link in issue.fields.issuelinks:
            if link.type.name == "Parent/Child":
                parent = jira.issue(str(link.outwardIssue.key))
                # check to see if the issue has documentation required
                if parent.fields.customfield_10226.value == "Yes":
                    # if so, transition the parent to the "Documentation Required"
                    # transition
                    jira.transition_issue(parent, "141")
                    # 12 is the id of the "Documentation Required" transition
                    return "Parent issue updated"
                elif parent.fields.customfield_10226.value == "No":
                    # if not, transition the parent to the "Ready for Release"
                    # transition
                    jira.transition_issue(parent, "121")
                    # 13 is the id of the "Ready for Release" transition
                    return "Parent issue updated"
    return "No parent issue found"
