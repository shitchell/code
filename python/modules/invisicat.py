#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Provides functions for viewing invisible characters in text. When run as a script,
accepts piped data from stdin or a file and prints the text with invisible
characters optionally highlighted.
"""

# TODO:
# - escape all backslashes with some character like % before highlighting
#   to be able to differentiate between literal escape characters and escape
#   characters written in the text

import re as _re
from typing import IO as _IO


def bytestr(text: str | bytes, encoding: str = "utf-8") -> str:
    # Convert the text to byte format to show all non-standard character codes
    #   Form feed's (\f) a cool char\n => $'Form feed\'s (\x0c) a cool char\n'
    if isinstance(text, str):
        text_bytes: bytes = text.encode(encoding, "surrogatepass")
    else:
        text_bytes = text
    # Convert back to a string to keep the char formatting and remove `b'...'`
    #   $'Form feed\'s (\x0c) a cool char\n' => Form feed\s (\x0c) a cool char\n
    text = str(text_bytes)[2:-1]
    # Add a newline after each '\n' for easier reading
    #   Form feed\s (\x0c) a cool char\n => Form feed\s (\x0c) a cool char\\n\n
    text = text.replace("\\n", "\\n\n")
    # Replace escaped single quotes with a single quote
    text = text.replace("\\'", "'")
    # Replace escaped backslashes with a single backslash
    # text = text.replace("\\\\", "\\")
    return text


def ansi_escape_match(match: _re.Match) -> str:
    """
    Given a match object with the groups (backslashes, escape characters), return a
    string with the ANSI reverse video escape sequence added to the escape characters
    if the number of backslashes is odd. Else, return the original characters (the
    groups concatenated).
    """
    backslashes: str = match.group(1)
    escape_chars: str = match.group(2)
    do_escape: bool = False
    # print(f"{backslashes=!r}, {escape_chars=!r}")
    # We want an odd number of backslashes, but since the escape_chars will include one
    # backslash, we need an even number of backslashes in the `backslashes` group to
    # total an odd number of overall backslashes.
    if len(backslashes) % 2 == 0:
        do_escape = True

    # The backslashes will need to be condensed for proper display
    backslashes = backslashes.replace("\\\\", "\\")

    if do_escape:
        return backslashes + "\x1b[7m" + escape_chars + "\x1b[0m"
    return backslashes + escape_chars


def highlight_escape_chars(text: str) -> str:
    """
    Adds the ANSI reverse video escape sequence to highlight the escape characters
    """
    # Create a set of patterns to match escape characters
    # ANSI escape regex adapted from:
    # https://stackoverflow.com/a/14693789/794241
    escape_patterns: list[str] = [
        r"\\x1b[@-Z\\-_]|\\x1b\[[0-?]*[ -/]*[@-~]",  # ANSI escape characters
        r"\\x(?:(?!1b))[0-9a-zA-Z]{2}",  # Hexadecimal escape characters (except \x1b)
        r"\\[nrtbfv0]",  # Whitespace
    ]
    # Search for the escape characters and add the ANSI reverse video escape sequence
    for pattern in escape_patterns:
        # Prepend each pattern to capture any backslashes before the escape character.
        # Our replacement function will then count the number of backslashes and only
        # add the ANSI escape sequence if the number of backslashes is odd.
        pattern = r"(\\*)(" + pattern + ")"
        text = _re.sub(pattern, ansi_escape_match, text)
    return text


if __name__ == "__main__":
    import argparse
    import os
    import sys

    from argparse import Namespace
    from pathlib import Path

    # Parse the command line arguments
    parser = argparse.ArgumentParser(description="View invisible characters in text")
    parser.add_argument(
        "filepaths", nargs="*", type=Path, help="files to read text from. - for stdin"
    )
    parser.add_argument(
        "-v",
        "--video",
        action="store_true",
        dest="video",
        help="highlight escape characters with ANSI reverse video",
    )
    parser.add_argument(
        "-V",
        "--no-video",
        action="store_false",
        dest="video",
        help="don't highlight escape characters",
    )
    parser.add_argument(
        "-n", "--names", action="store_true", dest="show_names", help="show file names"
    )
    parser.add_argument(
        "-N",
        "--no-names",
        action="store_false",
        dest="show_names",
        help="don't show file names",
    )
    parser.add_argument(
        "-b",
        "--bytes",
        action="store_true",
        dest="bytes",
        help="Process the text as a bytes stream instead of a string",
    )
    parser.add_argument(
        "-B",
        "--no-bytes",
        action="store_false",
        dest="bytes",
        help="Process the text as a string instead of a bytes stream",
    )
    parser.add_argument(
        "-e",
        "--encoding",
        type=str,
        default="utf-8",
        help="The encoding to use when reading the file",
    )
    # Add epilog to show the usage message when the user requests help
    parser.epilog = "specifying '-' for a filepath will read from stdin"
    args: Namespace = parser.parse_args()

    # If there are no filepaths and stdin is being piped, add stdin to the filepaths
    if not sys.stdin.isatty() and Path("-") not in args.filepaths:
        args.filepaths.append(Path("-"))

    # Process each path
    for path in args.filepaths:
        file: _IO
        if args.show_names:
            path_display_name: str = "<stdin>" if path == Path("-") else path.name
            print(f"---- {path_display_name} ----")
        if path != Path("-"):
            if not path.is_file():
                print("error: '{}' does not exist".format(path), file=sys.stderr)
                continue
            # Check if the file is readable
            if not os.access(path, os.R_OK):
                print("error: '{}' is not readable".format(path), file=sys.stderr)
                continue
        # Read the text from the file
        if path == Path("-"):
            file = sys.stdin.buffer if args.bytes else sys.stdin
        else:
            file = open(path, "rb" if args.bytes else "r")
        # Process each line of the file
        for line in file:
            # Convert the line to a bytestr to show all non-standard character codes
            text = bytestr(line, args.encoding)
            # Optionally highlight escape characters
            if args.video:
                text = highlight_escape_chars(text)
            # Finally, print the text
            print(text, end="")
