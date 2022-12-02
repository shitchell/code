#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
This module allows for manipulation of tabular data via pandas
"""
import os as _os
import pandas as _pd
import re as _re
import sqlite3 as _sqlite3

from enum import Enum as _Enum
from numpy import ndarray as _ndarray, dtype as _dtype
from pandas import DataFrame as _DataFrame
from pandas.core.series import Series as _Series
from pathlib import Path as _Path
from sqlite3 import Connection as _Connection, Cursor as _Cursor
from typing import Callable as _Callable


class TabularFormat(_Enum):
    """
    Enum for the supported tabular formats (all formats supported by pandas).
    """

    CSV = 1
    TSV = 2
    SQLITE = 3
    XML = 4
    XLSX = 5
    HTML = 6
    JSON = 7


class TableFile:
    """
    Base class for interacting with a file that contains tabular data.
    """

    _infile: _Path
    _outfile: _Path
    _format: TabularFormat
    data: _DataFrame
    na_values: list[str]
    # TODO: potentially move default columns to separate timesheet program
    _default_columns: list[str] = [
        "name",
        "description",
        "job_code",
        "start_time",
        "end_time",
        "duration",
    ]

    def __init__(
        self,
        infile: _Path | str = None,
        outfile: _Path | str = None,
        name: str = None,
        format: TabularFormat = None,
        column_names: list[str] = [],
        data: dict | _DataFrame = None,
        detect_types: bool = True,
        na_values: list[str] = ["nan", "nat", "NaN", "NaT"],
        con: _Connection = None,
    ) -> None:
        """
        Initialize the TableFile object

        Args:
            infile (_Path | str, optional): The path to the file to load data from.
                Defaults to None.
            outfile (_Path | str, optional): The path to write save data to. If not
                specified, will use the infile. Defaults to None.
            name (str, optional): For databases and Excel workbooks, the name of the
                table or sheet to use. Defaults to None.
            format (TabularFormat, optional): Use the specified format to load the
                data. Defaults to None.
            column_names (list[str], optional): Default column names to use if none are
                found. Defaults to [].
            data (dict | _DataFrame, optional): A dictionary of rows and columns to
                load. Defaults to None.
            detect_types (bool, optional): Use regex to attempt and convert columns to
                appropriate types. Defaults to True.
            na_values (list[str], optional): Values to treat as NaN. When writing to a
                csv, the first item will be used for NaN values. Defaults to ["nan", ""]
            con (_Connection, optional): A database connector. Defaults to None.
        """
        if infile is not None:
            self._infile = _Path(infile)
        else:
            self._infile = None
        if outfile is None:
            self._outfile = self._infile
        self.format = format
        self.name = name
        self._default_columns = column_names
        self.na_values = na_values
        self.load(name=name)
        if data is not None:
            self.data = self._to_df(data)
            self.add(data)
        if detect_types:
            self.set_column_types()

    def __repr__(self):
        return f"{self.__class__.__name__}({self.path}, type={self.format.name})"

    @property
    def infile(self) -> _Path:
        """
        The path to the input file.

        Returns:
            _Path: The path to the input file
        """
        return self._infile

    @infile.setter
    def infile(self, value: object) -> None:
        """
        Placeholder for a custom exception message indicating that the infile can only
        be set at initialization.

        Raises:
            AttributeError: The infile can only be set at initialization.
        """
        raise AttributeError("Attribute 'infile' can only be set at initialization")

    @property
    def outfile(self) -> _Path:
        """
        The path to the output file.

        Returns:
            _Path: The path to the output file
        """
        return self._outfile

    @outfile.setter
    def outfile(self, outfile: _Path | str) -> None:
        """
        Set the output file path.

        Args:
            outfile (_Path | str): The output file path
        """
        self._outfile = _Path(outfile)

    @property
    def path(self) -> _Path:
        """
        An alias for the outfile property.

        Returns:
            _Path: The path to the output file
        """
        return self.outfile or self.infile

    @path.setter
    def path(self, path: _Path | str):
        self.outfile = path

    # TODO: allow for tracking fileformat based on last saved format
    @property
    def format(self) -> TabularFormat:
        """
        Detect the format of the file

        Returns:
            TabularFormat (str): The file format
        """
        if self._format:
            return self._format
        if self.path.suffix == ".csv":
            return TabularFormat.CSV
        elif self.path.suffix == ".tsv":
            return TabularFormat.TSV
        elif self.path.suffix in [".sql", ".sqlite", ".sqlite3", "db"]:
            return TabularFormat.SQLITE
        elif self.path.suffix == ".xml":
            return TabularFormat.XML
        elif self.path.suffix == ".xlsx":
            return TabularFormat.XLSX
        elif self.path.suffix == ".html":
            return TabularFormat.HTML
        elif self.path.suffix == ".json":
            return TabularFormat.JSON
        else:
            raise ValueError("Unsupported format")

    @format.setter
    def format(self, format: TabularFormat | str) -> None:
        """
        Set the file format

        Args:
            format (TabularFormat | str): The file format
        """
        if isinstance(format, str):
            format = TabularFormat[format.upper()]
        self._format = format

    @property
    def na_rep(self) -> str:
        """
        The string to use for NaN values when writing to a csv file.

        Returns:
            str: The string to use for NaN values
        """
        return self.na_values[0]

    @property
    def columns(self) -> list[str]:
        """
        Get the column names from the file

        Returns:
            list[str]: The column names
        """
        return self.data.columns.tolist()

    @property
    def rows(self) -> int:
        """
        Get the number of rows in the timesheet.

        Returns:
            int: The number of rows
        """
        return len(self.data)

    @classmethod
    def _to_df(
        self, *args: dict[str, object] | list[dict[str, object]], **kwargs: str
    ) -> _DataFrame:
        """
        Convert the arguments to a DataFrame.

        Args:
            *args: A dictionary or a list of dictionaries
            **kwargs: A list of key/value pairs to generate a single row

        Examples:
            ```
            >>> self._to_df({"name": "Task 1", "description": "Description 1"})
            >>> self._to_df([
            ...     {"name": "Task 1", "description": "Description 1"},
            ...     {"name": "Task 2", "description": "Description 2"}
            ... ])
            >>> self._to_df(name="Task 1", description="Description 1")
            ```

        Returns:
            _DataFrame: The converted DataFrame
        """
        if len(args) == 1 and isinstance(args[0], dict):
            return _pd.DataFrame(args[0], index=[0])
        elif len(args) == 1 and isinstance(args[0], list):
            return _pd.DataFrame(args[0])
        else:
            return _pd.DataFrame(kwargs, index=[0])

    def _detect_type(
        self, values: [object], default: type = str, match_all: bool = True
    ) -> type:
        """
        Detect the type of the value of the objects using regex for strings:

        - `date`: `YYYY-MM-DD`
        - `datetime`: `YYYY-MM-DD HH:MM:SS`
        - `timedelta`: `HH:MM:SS`
        - `int`: `123`
        - `float`: `123.45`
        - `bool`: `true`, `false`, `yes`, `no`, `1`, `0`
        - `str`: any other value

        Args:
            values (list[object]): The values to detect
            default (type): The default type to return if no match is found. Defaults to
                str.
            match_all (bool, optional): If True, all values must match the same type.
                Defaults to True.

        Returns:
            type: The detected type
        """
        import datetime as _datetime

        detected_type: type = None
        for value in values:
            value_type: type = type(value)
            if value_type is str:
                # The value is a string, so try to detect the type
                if value.lower() in ["true", "false", "yes", "no", "1", "0"]:
                    value_type = bool
                elif _re.match(r"^\d{4}-\d{2}-\d{2}$", value):
                    value_type = _datetime.date
                elif _re.match(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?$", value):
                    value_type = _datetime.datetime
                elif _re.match(r"^\d{2}:\d{2}:\d{2}$", value):
                    value_type = _datetime.timedelta
                elif _re.match(r"^\d+$", value):
                    value_type = int
                elif _re.match(r"^\d+\.\d+$", value):
                    value_type = float
                else:
                    value_type = str
            # Compare the detected type to the previous detected type
            if detected_type is not None:
                if detected_type != value_type and match_all:
                    # If all values must match the same type, then we can stop
                    # checking and return the default type
                    return default

            # Update the detected type
            detected_type = value_type

        return detected_type

    def set_column_types(self, types: dict[str, object] = {}, **kwargs) -> None:
        """
        Convert columns to appropriate types. If `types` is not specified, will attempt
        to convert columns based on regex patterns:

        - `date`: `YYYY-MM-DD`
        - `datetime`: `YYYY-MM-DD HH:MM:SS`
        - `timedelta`: `HH:MM:SS`
        - `int`: `123`
        - `float`: `123.45`
        - `bool`: `true`, `false`, `yes`, `no`, `1`, `0`

        Args:
            types (dict[str, object]): A dictionary of column names and types
            **kwargs: Each key/value pair will be added to the `types` dictionary
        """
        import datetime as _datetime

        types.update(kwargs)
        if types:
            # Use the specified types to update the column types
            for column, dtype in types.items():
                if column in self.data.columns:
                    self.data[column] = self.data[column].astype(dtype)
        else:
            # Use regex patterns to update the column types
            for column in self.data.columns:
                # Retrieve 5 (or all if fewer) random non-null values from the column
                sample_size: int = min(5, self.data[column].count())
                values = self.data[column].dropna().sample(sample_size).tolist()
                # Determine the type of the values
                dtype = self._detect_type(values)
                # Handle dates, times, and timedeltas using pandas methods
                if dtype in [_datetime.date, _datetime.datetime, _datetime.timedelta]:
                    update_func: Callable
                    if dtype is _datetime.date:
                        update_func = _pd.to_datetime
                    elif dtype is _datetime.datetime:
                        update_func = _pd.to_datetime
                    elif dtype is _datetime.timedelta:
                        update_func = _pd.to_timedelta
                    try:
                        self.data[column] = update_func(self.data[column])
                    except Exception as e:
                        # The column could not be updated
                        pass
                else:
                    # Try to update the column type to the detected type
                    try:
                        self.data[column] = self.data[column].astype(dtype)
                    except ValueError:
                        # The column type could not be updated
                        pass

    def exists(self) -> bool:
        """
        Check if the file exists.

        Returns:
            bool: True if the file exists, False otherwise
        """
        return self.path.exists()

    def is_readable(self) -> bool:
        """
        Check if the file is readable.

        Returns:
            bool: True if the file is readable, False otherwise
        """
        return os.access(self.path, os.R_OK)

    def is_writable(self) -> bool:
        """
        Check if the file is writable.

        Returns:
            bool: True if the file is writable, False otherwise
        """
        return os.access(self.path, os.W_OK)

    def load(
        self,
        filepath: str | _Path = None,
        format: TabularFormat = None,
        name: str = None,
    ) -> None:
        """
        Load the file intelligently based on its format
        """
        if filepath is None:
            filepath = self.path
        if format is None:
            format = self.format
        if name is None:
            name = self.name

        # If the file doesn't exist, create it
        if not self.path or not self.path.exists():
            self.data = _pd.DataFrame(columns=self._default_columns)
            return

        if format == TabularFormat.CSV:
            self.data = _pd.read_csv(filepath)
        elif format == TabularFormat.TSV:
            self.data = _pd.read_csv(filepath, sep="\t")
        elif format == TabularFormat.SQLITE:
            with _sqlite3.connect(filepath) as conn:
                # A name is required to load a table from a sqlite database
                if name is None:
                    # Fetch the list of table names
                    tables = _pd.read_sql_query(
                        "SELECT name FROM sqlite_master WHERE type='table'", conn
                    )
                    raise ValueError(
                        f"Must specify a table name: {tables.name.tolist()}"
                    )
                try:
                    self.data = _pd.read_sql(f"SELECT * FROM '{name}'", conn)
                except _pd.io.sql.DatabaseError:
                    self.data = _pd.DataFrame(columns=self._default_columns)
            # If the first column is an index, use it
            if self.data.columns[0] == "index":
                self.data.set_index("index", inplace=True)
                self.data.index.name = None
        elif format == TabularFormat.XML:
            self.data = _pd.read_xml(filepath)
        elif format == TabularFormat.XLSX:
            self.data = _pd.read_excel(filepath)
        elif format == TabularFormat.HTML:
            self.data = _pd.read_html(filepath)
        elif format == TabularFormat.JSON:
            self.data = _pd.read_json(filepath)

        # If the first column is an unnamed index, use it as the index
        if self.data.columns[0] == "Unnamed: 0":
            self.data.set_index("Unnamed: 0", inplace=True)
            self.data.index.name = None

    def save(
        self,
        filepath: str | _Path = None,
        format: str | TabularFormat = None,
        name: str = None,
        overwrite: bool = False,
        **kwargs: str,
    ) -> None:
        """
        Write the current data to disk

        Args:
            filepath (str | _Path, optional): The path to the save file
            format (str | TabularFormat, optional): The format to save the file as
            name (str, optional): The name of the table to save to a sqlite database
            **kwargs: Additional keyword arguments to pass to the save function

        Raises:
            ValueError: If the format is not supported
        """
        if filepath is None:
            if self.path is None:
                raise ValueError("No output file specified")
            filepath = self.path
        elif self.outfile is None:
            # If the outfile has not yet been set, set it now
            self.outfile = filepath
        if format is None:
            if self.format is None:
                raise ValueError("No output format specified")
            format = self.format
        elif isinstance(format, str):
            format = getattr(TabularFormat, format.upper(), None)
        if name is None:
            name = self.name

        if format == TabularFormat.CSV:
            self.data.to_csv(filepath, **kwargs)
        elif format == TabularFormat.SQLITE:
            with _sqlite3.connect(filepath) as conn:
                # Determine if the table already exists
                cur: _Cursor = conn.cursor()
                cur.execute(
                    "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
                    (name,),
                )
                if cur.fetchone() is not None:
                    if overwrite:
                        cur.execute("DROP TABLE ?", (name,))
                    else:
                        raise ValueError(f"Table '{name}' already exists")
                self.data.to_sql(name, conn, **kwargs)
        elif format == TabularFormat.XML:
            self.data.to_xml(filepath, **kwargs)
        elif format == TabularFormat.XLSX:
            self.data.to_excel(filepath, **kwargs)
        elif format == TabularFormat.HTML:
            self.data.to_html(filepath, **kwargs)
        elif format == TabularFormat.JSON:
            self.data.to_json(filepath, **kwargs)
        else:
            raise ValueError(f"Unsupported format '{format}'")

    def add(
        self, *args: dict[str, object] | list[dict[str, object]], **kwargs: str
    ) -> _DataFrame:
        """
        Add a row to the table

        Args:
            *args: A list of dictionaries
            **kwargs (str): Key/value pairs to insert into the row

        Returns:
            _DataFrame: The new row(s)
        """
        df: _DataFrame = self._to_df(*args, **kwargs)
        self.data = _pd.concat([self.data, df], ignore_index=True)
        return self.data[-len(df) :]

    def pop(self, where: str | int | list[str | int]) -> _DataFrame:
        """
        Remove rows from the table and return them.

        Args:
            where (str | int | list[str | int]): One or more pandas queries or row
                indices to match

        Returns:
            _DataFrame: The removed rows
        """
        if isinstance(where, (str, int)):
            where = [where]

        # Create an empty dataframe to hold the removed rows
        match_df: _DataFrame = _pd.DataFrame(columns=self.data.columns)

        # Iterate over the list of queries
        for w in where:
            if isinstance(w, int):
                # If the query is an integer, use it as a row index
                match_df = _pd.concat([match_df, self.data.iloc[w].to_frame().T])
            else:
                # Otherwise, use it as a pandas query
                match_df = _pd.concat([match_df, self.data.query(w)])

        # Remove the matched rows from the table
        self.data = self.data.drop(match_df.index)

        # Return the matched rows
        return match_df

    def remove(self, where: str | int | list[str | int]) -> None:
        """
        Remove rows from the table

        Args:
            where (str | int | list[str | int]): One or more pandas queries or row
                indices to match
        """
        # Remove all rows where "where" is true
        self.pop(where)

    def update(self, where: str | int | list[str | int], *args, **kwargs) -> _Series:
        """
        Update all rows in the table which match the condition.

        Args:
            where (str | int | list[str | int]): One or more pandas queries or row
                indices to match
            *args (dict): A dictionary of key/value pairs to update
            *args (Callable): A function to apply to each row that matches the condition
            **kwargs (str): Key/value pairs to update in the row

        Examples:
            >>> table.update("name == 'John'", age=30)
            >>> table.update("name == 'John'", lambda row: row.age + 1)
            >>> table.update([0, 1], age=30)
            >>> table.update([0, 1], lambda row: row.age + 1)
            >>> table.update([0, 1], {"age": 30})

        Returns:
            _Series: The updated rows
        """
        # Determine if we should use a function to update the row(s)
        func: _Callable = None
        if len(args) == 1 and isinstance(args[0], dict):
            kwargs = args[0]
        elif len(args) == 1 and callable(args[0]):
            func = args[0]
        elif len(kwargs) == 0:
            raise ValueError("No update methods specified")

        # Find all rows where "where" is true
        if isinstance(where, (str, int)):
            where = [where]

        original_df: _DataFrame = self.data
        match_df: _DataFrame = _pd.DataFrame()

        for loc in where:
            if isinstance(loc, int):
                # If the location is an integer, use it as a row index
                match_df = _pd.concat([match_df, self.data.iloc[loc].to_frame().T])
            else:
                # Otherwise, use it as a query
                match_df = _pd.concat([match_df, original_df.query(loc)])
            original_df = original_df.drop(match_df.index)

        # Get the index of the matched row
        match_indices: _ndarray = match_df.index.values

        # Loop through each matched row
        for match_index in match_indices:
            if func is not None:
                # Update the row with the function
                self.data.iloc[match_index] = func(self.data.iloc[match_index])
            else:
                # Loop over each key/value pair and update the row
                for key, value in kwargs.items():
                    self.data.at[match_index, key] = value

        # Return the updated rows
        return self.data.iloc[match_indices]

    def get(
        self,
        row: int | list[int] = None,
        column: str | int | list[str | int] = None,
        where: str = None,
        as_type: type | str | _dtype = None,
        default: object = None,
    ) -> _Series | _DataFrame | object:
        """
        Get a Series, DataFrame, or value from the table

        Args:
            column (str | int | list[str | int], optional): The column(s) to get
            row (int, optional): The row to get
            where (str, optional): The pandas query to match rows to get

        Returns:
            object: The value of the cell
        """
        match_df: _DataFrame = self.data

        # If a row is specified, get the row
        if row is not None:
            if isinstance(row, int):
                row = [row]
            match_df = match_df.iloc[row]

        # If a column is specified, limit the columns
        if column is not None:
            if isinstance(column, (str, int)):
                column = [column]
            # If any of the columns are integers, convert them to strings
            for i in range(len(column)):
                if isinstance(column[i], int):
                    column[i] = match_df.columns[i]
            match_df = match_df[column]

        # If a query is specified, limit the rows to those that match
        if where is not None:
            match_df = match_df.query(where)

        # If the result is empty and a default value is specified, return the default
        if match_df.size == 0 and default is not None:
            return default

        # Form the response based on the number of rows and columns and the type
        response: _Series | _DataFrame | object

        if len(match_df) == 1 and as_type != _DataFrame:
            # If there is only one row, return a Series
            response = match_df.iloc[0]
        elif len(match_df.columns) == 1 and as_type != _DataFrame:
            # If there is only one column, return a Series
            response = match_df.iloc[:, 0]
        else:
            # Otherwise, return a DataFrame
            response = match_df

        # If a type is specified, convert the response to that type
        if as_type in [list, tuple, set]:
            response = response.values.tolist()
            if as_type == tuple:
                response = tuple(response)
            elif as_type == set:
                response = set(response)
        elif as_type is dict:
            response = response.to_dict()
        elif as_type is _Series:
            if len(response) > 1 and len(response.columns) > 1:
                raise ValueError(
                    f"Cannot convert {'%ix%i' % response.shape} DataFrame to Series"
                )
        elif as_type in [int, float, str, bool]:
            if len(match_df) > 1 or len(match_df.columns) > 1:
                raise ValueError(
                    f"Cannot convert {'%ix%i' % match_df.shape} DataFrame to {as_type}"
                )
            # Try to set the response to the value of the cell converted to the type
            cell_value: object = response.values[0]
            try:
                response = as_type(response.values[0])
            except ValueError:
                raise ValueError(
                    f"Cannot convert '{cell_value}' to {as_type}"
                ) from None
        else:
            response = response.astype(as_type)

        return response


def run(**kwargs: object) -> None:
    """
    Run the main function

    Args:
        **kwargs: Keyword arguments to pass to the ArgumentParser
    """
    import sys
    from argparse import ArgumentParser, _ArgumentGroup as ArgumentGroup

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

    parser: ArgumentParser = ArgumentParser(description="Tabular data management")
    action_group: ArgumentGroup = parser.add_argument_group("action")
    # Treat the first positional argument as the file path
    parser.add_argument("path", type=_Path, help="Path to the timesheet file")
    parser.add_argument("-F", "--format", type=str, help="Format of the file")
    action_group.add_argument(
        "-U",
        "--update",
        dest="action",
        action="store_const",
        const="update",
        help="update an existing row",
    )
    action_group.add_argument(
        "-A",
        "--add",
        dest="action",
        action="store_const",
        const="add",
        help="add a new row",
    )
    action_group.add_argument(
        "-D",
        "--delete",
        dest="action",
        action="store_const",
        const="delete",
        help="delete rows or columns",
    )
    action_group.add_argument(
        "-L",
        "--list",
        dest="action",
        action="store_const",
        const="list",
        help="list existing entries",
    )
    action_group.add_argument(
        "-I",
        "--interact",
        dest="action",
        action="store_const",
        const="interact",
        help="start an interactive prompt",
    )
    action_group.add_argument(
        "-C",
        "--copy",
        dest="action",
        action="store_const",
        const="copy",
        help="copy a row to the end of the table",
    )
    parser.add_argument(
        "-c",
        "--col",
        action="append",
        default=[],
        help="a column name or key=value pair",
    )
    parser.add_argument(
        "-r", "--row", action="append", type=int, default=[], help="a row index"
    )
    parser.add_argument(
        "-w",
        "--where",
        action="append",
        type=str,
        default=[],
        help="pandas query for filtering",
    )
    parser.add_argument(
        "-e",
        "--eval",
        action="append",
        type=str,
        default=[],
        help="evaluate a query",
    )
    parser.add_argument(
        "-n", "--name", type=str, default=None, help="sheet or table name"
    )
    parser.add_argument(
        "-o",
        "--overwrite",
        action="store_true",
        help="overwrite existing file or table",
    )
    parser.set_defaults(action="list")
    args = parser.parse_args()

    # If kwargs were passed in, update the args. Passed in kwargs take precedence over
    # command line arguments.
    if kwargs:
        args.__dict__.update(kwargs)

    tf = TableFile(args.path, name=args.name, format=args.format)

    # If the file is not readable, load it, but print a warning
    if not tf.is_readable:
        print(f"WARNING: '{tf.path}' is not readable", file=sys.stderr)

    # Convert the field arguments to a list of names and a dictionary of key/value pairs
    field_names: list[str] = []
    field_values: dict[str, str | None] = {}
    for field in args.col:
        if "=" in field:
            key, value = field.split("=", 1)
            field_values[key] = value
            field_names.append(key)
        else:
            field_values[field] = None
            field_names.append(field)

    # print(f"{args=}")
    # print(f"{field_values=}")
    # Action: Update
    if args.action == "update":
        if args.row and args.where:
            print(
                "error: Cannot specify both a row and a where clause", file=sys.stderr
            )
            sys.exit(1)
        else:
            location: list[str] | list[int] = args.row or args.where
        print(tf.update(location, field_values))
        tf.save(name=args.name, overwrite=args.overwrite)
    elif args.action == "add":
        print(tf.add(field_values))
        tf.save(name=args.name, overwrite=args.overwrite)
    elif args.action == "delete":
        # If fields are provided, drop those columns
        if field_names:
            # Print the columns to be dropped
            print(tf.data[field_names])
            tf.data.drop(columns=field_names, inplace=True)
        # If rows or queries are provided, drop those rows
        if args.row or args.where:
            print(tf.pop(args.row + args.where))
        tf.save(name=args.name, overwrite=args.overwrite)
    elif args.action == "copy":
        # Ensure that a row or query is provided
        if not args.row and not args.where:
            print("error: Must specify a row or where clause", file=sys.stderr)
            sys.exit(1)
        copy_df: _DataFrame = tf.get(args.row + args.where)
    elif args.action == "list":
        df: _DataFrame = tf.data
        if field_names:
            # Limit the columns to the specified fields
            df = df[field_names]
        for query in args.where:
            df = df.query(query)
        for stmt in args.eval:
            df = df.eval(stmt)
        if args.row:
            df = df.iloc[args.row]
        print(df)
    elif args.action == "interact":
        import code

        # Setup tab completion, persistent history, and a colorized prompt
        try:
            import readline
        except ImportError:
            pass
        else:
            import atexit
            import os
            import rlcompleter

            hist_path: str = os.path.expanduser("~/.tabular_data_history")
            try:
                readline.read_history_file(hist_path)
            except FileNotFoundError:
                pass
            atexit.register(readline.write_history_file, hist_path)
            readline.set_completer(rlcompleter.Completer(locals()).complete)
            readline.parse_and_bind("tab: complete")
        code.interact(
            banner=f"tf: {tf}\ndf: DataFrame(tf.data)",
            exitmsg="",
            local={
                "df": tf.data,
                "tf": tf,
                "pd": __import__("pandas"),
                "np": __import__("numpy"),
            },
            readfunc=lambda prompt: input(f"\x1b[1;32m{prompt}\x1b[0m"),
        )


if __name__ == "__main__":
    run()
