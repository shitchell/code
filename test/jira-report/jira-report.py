#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Download all JIRA issues for a given filter, save them to a file, and then email the
file to a list of recipients.
"""
# TODO:
# - [ ] add support for multiple filters
# - [ ] convert all top-level imports to have a _prefix

import dateutil
import re
import shlex
import sys
import time

from enum import Enum
from pprint import pformat
from pathlib import Path
from jira import resources
from trinoor.jira import JIRA
from typing import Iterable


class OutputFormat(Enum):
    CSV = "csv"
    JSON = "json"
    EXCEL = "xlsx"
    XLSX = "xlsx"


def load_env(env_path: Path | str) -> dict[str, str | int | float | bool]:
    """
    Load environment variables from a file and return them as a dict. Will parse a
    bash style environment file:
        FOO_BAR="some value"
        FOO_BAR2=123
    or a python style environment file:
        FOO_BAR = "some value"
        FOO_BAR2 = 123
    """
    env_path: Path = Path(env_path)
    print(f"Loading environment from {env_path}")
    env_values: dict[str, str | int | float | bool] = {}
    if env_path.exists():
        with open(env_path) as env_file:
            for line in env_file:
                line = line.strip()
                if line and not line.startswith("#"):
                    key, value = line.split("=", 1)
                    # Clean up the key/value
                    key = key.strip()
                    value = value.strip(" '\"")
                    os.environ[key] = value
                    env_values[key] = parse_value(value)
                    print(f" - {key}={env_values[key]}")
    else:
        raise FileNotFoundError(f"Environment file not found: {env_path}")
    print("loaded:", env_values)
    return env_values


def parse_value(value: str) -> str | int | float | bool:
    """
    Parse a string value into a string, int, float, or bool.
    """
    try:
        value = float(value)
        if value.is_integer():
            value = int(value)
    except ValueError:
        if value.lower() == "true":
            value = True
        elif value.lower() in ("false", ""):
            value = False
    return value


def normalize_issue_value(value: object):
    """
    Normalize a JIRA issue field's value to a string.
    """
    valuestr = str(value)
    if isinstance(value, Iterable) and "self" in value:
        if "/resolution/" in value["self"]:
            return value["name"]
        elif "accountId" in value:
            display_name = value.get("displayName", "")
            email_address = value.get("emailAddress", "")
            if display_name and email_address:
                value = f"{display_name} <{email_address}>"
            elif display_name:
                value = display_name
            elif email_address:
                value = email_address
        elif "name" in value:
            value = value["name"]
        elif "value" in value:
            value = value["value"]
    elif isinstance(value, list):
        valuelist = []
        for subvalue in value:
            valuelist.append(normalize_issue_value(subvalue))
        value = pformat(valuelist)
    elif isinstance(value, dict):
        valuedict = {}
        for k, v in value.items():
            valuedict[k] = normalize_issue_value(v)
        value = pformat(valuedict)
    elif isinstance(value, resources.Watchers):
        value = value.watchCount
    elif isinstance(value, resources.TimeTracking):
        value = value.raw
    elif isinstance(value, resources.Comment):
        value = f"{value.author} ({value.created}): {value.body}"
    elif isinstance(value, resources.PropertyHolder):
        value = normalize_issue_value(value.__dict__)
    elif isinstance(value, resources.UnknownResource):
        if hasattr(value, "comments"):
            value = normalize_issue_value(value.comments)
    elif isinstance(value, resources.Resource):
        value = valuestr
    elif not isinstance(value, (int, float, str, bool)):
        value = valuestr
    elif isinstance(value, str):
        value = value.replace(r"\\ ", "\n")
        if value in ("NA", "N/A", "NULL"):
            value = None
    return value


if __name__ == "__main__":
    import os
    from pathlib import Path
    from textwrap import dedent
    import pandas as pd
    from trinoor.email import SMTPClient

    from argparse import (
        ArgumentParser,
        _ArgumentGroup,
        Namespace,
        RawDescriptionHelpFormatter,
    )

    parser = ArgumentParser(
        description="Download Jira issues and email them to a list of recipients",
    )
    parser.add_argument(
        "-o", "--output", type=Path, help="The output file to save the issues to"
    )
    parser.add_argument(
        "--output-type",
        default="csv",
        type=OutputFormat,
        help="The output type to save the issues as",
    )
    parser.add_argument("-f", "--filter", type=int, help="The Jira filter to use")
    parser.add_argument(
        "-F",
        "--fields",
        action="append",
        default=["key", "summary", "status"],
        help="The fields to include in the report",
    )
    parser.add_argument(
        "-e",
        "--env",
        type=load_env,
        default=None,
        help="The .env file to load environment variables from",
    )
    parser.add_argument(
        "-J",
        "--jira-email",
        default=os.environ.get("JIRA_EMAIL"),
        help="The email address to authenticate JIRA with",
    )
    parser.add_argument(
        "-T",
        "--jira-token",
        default=os.environ.get("JIRA_TOKEN"),
        help="The token to authenticate JIRA with",
    )
    parser.add_argument(
        "-E",
        "--smtp-email",
        default=os.environ.get("SMTP_EMAIL"),
        help="The email address to authenticate SMTP with",
    )
    parser.add_argument(
        "-P",
        "--smtp-password",
        default=os.environ.get("SMTP_PASSWORD"),
        help="The password to authenticate SMTP with",
    )
    parser.add_argument(
        "-s",
        "--smtp-server",
        default=os.environ.get("SMTP_HOST", "smtp.office365.com"),
        help="The SMTP server to use",
    )
    parser.add_argument(
        "-p",
        "--smtp-port",
        default=os.environ.get("SMTP_PORT", 587),
        help="The SMTP port to use",
    )
    parser.add_argument(
        "-S",
        "--smtp-tls",
        default=os.environ.get("SMTP_TLS", True),
        type=bool,
        help="Whether to use SSL to connect to the SMTP server",
    )
    parser.add_argument("-t", "--to", help="An email address to send the report to")
    parser.add_argument("-c", "--cc", help="An email address to CC on the report")
    parser.add_argument("-b", "--bcc", help="An email address to BCC on the report")
    parser.add_argument("-H", "--html", help="The HTML body of the email")
    parser.add_argument(
        "--subject", default="{{filter_name}} Report", help="The subject of the email"
    )
    parser.add_argument(
        "--html-template",
        type=Path,
        default=Path("jira-report.html"),
        help="An HTML file to use as a template",
    )
    parser.epilog = dedent(
        """
        The following environment variables are supported:
        - JIRA_EMAIL: The email address to authenticate with
        - JIRA_TOKEN: The token to authenticate with

        The following output types are supported:
        - csv: Comma-separated values
        - json: JSON
        - xlsx: Excel spreadsheet
        """
    )
    args = parser.parse_args()

    # If any fields were specified, then remove the default fields
    # Get the length of the default fields
    default_fields_len = len(parser.get_default("fields"))
    if len(args.fields) > default_fields_len:
        args.fields = args.fields[default_fields_len:]

    print(
        "logging in to jira with",
        args.jira_email,
        len(args.jira_token) * "*",
        "... ",
        flush=True,
        end="",
    )
    try:
        jira = JIRA(args.jira_email, args.jira_token)
    except Exception as e:
        print("error:", e, flush=True, file=sys.stderr)
        sys.exit(1)
    print("success", flush=True)
    print(
        "authenticating with smtp server", args.smtp_server, "... ", flush=True, end=""
    )
    try:
        smtp_client: SMTPClient = SMTPClient(
            args.smtp_email,
            args.smtp_password,
            args.smtp_server,
            args.smtp_port,
            args.smtp_tls,
        )
    except Exception as e:
        print("error:", e, flush=True, file=sys.stderr)
        sys.exit(1)
    print("success")
    print("fetching custom fields ... ", end="")
    # Get a list of all custom fields
    try:
        custom_fields_by_name: dict[str, str] = {
            field["name"]: field["id"] for field in jira.fields()
        }
        custom_fields_by_id: dict[str, str] = {
            v: k for k, v in custom_fields_by_name.items()
        }
    except Exception as e:
        print("error:", e, flush=True, file=sys.stderr)
        sys.exit(1)
    print("success", flush=True)
    df_prelist = []
    # Get all issues from the filter
    i = 0  # TODO: remove
    print(f"processing filter {args.filter} ... ", flush=True, end="")
    for issue in jira.search_all_issues(f""" filter = {args.filter} """):
        # Get each field from the issue and add it to the dataframe
        issue_fields: dict[str, str] = {}
        for field in args.fields:
            # print(f"processing {issue}.{field}")
            # Check if the field exists in either the raw issue or the custom fields
            field_id: str
            field_name: str
            if field in issue.raw["fields"]:
                field_id = field
            elif field in custom_fields_by_name:
                field_id = custom_fields_by_name[field]
            elif field == "key":
                field_id = "key"
            else:
                print(
                    f"Field {field} not found in issue {issue.key}, skipping",
                    flush=True,
                )
                continue
            if args.capitalize_fields:
                field_name = field.title()
            elif field_id in custom_fields_by_id:
                field_name = custom_fields_by_id[field_id]
            else:
                field_name = field
            # Get the value of the field
            if field_id == "key":
                field_value = issue.key
            else:
                field_value = normalize_issue_value(issue.raw["fields"][field_id])
            # If the value is a date, format it just a little more nicely
            if isinstance(field_value, str) and re.match(
                r"\d{4}-\d{2}-\d{2}", field_value
            ):
                # Check if it includes a time
                if re.match(r"d{2}:\d{2}:\d{2}", field_value):
                    date_format = "%Y-%m-%d %H:%M:%S %z"
                else:
                    date_format = "%Y-%m-%d"
                field_value = dateutil.parser.parse(field_value).strftime(date_format)
            issue_fields[field_name] = field_value
        df_prelist.append(issue_fields)
        i += 1
        # if i > 15:  # TODO: remove
        #     break  # TODO: remove this
    print(f"{i} issues found", flush=True)
    print("generating pandas dataframe ... ", flush=True)
    df = pd.DataFrame(df_prelist)
    print(df.head())

    print("generating report ... ", end="", flush=True)
    # Get the filter name
    filter_name = jira.filter(args.filter).name

    # Export the dataframe to the specified format
    export_data: bytes
    export_date: str = time.strftime("%d%b%Y").upper()
    export_name: str = f"{filter_name} - {export_date}.{args.output_type.value}"
    if args.output_type == OutputFormat.CSV:
        export_data = df.to_csv(index=False).encode()
    elif args.output_type == OutputFormat.JSON:
        export_data = df.to_json(orient="records", indent=4).encode()
    elif args.output_type == OutputFormat.EXCEL:
        from _io import BytesIO
        import xlsxwriter

        # Create a new writer in memory
        bytes_io = BytesIO()
        writer = pd.ExcelWriter(bytes_io, engine="xlsxwriter")

        # Write the dataframe to the writer
        df.to_excel(writer, index=False, sheet_name=export_date)

        # Fit the columns to the data
        for column in df.columns:
            column_length = max(df[column].astype(str).map(len).max(), len(column))
            # Don't go over 100
            column_length = min(column_length, 100)
            col_idx = df.columns.get_loc(column)
            writer.sheets[export_date].set_column(col_idx, col_idx, column_length + 2)

        # Close the writer and get the data
        writer.save()
        export_data = bytes_io.getvalue()
    else:
        print(f"Output type {args.output_type} not supported, exiting")
        sys.exit(1)

    print("success", flush=True)
    print("generating email ... ", flush=True, end="")

    # Format the HTML body
    html: str
    if args.html:
        html = args.html
    elif args.html_template and args.html_template.exists():
        html = args.html_template.read_text()
    else:
        html = dedent(
            """
            <h1>{{filter_name}} Report</h1>
            <p>Exported on {{export_date}} with {{issue_count}} issue{{issue_count_plural}}.</p>
            {{issue_table}}
            """
        )

    # Replace a few common variables
    if "{{filter_name}}" in html:
        html = html.replace("{{filter_name}}", filter_name)
    if "{{filter_name}}" in args.subject:
        args.subject = args.subject.replace("{{filter_name}}", filter_name)
    if "{{export_date}}" in html:
        html = html.replace("{{export_date}}", export_date)
    if "{{export_date}}" in args.subject:
        args.subject = args.subject.replace("{{export_date}}", export_date)
    if "{{issue_count}}" in html:
        html = html.replace("{{issue_count}}", str(len(df)))
    if "{{issue_count}}" in args.subject:
        args.subject = args.subject.replace("{{issue_count}}", str(len(df)))
    if "{{issue_count_plural}}" in html:
        html = html.replace("{{issue_count_plural}}", "s" if len(df) != 1 else "")
    if "{{issue_count_plural}}" in args.subject:
        args.subject = args.subject.replace(
            "{{issue_count_plural}}", "s" if len(df) != 1 else ""
        )
    if "{{issue_table}}" in html:
        import numpy as np
        from premailer import transform

        # Limit the rows shown in the email
        max_html_rows = 10

        # Construct a mask of which columns are numeric
        numeric_col_mask = df.dtypes.apply(
            lambda d: issubclass(np.dtype(d).type, np.number)
        )

        # Dict used to center the table headers
        table_styles = [
            {
                "selector": "th",
                "props": [
                    ("border", "none"),
                    ("text-align", "left"),
                    ("font-weight", "bold"),
                    ("padding-left", "1em"),
                ],
            },
            {
                "selector": "td",
                "props": [
                    ("border", "none"),
                    ("padding", "0.5em 1em"),
                ],
            },
            {
                "selector": "tr",
                "props": [
                    ("border", "none"),
                    ("border-bottom", "2px solid rgba(122, 122, 122, 0.5)"),
                ],
            },
            {
                "selector": "",  # the table itself
                "props": [
                    ("border-collapse", "collapse"),
                    ("border-spacing", "0"),
                    ("width", "100%"),
                ],
            },
        ]

        # Create a Styler
        df_styled = (
            df.iloc[:max_html_rows]
            .style.set_properties(
                subset=df.columns[
                    numeric_col_mask
                ],  # right-align the numeric columns and set their width
                **{"text-align": "right"},
            )
            .set_properties(
                subset=df.columns[
                    ~numeric_col_mask
                ],  # left-align the non-numeric columns and set their width
                **{"text-align": "left"},
            )
            .format(
                lambda x: "{:,.0f}".format(x)
                if x > 1e3
                else "{:,.2f}".format(x),  # format the numeric values
                subset=pd.IndexSlice[:, df.columns[numeric_col_mask]],
            )
            .set_table_styles(table_styles)
        ).hide(axis="index")
        # center the header
        # df_styled = df.style.set_properties(
        #     **{"text-align": "center", "font-weight": "bold"}
        # ).hide(axis="index")

        # export html with style
        table_html = df_styled.to_html()
        # If there are more than 20 rows, add a message to the bottom of the table
        if len(df) > max_html_rows:
            print("Adding overflow message to bottom of table")
            table_html = table_html.replace(
                "</tbody>",
                f"""
            <tr>
                <td colspan="{len(df.columns)}" style="
                    text-align: center;
                    font-style: italic;
                ">
                    {len(df) - max_html_rows} more rows in attached report
                </td>
            </tr>
            </tbody>
            """,
            )

        # Make the <style> tag inline
        table_html = transform(table_html)
        html = html.replace("{{issue_table}}", table_html)

    print("success", flush=True)

    print("sending email ... ", flush=True, end="")
    try:
        smtp_client.send_email(
            to=args.to,
            cc=args.cc,
            bcc=args.bcc,
            subject=args.subject,
            sender=args.smtp_email,
            body_html=html,
            # body_text=df.to_string(),
            attachments={export_name: export_data},
        )
    except Exception as e:
        print("error:", e, flush=True, file=sys.stderr)
        sys.exit(1)
    print("success", flush=True)
