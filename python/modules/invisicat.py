#!/usr/bin/env python
# -*- coding: utf-8 -*-
r"""
Provides functions for viewing invisible characters in text. When run as a script,
accepts piped data from stdin or a file and prints the text with invisible
characters optionally highlighted.

When processing the text, each line is escaped to show invisible characters. This
converts, for example, "\x1b[31m" to "\\x1b[31m". This is done using the `bytestr()`
function provided below. The `highlight_escape_chars()` function then uses regular
expressions to find and highlight escape sequences in the text. The regular expressions
used are:
- REGEX_ANSI_SEQUENCES: \\x1b(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])?
- REGEX_HEXADECIMAL: \\x[0-9a-zA-Z]{2}
- REGEX_HEXADECIMAL_NO_ANSI: \\x(?:(?!1b))[0-9a-zA-Z]{2}
- REGEX_WHITESPACE: \\[nrtbfv0]

Because the characters are escaped, each regex pattern looks for escaped versions of
each escape sequence. If you wish to make use of these regex patterns in your own code,
you'll need to ensure the text is escaped using `bytestr()` first.
"""
import re as _re
from typing import IO as _IO, Generator as _Generator

REGEX_ANSI_SEQUENCES: _re.Pattern = _re.compile(
    r"\\x1b(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])?"
)
REGEX_HEXADECIMAL: _re.Pattern = _re.compile(r"\\x[0-9a-zA-Z]{2}")
REGEX_HEXADECIMAL_NO_ANSI: _re.Pattern = _re.compile(r"\\x(?:(?!1b))[0-9a-zA-Z]{2}")
REGEX_WHITESPACE: _re.Pattern = _re.compile(r"\\[nrtbfv0]")


def bytestr(text: str | bytes, encoding: str = "utf-8") -> str:
    """
    Given some text, return a string with all non-standard character codes shown
    escaped in bytes format. This is useful for showing invisible characters in text.

    The encoding will be ignored if supplied text is a bytes object.

    Args:
        text (str | bytes): The text to convert.
        encoding (str): The encoding to use when converting the text to bytes. Defaults
            to 'utf-8'.

    Returns:
        str: The text with all non-standard characters escaped in bytes format.
    """
    # Convert the text to bytes using the specified encoding
    #   Form feed's (\f) a cool char\n => b"Form feed's (\x0c) a cool char\n"
    if isinstance(text, str):
        text_bytes: bytes = text.encode(encoding, "surrogatepass")
    else:
        text_bytes = text
    # Convert the bytes to its string representation
    #   b"Form feed's (\x0c) a cool char\n" => 'b"Form feed\'s (\\x0c) a cool char\\n"'
    text = str(text_bytes)
    # Remove the 'b' prefix and quotes
    #   'b"Form feed\'s (\\x0c) a cool char\\n"' => Form feed's (\\x0c) a cool char\\n
    text = text[2:-1]

    return text


def _pre_process_text(
    text: str | bytes, ansi_sequences: bool, regexes: list[str] | None
) -> tuple[str, list[_re.Pattern]]:
    """
    Helper function for processing escape sequences. Returns the escaped text and a list
    of compiled regex patterns to match escape characters.
    """
    text = bytestr(text)

    # Create a set of patterns to match escape characters
    escape_patterns: list[_re.Pattern] = [REGEX_WHITESPACE]
    if ansi_sequences:
        escape_patterns.append(REGEX_ANSI_SEQUENCES)
        escape_patterns.append(REGEX_HEXADECIMAL_NO_ANSI)
    else:
        # Just look for hex escape characters
        escape_patterns.append(REGEX_HEXADECIMAL)

    # Post-process the regex patterns prepending a capture group for leading backslashes
    for i, pattern in enumerate(escape_patterns):
        escape_patterns[i] = _re.compile(r"(\\*)(" + pattern.pattern + ")")

    # Add any additional regex patterns
    if regexes is not None:
        for pattern in regexes:
            escape_patterns.append(_re.compile(r"(\\*)(" + pattern + ")"))

    return text, escape_patterns


def extract(
    text: str | bytes,
    ansi_sequences: bool = True,
    regexes: list[str] | None = None,
) -> list[_re.Match]:
    r"""
    Extracts escape characters from the text. Checks for:
    - Whitespace escape characters: \n, \r, \t, \b, \f, \v, \0
    - Hexidecimal escape characters: \x00 - \xff
    - ANSI escape sequences: \x1b[...m (if `ansi_sequences` is True)

    Args:
        text (str): The text to extract escape characters from.
        ansi_sequences (bool): If True, will also extract full ANSI escape sequences
            (i.e.: "\x1b[31m" instead of just "\x1b"). Defaults to True.
        regexes (list[str] | None): A list of additional regex patterns to match escape
            characters. The patterns should not include any capture groups. Defaults to
            None.

    Returns:
        list[re.Match]: A generator of re.Match objects containing the escape characters
            found in the text.
    """
    text, escape_patterns = _pre_process_text(text, ansi_sequences, regexes)
    matches: list[_re.Match] = []
    match_spans: set[tuple[int, int]] = set()

    for pattern in escape_patterns:
        for match in pattern.finditer(text):
            # Check if the match is a duplicate
            if match.span() in match_spans:
                continue
            matches.append(match)

    # Sort the matches by their start position
    matches.sort(key=lambda match: match.start())

    return matches


