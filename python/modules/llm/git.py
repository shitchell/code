#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
This module provides functions for generating commit messages from a diff of changes
using OpenAI's GPT-3 model.
"""

import json as _json
import os as _os
import re as _re
import sys as _sys
from pprint import pprint as _pprint
from textwrap import dedent as _dedent
from typing import List as _List, Tuple as _Tuple

import openai as _openai

from . import core as _core


def _md_newlines(text: str) -> str:
    text = _re.sub(r"\n\n\n+", "\0\0", text)
    text = _re.sub(r"\n\n", "\0", text)
    text = text.replace("\n", " ")
    text = _re.sub(r" +", " ", text)
    text = _re.sub(r"\0", "\n", text)
    text = _re.sub(r"^ +", "", text, flags=_re.MULTILINE)
    text = text.replace("\f", "")
    return text

def review_diff(
        diff: str,
        max_size: int = 10000,
        key: str = _os.environ.get(_core.OPENAI_ENVIRON_KEY)
    ) -> _Tuple[bool, str]:
    """
    Review a diff, checking for common issues:
    * Passwords included
    * Syntax errors
    * Hardcoded values
    * Debugging code left in (without using appropriate log/debugging functions)
    * Large/empty diffs

    Args:
        diff (str): The diff of changes to review.

    Returns:
        Tuple[bool, str]: A tuple containing a boolean indicating whether the
        diff is valid and a string containing an error message if the diff is
        invalid.
    """
    # Clean up the diff and reduce chars
    diff = _re.sub(r"\n+", "\n", diff)
    diff = diff.strip()

    # Do the bare minimum before anything else
    if not diff:
        return False, "error: diff is empty"

    # Check that we have a key
    if not key:
        raise ValueError("No OpenAI API key provided")

    # Initialize the API connection
    client = _openai.OpenAI(api_key=key)
    _openai.api_key = key

    # Create an example diff for testing
    example_diffs: list[str] = [
        (
            "diff --git a/foo.py b/foo.py\n"
            "index 0123456..abcdef 100644\n"
            "--- a/foo.py\n"
            "+++ b/foo.py\n"
            "@@ -1,1 +1,1 @@\n"
            # This will raise an import warning, since the diff deletes bar.py
            "-import bar\n"
            # Include a password error
            "+user_password = os.environ.get('PASSWORD', 'hunter2')\n"
            # Include a syntax error
            "@@ -5,1 +5,1 @@\n"
            "-print('Hello, world!')\n"
            "+print('Hello, world!'\n"
            # Include a hardcoded value error that should also trigger a debug
            # warning
            "@@ -10,2 +10,5 @@\n"
            "-a = input('Enter a number: ')\n"
            "-b = input('Enter another number: ')\n"
            "+#a = input('Enter a number: ')\n"
            "+#b = input('Enter another number: ')\n"
            "+# Set these values for now\n"
            "+a = 42\n"
            "+b = 23\n"
            # Include a debugging statement that should trigger a debug warning
            "@@ -17,0 +18,1 @@\n"
            "+print('Line 33: `foo` value:', foo, file=sys.stderr)\n"
            "diff --git a/bar.py b/bar.py\n"
            "deleted file mode 100644\n"
            "index 95e217f..0000000\n"
            "--- a/bar.py\n"
            "+++ /dev/null\n"
        ),
        (
            "diff --git a/llm/git.py b/llm/git.py\n"
            "index c372cad..133ec1e 100644\n"
            "--- a/llm/git.py\n"
            "+++ b/llm/git.py\n"
            "@@ -192,10 +264,15 @@ def describe_diff(\n"
            "     # Debug the messages\n"
            "     # print(\"Messages:\\n----\", _json.dumps(messages, indent=2)"
            ", \"----\", file=_sys.stderr)\n"
            "     # print(\"Messages:\\n----\")\n"
            "     # _pprint(messages)\n"
            "     # print(\"----\")\n"
            "     # return\n"
            "-    # print(\"Messages:\\n----\")\n"
            "-    # _pprint(messages)\n"
            "-    # print(\"----\")\n"
            "-    # return\n"
            # True life debug statements from this script :')
            "+    print(f\"SYSTEM MESSAGE\\n----\\n{system_message}\\n\\n\", "
            "file=_sys.stderr)\n"
            "+    print(f\"EXAMPLE BASIC\\n----\\n{example_basic_diff}\\n\\n\","
            " file=_sys.stderr)\n"
            "+    print(f\"EXAMPLE BASIC RESPONSE\\n----\\n"
            "{example_basic_response}\\n\\n\", file=_sys.stderr)\n"
            "+    print(f\"EXAMPLE EXTENDED\\n----\\n"
            "{example_extended_diff}\\n\\n\", file=_sys.stderr)\n"
            "+    print(f\"EXAMPLE EXTENDED RESPONSE\\n----\\n"
            "{example_extended_response}\\n\\n\", file=_sys.stderr)\n"
            "+    # _pprint(messages, stream=_sys.stderr, width=120)\n"
            "+    print(\"----\", file=_sys.stderr)\n"
            "+    print(diff, file=_sys.stderr)\n"
            "+    return\n"
            "     # Generate the commit message\n"
            "     response = client.chat.completions.create(\n"
        )
    ]
    example_responses: str = [
        (
            "[-1,1 +1,1] error: foo.py imports `bar`, which is being deleted\n"
            "[-1,1 +1,1] error: password found: `user_password`\n"
            "[-5,1 +5,1] error: syntax error: missing closing parenthesis\n"
            "[10,2 +10,5] warning: hardcoded value: `a`\n"
            "[10,2 +10,5] warning: hardcoded value: `b`\n"
            "[10,2 +10,5] warning: hardcoded values appear to be debugging "
            "code\n"
            "[17,0 +18,1] warning: debugging code found: `print('Line 33: `foo`"
            " value:', foo)`\n"
        ),
        (
            "[-192,10 +264,15] warning: debugging code found: `print(f\"SYSTEM "
            "MESSAGE\\n----\\n{system_message}\\n\\n\", file=_sys.stderr)`\n"
            "[-192,10 +264,15] warning: debugging code found: `print(f\"EXAMPLE"
            " BASIC\\n----\\n{example_basic_diff}\\n\\n\", file=_sys.stderr)`\n"
            "[-192,10 +264,15] warning: debugging code found: `print(f\"EXAMPLE"
            " BASIC RESPONSE\\n----\\n{example_basic_response}\\n\\n\", file="
            "_sys.stderr)`\n"
            "[-192,10 +264,15] warning: debugging code found: `print(f\"EXAMPLE"
            " EXTENDED\\n----\\n{example_extended_diff}\\n\\n\", file="
            "_sys.stderr)`\n"
            "[-192,10 +264,15] warning: debugging code found: `print(f\"EXAMPLE"
            " EXTENDED RESPONSE\\n----\\n{example_extended_response}\\n\\n\", "
            "file=_sys.stderr)`\n"
            "[-192,10 +264,15] warning: debugging code found: `print(diff, "
            "file=_sys.stderr)`\n"
        )
    ]

    # Create an *bad* response to correct
    bad_example_diff: str = (
        "diff --git a/foo.py b/foo.py\n"
        "index 0123456..abcdef 100644\n"
        "--- a/foo.py\n"
        "+++ b/foo.py\n"
        "@@ -11,0 +12,1 @@\n"
        # Debug example
        "+print('Line 1 -- Debugging code')\n"
    )
    bad_example_response: str = (
        'success'
    )
    bad_example_correction: str = (
        "INVALID RESPONSE. The response should have been:\n"
        "[-11,0 +12,1] warning: debugging code found: `print('Line 1 -- "
        "Debugging code')`\n"
    )

    # Create a direct set of instructions for the model
    system_message: str = (
        "The user will provide a `git diff` output, and you are to review the "
        "diff for common issues. These include:\n"
        "* Passwords included\n"
        "* Syntax errors\n"
        "* Hardcoded integers\n"
        "* Debugging code left in (without using appropriate log/debugging "
        "functions)\n"
        "\n"
        "Each issue detected should be in the format:\n"
        "* `[diff location] error: <error message>`\n"
        "\n"
        "Tips:\n"
        "* Uses of `pprint` or printing to stderr are often debug code.\n"
        "* Some values must be hardcoded. Only look for integers that seem like"
        " they should be variables.\n\n"
        "There should be NO commentary and NO additional information provided "
        "except for the specific error messages.\n"
        "If there are no issues detected, respond with 'success'."
    )

    # Set up the message list
    messages: list[dict[str, str]] = [
        {"role": "system", "content": "You are a diff reviewer."},
        {"role": "system", "content": system_message}
    ]
    # Add the examples
    for example_diff, example_response in zip(example_diffs, example_responses):
        messages.extend([
            {"role": "user", "content": example_diff},
            {"role": "assistant", "content": example_response}
        ])
    # Add the bad example
    messages.extend([
        {"role": "user", "content": bad_example_diff},
        {"role": "assistant", "content": bad_example_correction},
        {"role": "system", "content": bad_example_response}
    ])
    # Add the user's diff
    messages.append({"role": "user", "content": diff})

    # _pprint(messages, width=120, stream=_sys.stderr)

    # Generate the review message
    response = client.chat.completions.create(
        model="gpt-4-turbo-preview",
        messages=messages,
        temperature=0.1,
    )
    message: str = response.choices[0].message.content
    success: bool = message == "success"

    # If the diff is too large, add a warning
    if len(diff) > max_size:
        success = False
        message = (
            f"warning: diff is too large ({len(diff)} > {max_size} bytes)\n"
            f"{message}"
        )

    return success, message

def describe_diff(
    diff: str, key: str = _os.environ.get(_core.OPENAI_ENVIRON_KEY)
) -> str:
    """
    Generate a commit message from a diff of changes.

    Args:
        diff (str): The diff of changes.

    Returns:
        str: The generated commit message.
    """
    # Check that we have a key
    if not key:
        raise ValueError("No OpenAI API key provided")

    # Initialize the API connection
    client = _openai.OpenAI(api_key=key)
    _openai.api_key = key

    # Clean up the diff and reduce chars
    diff = _re.sub(r"\n+", "\n", diff)
    diff = diff.strip()

    # Generate a system message for teaching the model how to generate a commit message
    system_message: str = (
        "The user will provide `git diff` output, and you are to describe the "
        "changes as a commit message. Changes with a `+` at the beginning of "
        "the line are newly added lines. Changes with a `-` at the beginning "
        "are deleted lines. Commit messages use one of the two formats:\n"
        "\n"
        "## BASIC_FORMAT\n"
        "<summary>\n"
        "\n"
        "## EXTENDED_FORMAT\n"
        "<summary>\n"
        "* additional detail\n"
        "* another detail\n"
        "\n"
        "If the diff is small, use BASIC_FORMAT. If the diff is large, use "
        "EXTENDED_FORMAT.\n"
        "\n"
        "Rules for the summary:\n"
        "1. Start with a capital letter\n"
        "2. Must always be less than 80 characters\n"
        "3. Must be one sentence\n"
        "4. Do not end with a period\n"
        "\n"
        "Rules for the additional details:\n"
        "1. Should generally be a bullet list\n"
        "2. Should be a list of changes made in the commit\n"
        "3. Each item should end with a period"
    )

    # Set up two example responses for the model to learn from
    ## Basic example
    example_basic_diff: str = (
        "diff --git a/file.txt b/file.txt\n"
        "index 0123456..abcdef 100644\n"
        "--- a/file.txt\n"
        "+++ b/file.txt\n"
        "@@ -1,3 +1,3 @@\n"
        "-print('Hi! Welcome to the program')\n"
        "+print('Hi! Welcome to the program!')\n"
    )
    example_basic_response: str = (
        "Add a closing exclamation point to the welcome message"
    )
    ## Extended example
    example_extended_diff: str = (
        "diff --git a/file.txt b/file.txt\n"
        "index 0123456..abcdef 100644\n"
        "--- a/file.txt\n"
        "+++ b/file.txt\n"
        "@@ -1,3 +1,3 @@\n"
        "+file.write(f'User's email: {user.email}')\n"
        "-file.write(f'{user.name} is {user.age} years old')\n"
        "+file.write(f'{user.name} is {user.age} years old.')\n"
        "+file.flush()\n"
        "+if user.age >= 18:\n"
        "+    file.write('User is an adult.')\n"
        "@@ -5,3 +10,3 @@\n"
        "-while True:\n"
        "+is_done = False\n"
        "+while not is_done:\n"
        "@@ -10,3 +15,3 @@\n"
        "     if processed_users >= total_users:\n"
        "-        break\n"
        "+        is_done = True\n"
        "diff --git a/otherfile.txt b/otherfile.txt\n"
        "deleted file mode 100644\n"
        "index 95e217f..0000000\n"
        "--- a/otherfile.txt\n"
        "+++ /dev/null\n"
    )
    example_extended_response: str = (
        "Update user logging, update loop termination logic, and delete "
        "otherfile.txt\n"
        "\n"
        "* Add user's email, age, and adult status to the log\n"
        "* Change loop termination to use a boolean flag `is_done`\n"
        "* Terminate the loop when `processed_users >= total_users`\n"
        "* Delete file: `otherfile.txt`"
    )

    # Set up the message list
    messages: list[str] = [
        {"role": "system", "content": "You are a git commit generator."},
        {"role": "system", "content": system_message},
        {"role": "user", "content": example_basic_diff},
        {"role": "assistant", "content": example_basic_response},
        {"role": "user", "content": example_extended_diff},
        {"role": "assistant", "content": example_extended_response},
        {"role": "user", "content": diff},
    ]

    # # Debug the messages
    # # print("Messages:\n----", _json.dumps(messages, indent=2), "----", file=_sys.stderr)
    # print(f"SYSTEM MESSAGE\n----\n{system_message}\n\n", file=_sys.stderr)
    # print(f"EXAMPLE BASIC\n----\n{example_basic_diff}\n\n", file=_sys.stderr)
    # print(f"EXAMPLE BASIC RESPONSE\n----\n{example_basic_response}\n\n", file=_sys.stderr)
    # print(f"EXAMPLE EXTENDED\n----\n{example_extended_diff}\n\n", file=_sys.stderr)
    # print(f"EXAMPLE EXTENDED RESPONSE\n----\n{example_extended_response}\n\n", file=_sys.stderr)
    # # _pprint(messages, stream=_sys.stderr, width=120)
    # print("----", file=_sys.stderr)
    # print(diff, file=_sys.stderr)
    # return

    # Generate the commit message
    response = client.chat.completions.create(
        model="gpt-4-turbo-preview",
        messages=messages,
        temperature=0.25,
    )
    return response.choices[0].message.content


if __name__ == "__main__":
    import argparse

    # Right now we only support generating diffs, but we might want to add more
    # functionality later. With that in mind, the usage will be:
    #   git.py <subcommand> [<args>]
    # Where subcommand will be one of:
    #   - diff: Generate a commit message from a diff of changes
    #   - more to come later

    # Set up the argument parser
    parser = argparse.ArgumentParser(description="do git stuff with an LLM")

    # Add the subparsers
    subparsers = parser.add_subparsers(dest="subcommand", required=True)

    # Add the diff commit message subcommand
    diff_parser = subparsers.add_parser(
        "diff-msg", help="Generate a commit message from a diff"
    )
    diff_parser.add_argument("diff", help="The diff of changes")

    # Add the diff review subcommand
    review_parser = subparsers.add_parser(
        "diff-review", help="Review a diff for common issues"
    )
    review_parser.add_argument(
        "-m",
        "--max-size",
        type=int,
        default=100000,
        help="The maximum size of the diff"
    )
    review_parser.add_argument("diff", help="The diff of changes")

    # Parse the arguments
    args = parser.parse_args()

    # Run the appropriate subcommand
    if args.subcommand == "diff-msg":
        print(describe_diff(args.diff))
    elif args.subcommand == "diff-review":
        success, response = review_diff(args.diff, args.max_size)
        print(response)
        if not success:
            _sys.exit(1)
    else:
        raise ValueError(f"Invalid subcommand: {args.subcommand}")
