#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
This module implements a mechanism for tracking time spent on tasks and saving them to a
csv file or sqlite database.
"""

import pandas as _pd

from enum import Enum as _Enum
from pathlib import Path as _Path

# Create a base class for a timesheet file with methods for adding and removing tasks
# Extend the base class to implement a csv file or sqlite database
# Allow for displaying the tasks using a specified format.

class TabularFormats(_Enum):
    """
    Enum for the supported tabular formats (all formats supported by pandas).
    """
    CSV = 1
    SQL = 2
    XML = 3
    XLSX = 4
    HTML = 5
    JSON = 6

class Timesheet:
    def __init__(self, path: _Path | str):
        self._path = Path(path)
        self.tasks = pd.DataFrame(columns=['task', 'time'])
        self.load()

    @property
    def path(self) -> _Path:
        return self._path

    @path.setter
    def path(self, path: _Path | str):
        if not hasattr(self, '_path'):
            self._path = Path(path)
        else:
            raise AttributeError('Cannot reassign path')

    def _determine_format(self) -> :

    def load(self) -> None:
        if self.path.exists():
            self.tasks = pd.read_csv(self.path)
        else:
            self.tasks = pd.DataFrame(columns=['task', 'time'])

if __name__ == "__main__":
    import argparse
    
    from argparse import ArgumentParser, ArgumentGroup
    
    # load settings from config/env/cmdline
    # determine if we're updating an existing entry, creating a new entry, deleting an
    # existing entry, or listing existing entries
    # if updating,
    #   get the existing entry/entries
    #   update the entry/entries
    #   save the csv file
    # else if creating,
    #   create a new entry
    #   save the csv file
    #   display the new entry with a success/failure message
    # else if deleting,
    #   get the existing entry / entries
    #   delete the entry / entries
    #   save the csv file
    #   display the deleted entry/entries with a success/failure message
    # else if listing,
    #   get all entries, optionally filtered based on the command line arguments
    #   display the entries
    
    parser: ArgumentParser = ArgumentParser(description="Timesheet")
    action_group: ArgumentGroup = parser.add_mutually_exclusive_group(required=True)
    action_group.add_argument("-u", "--update", action="store_true", default=False,
                              help="update an existing entry")
    action_group.add_argument("-c", "--create", action="store_true", default=True,
                              help="create a new entry")
    action_group.add_argument("-d", "--delete", action="store_true", default=False,
                              help="delete an existing entry")
    action_group.add_argument("-l", "--list", action="store_true", default=False,
                              help="list existing entries")
    