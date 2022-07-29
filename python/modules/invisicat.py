#!/usr/bin/env python
"""
Provides functions for viewing invisible characters in text. When run as a script,
accepts piped data from stdin or a file and prints the text with invisible
characters optionally highlighted.
"""

import re as _re


def convert_to_bytes_str(text: str) -> str:
    # Convert the text to byte format to show all non-standard character codes
    text_bytes: bytes = text.encode()
    # Convert back to a string to keep the char formatting and remove `b'...'`
    text = str(text_bytes)[2:-1]
    # Add a newline after each '\n' for easier reading
    text = text.replace("\\n", "\\n\n")
    # Replace escaped single quotes with a single quote
    text = text.replace("\\'", "'")
    return text


def highlight_escape_chars(text: str) -> str:
    """
    Adds the ANSI reverse video escape sequence to highlight the escape characters
    """
    # Create a set of patterns to match escape characters
    # ANSI escape regex adapted from:
    # https://stackoverflow.com/a/14693789/794241
    escape_patterns: list[str] = [
        r"(?<!\\)\\x1b[@-Z\\-_]|\\x1b\[[0-?]*[ -/]*[@-~]", # ANSI escape characters
        r"(?<!\\)\\x(?:(?!1b))[0-9a-zA-Z]{2}", # Hexadecimal escape characters (except \x1b)
        r"(?<!\\)\\[nrtbfv0]", # Whitespace
    ]
    # Search for the escape characters and add the ANSI reverse video escape sequence
    for pattern in escape_patterns:
        text = _re.sub(pattern, lambda match: "\x1b[7m" + match.group(0) + "\x1b[0m", text)
    return text


if __name__ == "__main__":
    import argparse
    import os
    import sys

    from argparse import Namespace
    from pathlib import Path

    # Parse the command line arguments
    parser = argparse.ArgumentParser(description="View invisible characters in text")
    parser.add_argument("filepaths", nargs="*", type=Path,
                        help="files to read text from. - for stdin")
    parser.add_argument("-v", "--video", action="store_true", dest="video",
                        help="highlight escape characters with ANSI reverse video")
    parser.add_argument("-V", "--no-video", action="store_false", dest="video",
                        help="don't highlight escape characters")
    parser.add_argument("-n", "--names", action="store_true", dest="show_names",
                        help="show file names")
    parser.add_argument("-N", "--no-names", action="store_false", dest="show_names",
                        help="don't show file names")
    # Add epilog to show the usage message when the user requests help
    parser.epilog = "specifying '-' for a filepath will read from stdin"
    args: Namespace = parser.parse_args()

    # Determine if stdin is being piped or a file is being passed
    if sys.stdin.isatty():
        # Read from stdin
        text: str = sys.stdin.read()
    else:
        # Loop over each operand and read the text those files
        for path in args.filepaths:
            if args.show_names:
                path_display_name: str = "<stdin>" if path == Path("-") else path.name
                print(f"--- {path_display_name} ---")
            if path != Path("-"):
                if not path.is_file():
                    print("Error: '{}' does not exist".format(path), file=sys.stderr)
                    continue
                # Check if the file is readable
                if not os.access(path, os.R_OK):
                    print("Error: '{}' is not readable".format(path), file=sys.stderr)
                    continue
            # Read the text from the file
            text: str
            if path == Path("-"):
                text = sys.stdin.read()
            else:
                with open(path, "r") as f:
                    text = f.read()
            # Convert the text to byte format to show all non-standard character codes
            text = convert_to_bytes_str(text)
            # Optionally highlight escape characters
            if args.video:
                text = highlight_escape_chars(text)
            # Finally, print the text
            print(text, end="")
