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
    system_message: str = _dedent(
        r"""
        The user will provide `git diff` output, and you are to describe the changes as
        a commit message. Changes with a "+" at the beginning of the line are newly
        added lines. Changes with a "-" at the beginning are deleted lines. Commit
        messages use one of the two formats:


        # Section: Formats


        ## Section: BASIC_FORMAT

        <summary>


        ## Section: EXTENDED_FORMAT

        <summary>


        * additional detail

        * another detail


        # Section: Example


        This is a longer commit message for a longer diff


        * This is an extra detail

        * This is another extra detail


        # Section: Rules


        If the diff is small, use BASIC_FORMAT. If the diff is large, use
        EXTENDED_FORMAT.


        Rules for the summary:

        1. Start with a capital letter

        2. Must always be less than 80 characters

        3. Must be one sentence

        4. Do not end with a period


        Rules for the additional details:

        1. Should generally be a bullet list

        2. Should be a list of changes made in the commit

        3. Each item should end with a period
    """
    )
    system_message = _md_newlines(system_message)

    # Set up two example responses for the model to learn from
    ## Basic example
    example_basic_diff: str = _dedent(
        """
        diff --git a/file.txt b/file.txt
        index 0123456..abcdef 100644
        --- a/file.txt
        +++ b/file.txt
        @@ -1,3 +1,3 @@
        -print("Hi! Welcome to the program")
        +print("Hi! Welcome to the program!")
    """
    )
    example_basic_diff = example_basic_diff.strip()
    example_basic_response: str = (
        "Add a closing exclamation point to the welcome message"
    )
    ## Extended example
    example_extended_diff: str = _dedent(
        """
        diff --git a/file.txt b/file.txt
        index 0123456..abcdef 100644
        --- a/file.txt
        +++ b/file.txt
        @@ -1,3 +1,3 @@
        +file.write(f"User's email: {user.email}")
        -file.write(f"{user.name} is {user.age} years old")
        +file.write(f"{user.name} is {user.age} years old.")
        +file.flush()
        +if user.age >= 18:
        +    file.write("User is an adult.")
        @@ -5,3 +10,3 @@
        -while True:
        +is_done = False
        +while not is_done:
        @@ -10,3 +15,3 @@
        \f     if processed_users >= total_users:
        -          break
        +          is_done = True
        diff --git a/otherfile.txt b/otherfile.txt
        deleted file mode 100644
        index 95e217f..0000000
        --- a/otherfile.txt
        +++ /dev/null
    """
    )
    example_extended_diff = example_extended_diff.strip().replace("\f", "")
    example_extended_response: str = _dedent(
        """
        Update user logging, update loop termination logic, and delete otherfile.txt

        * Add user's email, age, and adult status to the log
        * Change loop termination to use a boolean flag `is_done`
        * Terminate the loop when `processed_users >= total_users`
        * Delete file: `otherfile.txt`
    """
    )
    example_extended_response = example_extended_response.strip()

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

    # Debug the messages
    # print("Messages:\n----", _json.dumps(messages, indent=2), "----", file=_sys.stderr)
    # print("Messages:\n----")
    # _pprint(messages)
    # print("----")
    # return

    # Generate the commit message
    response = client.chat.completions.create(
        model="gpt-4-turbo-preview",
        messages=messages,
        temperature=0.5,
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

    # Add the diff subcommand
    diff_parser = subparsers.add_parser(
        "diff-msg", help="Generate a commit message from a diff"
    )
    diff_parser.add_argument("diff", help="The diff of changes")

    # Parse the arguments
    args = parser.parse_args()

    # Run the appropriate subcommand
    if args.subcommand == "diff-msg":
        print(describe_diff(args.diff))
    else:
        raise ValueError(f"Invalid subcommand: {args.subcommand}")
