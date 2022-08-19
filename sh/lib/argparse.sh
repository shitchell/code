# This module provides functions for parsing command line arguments.
# Inspired heavily by the argparse module in the Python standard library:
# https://docs.python.org/3/library/argparse.html
#
# Common options:
#   -h/--help <help text>   Help text to display for the option
#   -r/--required           Show an exception if this option/argument is not provided
#   -d/--default <value>    Default value for the option/argument
#   -n/--nargs <*|+|?|N>    Number of arguments for the argument
#                             * - zero or more arguments
#                             + - one or more arguments
#                             ? - zero or one argument
#                             N - exactly N arguments
#
# Functions:
#   add_option <short_name> <long_name> [options]
#   add_argument <short_name> <long_name> [options]
#   add_argument_group <name> <description>
#   add_positional_argument <name> [options]
#   add_usage <usage text>
#   add_epilog <epilog text>
#   add_help <help text>
#   set_prog <program name>
#   parse_args <argv>
#
# Usage:
#   source argparse.sh
#   add_option <short_name|long_name> [-r|--required] [-s|--store <var_name>] [-n|--nargs <+|*|int>] [-d|--default <value>] [-h|--help <text>]
#   add_argument <short_name|long_name> [-f|--flag] [-s|--store <var_name>] [-r|--required] [-n|--nargs <+|*|int>] [-d|--default <value>] [-c|--choices <value1,value2,...>] [--type <type>] [--help <text>]
#   add_positional <var_name> [--type <type>] [-n|--nargs <+|*|int>] [-d|--default <value>] [-c|--choices <value1,value2,...>] [-F|--follows <separator>] [-r|--required] [--help <text>]
#   parse_args <argv>
#
# Types:
#   int - integer
#   float - floating point number
#   bool - boolean ("true", "false", 0, 1)
#   string - string
#   file - file
#   dir - directory
#   path - path (file or directory)
#
# Type specific options:
#   int|float:
#     --negative-only - only allow negative values
#     --positive-only - only allow positive values
#     --min <value> - minimum value
#     --max <value> - maximum value
#   file|dir|path:
#     --exists - only allow existing files or directories
#     --no-exists - only allow non-existing files or directories
#     --readable - only allow readable files or directories
#     --writable - only allow writable files or directories
#     --executable - only allow executable files or directories
#
# Example:
#   source argparse.sh
#   add_option "-f" "--force" --default false \
#     --help "Force the operation"
#   add_option "-v" "--verbose" --default false --store verbosity \
#     --help "Verbose output"
#   add_option "-q" "--quiet" --default true --store verbosity \
#     --help "Quiet output"
#   add_argument "-f" "--file" --type array --store filepaths \
#     --help "File to operate on"
#   add_positional "filepaths" --type filepath --store command --follows "--" --default "" \
#     --help "Filepaths to operate on"

