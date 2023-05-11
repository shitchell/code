"""
Provides the main entry point for the trinoor-email package.
"""


def main():
    import argparse
    import os
    import sys
    import textwrap

    from . import SMTPClient
    from argparse import (
        ArgumentParser,
        _ArgumentGroup,
        Namespace,
        RawDescriptionHelpFormatter,
    )
    from pathlib import Path

    parser: ArgumentParser = argparse.ArgumentParser(
        prog=(__package__ if __name__ == "__main__" else None),
        formatter_class=RawDescriptionHelpFormatter,
    )
    required_args: _ArgumentGroup = parser.add_argument_group("required arguments")
    server_args: _ArgumentGroup = parser.add_argument_group("smtp server")
    email_args: _ArgumentGroup = parser.add_argument_group("email options")
    server_args.add_argument(
        "-s",
        "--smtp-server",
        default=os.environ.get("SMTP_HOST", "smtp.office365.com"),
        help="The SMTP server to use",
    )
    server_args.add_argument(
        "-p", "--smtp-port", default=587, type=int, help="The SMTP port to use"
    )
    server_args.add_argument(
        "-t",
        "--starttls",
        action="store_true",
        default=(os.environ.get("SMTP_STARTTLS", "true").lower() in ("true", "1")),
        help="Connect to the SMTP server using STARTTLS",
    )
    server_args.add_argument(
        "--no-starttls",
        action="store_false",
        dest="starttls",
        help="Do not connect to the SMTP server using STARTTLS",
    )
    required_args.add_argument(
        "-f",
        "--from",
        type=str,
        dest="sender",
        default=os.environ.get("SMTP_EMAIL"),
        required=False,
        help="The email address of the sender",
    )
    server_args.add_argument(
        "--password",
        type=str,
        default=os.environ.get("SMTP_PASSWORD"),
        help="The password for the SMTP server",
    )
    server_args.add_argument(
        "-P",
        "--prompt-password",
        action="store_true",
        default=False,
        help="Prompt for the SMTP password",
    )
    required_args.add_argument(
        "-r",
        "--recipient",
        action="append",
        default=[],
        required=True,
        help="The email address(es) of the recipient(s)",
    )
    email_args.add_argument(
        "-c",
        "--cc",
        action="append",
        default=[],
        help="The email address(es) to carbon copy",
    )
    email_args.add_argument(
        "-b",
        "--bcc",
        action="append",
        default=[],
        help="The email address(es) to blind carbon copy",
    )
    email_args.add_argument(
        "-S", "--subject", default="No subject", help="The subject of the email"
    )
    email_args.add_argument(
        "-A",
        "--attachment",
        action="append",
        default=[],
        type=Path,
        help="The file(s) to attach to the email",
    )
    email_args.add_argument(
        "-H", "--html", default="", help="The HTML body of the email"
    )
    email_args.add_argument(
        "-T", "--text", default="", help="The text body of the email"
    )
    email_args.add_argument("--raw", type=str, default="", help="The raw email to send")
    email_args.add_argument(
        "--header", nargs="+", default=[], help="An SMTP header to add to the email"
    )
    parser.epilog = textwrap.dedent(
        """
        For --html, --text, and --raw, '-' can be used to read from stdin. If only
        --html is provided, the text body will be generated from the HTML body.

        --recipient, --cc, --bcc, and --attachment can be provided multiple times. Each
        email should be a string in the format "foo@bar.com" or
        "John Smith <john@smith.com>"

        It is not recommended to pass the password via the --password option. It can
        either be prompted for using the --prompt-password argument or set via the
        SMTP_PASSWORD environment variable.

        Headers added via --header should be in the format "Header: Value"

        If --raw is provided, it will be used as the email to send, and all other email
        options will be ignored.
    """
    )
    args: Namespace = parser.parse_args()

    # If the password is not set and the --prompt-password argument is set, prompt for
    # the password
    password: str = args.password
    if not password and args.prompt_password:
        from getpass import getpass

        password = getpass("Password: ")

    if not args.sender:
        parser.print_usage()
        print(
            f"{parser.prog}: error: "
            "no sender email or SMTP_EMAIL environment variable set"
        )
        sys.exit(1)

    # Connect to the SMTP server
    client: SMTPClient = SMTPClient(
        args.sender,
        password,
        args.smtp_server,
        args.smtp_port,
        args.starttls,
    )

    # Process the headers
    headers: dict[str, str] = {}
    for header in args.header:
        try:
            key, value = header.split(": ", 1)
        except ValueError:
            print(f"Invalid header: {header}")
            sys.exit(1)
        headers[key] = value.strip()

    # Process the attachments
    attachments: dict[str, bytes] = {}
    for attachment in args.attachment:
        print(f"Attaching '{attachment.name}'", end=" ")
        try:
            with attachment.open("rb") as f:
                attachments[attachment.name] = f.read()
                print(f"({len(attachments[attachment.name])} bytes)")
        except FileNotFoundError:
            print(f"\nFile not found: {attachment}", file=sys.stderr)
            sys.exit(1)
        except PermissionError:
            print(f"\nPermission denied: {attachment}", file=sys.stderr)
            sys.exit(1)

    # Determine if we should read the text/html body from stdin
    if args.text == "-":
        args.text = sys.stdin.read()
    if args.html == "-":
        args.html = sys.stdin.read()
    if args.raw == "-":
        args.raw = sys.stdin.read()

    # Send the email
    client.send_email(
        args.recipient,
        args.subject,
        args.sender,
        args.html,
        args.text,
        args.cc,
        args.bcc,
        attachments,
        headers,
        False,
        args.raw,
    )


if __name__ == "__main__":
    main()