def _ansi_escape_match(
    match: _re.Match, prefix: str = "\x1b[7m", suffix: str = "\x1b[0m"
) -> str:
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

    # Condense the backslashes for proper display
    backslashes = backslashes.replace("\\\\", "\\")

    if do_escape:
        return backslashes + prefix + escape_chars + suffix
    return backslashes + escape_chars


def highlight(
    text: str | bytes,
    ansi_sequences: bool = True,
    prefix: str = "\x1b[7m",
    suffix: str = "\x1b[0m",
    regexes: list[str] | None = None,
) -> str:
    r"""
    Highlights escape characters in the text by prefixing them with the supplied prefix
    and suffix. Checks for:
    - Whitespace escape characters: \n, \r, \t, \b, \f, \v, \0
    - Hexidecimal escape characters: \x00 - \xff
    - ANSI escape sequences: \x1b[...m (if `ansi_sequences` is True)

    Args:
        text (str): The text to highlight escape characters in.
        ansi_sequences (bool): If True, will also highlight full ANSI escape sequences
            (i.e.: "\x1b[31m" instead of just "\x1b"). Defaults to True.
        prefix (str): The prefix to insert before highlighted characters. Defaults to
            "\x1b[7m" (ANSI reverse video).
        suffix (str): The suffix to insert after highlighted characters. Defaults to
            "\x1b[0m" (ANSI reset).
        regexes (list[str] | None): A list of additional regex patterns to match escape
            characters. The patterns should not include any capture groups. Defaults to
            None.

    Returns:
        str: The text with escape characters highlighted.
    """
    text, escape_patterns = _pre_process_text(text, ansi_sequences, regexes)

    # Search for the escape characters and add the ANSI reverse video escape sequence
    for pattern in escape_patterns:
        # Prepend each pattern to capture any backslashes before the escape character.
        # Our replacement function will then count the number of backslashes and only
        # add the ANSI escape sequence if the number of backslashes is odd.
        text = _re.sub(
            pattern, lambda match: _ansi_escape_match(match, prefix, suffix), text
        )
    return text


def _main():
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
        "-a",
        "--ansi",
        action="store_true",
        default=True,
        dest="ansi",
        help="highlight full ANSI escape sequences (e.g.: \\x1b[31m)",
    )
    parser.add_argument(
        "-A",
        "--no-ansi",
        action="store_false",
        dest="ansi",
        help="don't highlight ANSI escape sequences",
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
        "--binary",
        action="store_true",
        dest="binary",  # binary here means "bytes" in Python-speak
        help="Process the text as a binary stream instead of a string (ignores -e)",
    )
    parser.add_argument(
        "-t",
        "--text",
        action="store_false",
        dest="binary",
        help="Process the text as a string instead of a binary stream",
    )
    parser.add_argument(
        "-e",
        "--encoding",
        type=str,
        default="utf-8",
        help="The encoding to use when reading the file",
    )
    parser.add_argument(
        "-p",
        "--highlight-prefix",
        type=str,
        default="\x1b[7m",
        help="The prefix to insert before highlighted characters",
    )
    parser.add_argument(
        "-s",
        "--highlight-suffix",
        type=str,
        default="\x1b[0m",
        help="The suffix to insert after highlighted characters",
    )
    parser.add_argument(
        "-i",
        "--highlight",
        action="store_true",
        default=True,
        dest="highlight",
        help="highlight invisible characters",
    )
    parser.add_argument(
        "-I",
        "--no-highlight",
        action="store_false",
        dest="highlight",
        help="don't highlight invisible characters",
    )
    # Add epilog to show the usage message when the user requests help
    parser.epilog = "specifying '-' for a filepath will read from stdin"
    args: Namespace = parser.parse_args()

    # If there are no filepaths and stdin is being piped, add stdin to the filepaths
    if not sys.stdin.isatty() and Path("-") not in args.filepaths:
        args.filepaths.append(Path("-"))

    # Process each path
    for path in args.filepaths:
        ## Print the filename if requested
        if args.show_names:
            path_display_name: str = "<stdin>" if path == Path("-") else path.name
            # If an ANSI escape sequence is used for the prefix, then assume the
            # user is running in a terminal that supports color and dim the filename
            color_start: str = ""
            color_end: str = ""
            if args.highlight and "\x1b" in args.highlight_prefix:
                color_start = "\x1b[2m"
                color_end = "\x1b[0m"
            print(f"{color_start}: {path_display_name}{color_end}")

        ## Validate we can read from the file
        if path != Path("-"):
            if not path.is_file():
                print(f"error: '{path}' does not exist", file=sys.stderr)
                continue
            # Check if the file is readable
            if not os.access(path, os.R_OK):
                print(f"error: '{path}' is not readable", file=sys.stderr)
                continue

        ## Set up a file object to read from
        file: _IO
        if path == Path("-"):
            file = sys.stdin.buffer if args.binary else sys.stdin
        else:
            file = open(
                path,
                "rb" if args.binary else "r",
                encoding=None if args.binary else args.encoding,
            )

        ## Process each line of the file (supports a continuous stream)
        for line in file:
            if args.highlight and (args.highlight_prefix or args.highlight_suffix):
                # Highlight escape characters
                text = highlight(
                    line,
                    ansi_sequences=args.ansi,
                    prefix=args.highlight_prefix,
                    suffix=args.highlight_suffix,
                )
            else:
                # Just convert the line to a bytestr
                text = bytestr(line, args.encoding)

            # Finally, print the text
            print(text)


if __name__ == "__main__":
    import sys

    try:
        _main()
    except KeyboardInterrupt:
        sys.exit(0)
