#!/usr/bin/env python3
#
# Given a set of Jira issues and 2 fields, swap the values of one or both fields. If
# only one field is copied to the other, optionally clear the source field.

import argparse
import json
import keyring
import os
import re
import textwrap

from getpass import getpass
from pprint import pformat
from trinoor.jira import JIRA
from typing import Iterable
from jira import resources

email: str = os.environ.get("JIRA_EMAIL", "")
keyinfo: tuple = ("system", "jira")


def login() -> JIRA:
    jira: JIRA = None
    password: str
    attempts: int = 3
    logged_in: bool = False
    store_password: bool = False

    # Get the password
    password = os.environ.get("JIRA_PAT", keyring.get_password(*keyinfo))
    if not password:
        # Check to see if an environment variable is set
        password = os.environ.get("JIRA_PAT")
        if not password:
            # Prompt for the password
            password = getpass("Password: ")
            store_password = True

    while attempts and not logged_in:
        try:
            jira = JIRA(email, password)
        except Exception as e:
            print(f"Failed to login: {e}")
            password = getpass(f"Please enter the password for '{email}': ")
            store_password = True
        else:
            logged_in = True
            if store_password:
                keyring.set_password(*keyinfo, password)

    if not jira:
        raise Exception(f"Failed to authenticate '{email}'")

    return jira


if __name__ == "__main__":
    import dateutil.parser
    import re

    parser = argparse.ArgumentParser(description="jira field swap utility")
    parser.add_argument("issues", nargs="*", help="issues to modify")
    parser.add_argument(
        "-s",
        "--source-field",
        action="store",
        help="The source field to copy from",
    )
    parser.add_argument(
        "-t",
        "--target-field",
        action="store",
        help="The target field to copy to",
    )
    parser.add_argument(
        "-j",
        "--jql",
        default="",
        help="The JQL query to use to find issues",
    )
    parser.add_argument(
        "-c",
        "--clear-source",
        action="store_true",
        dest="clear_source",
        help="Clear the source field after copying",
    )
    parser.add_argument(
        "-C",
        "--no-clear-source",
        action="store_false",
        dest="clear_source",
        help="Do not clear the source field after copying",
    )
    parser.epilog = textwrap.dedent(
        """
        This script will swap the values of the source and target fields for jira
        issues. Issues can be specified by key as arguments, searched for using a JQL
        query, or both.

        If the `--clear-source` option is specified, rather than setting the source
        field's value to the target field's value, it will be set to None. This is
        useful if we want to switch from using the source field to the target field
        and no longer need the source field.
        """
    )

    args = parser.parse_args()

    # Check that the source and target fields are specified
    if not args.source_field or not args.target_field:
        parser.print_help()
        exit(1)

    # Check that a JQL query or issues are specified
    if not args.issues and not args.jql:
        parser.print_help()
        exit(1)

    # Login to Jira
    print("* logging in ... ", end="", flush=True)
    try:
        jira = login()
    except Exception as e:
        print(f"failed: {e}")
        exit(1)
    print("done")

    # Combine the issues from the command line with the issues from the JQL query
    jql_query = ""
    if args.issues:
        jql_query = f"issue in ({','.join(args.issues)})"
    if args.issues and args.jql:
        jql_query += " OR "
    if args.jql:
        jql_query += args.jql

    print("* searching for issues ... ", end="", flush=True)
    issues = list(jira.search_all_issues(jql_query))
    print(f"found {len(issues)} issues")

    # Loop over each issue, swapping the fields
    for issue in issues:
        print(f"* processing issue {issue.key} ... ", flush=True, end="")

        # Get the source field value
        source_value = jira.get_field(issue, args.source_field)
        try:
            source_value = int(source_value)
        except:
            pass
        target_value = jira.get_field(issue, args.target_field)
        try:
            target_value = int(target_value)
        except:
            pass

        print("")
        print(f"  {source_value=} -> {target_value=}")

        # # Set the target field to the source field value
        # jira.set_field(issue, args.target_field, source_value)

        # # If clearing the source field, set it to None, else set it to the target value
        # if args.clear_source:
        #     jira.set_field(issue, args.source_field, None)
        # else:
        #     jira.set_field(issue, args.source_field, target_value)

        # print("done")
