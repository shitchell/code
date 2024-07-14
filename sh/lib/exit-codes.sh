#!/usr/bin/env bash
: '
A list of exit codes for use in shell scripts.

Note when adding new exit codes: the possible range is 0-255.
'

# General

export E_SUCCESS=0
export E_ERROR=1
export E_UNKNOWN=2
export E_HELP_DISPLAYED=3


# 10-19 - Argument parsing

export E_INVALID_ARGUMENT=10
export E_MISSING_ARGUMENT=11
export E_UNKNOWN_ARGUMENT=12
export E_INVALID_OPTION=13
export E_MISSING_OPTION=14
export E_UNKNOWN_OPTION=15
export E_INVALID_VALUE=16
export E_MISSING_VALUE=17
export E_UNKNOWN_VALUE=18


# 20-45 - Type checking

export E_INVALID_TYPE=20
export E_NOT_A_NUMBER=21
export E_NOT_A_STRING=22
export E_NOT_AN_ARRAY=23
export E_NOT_A_MAP=24
export E_NOT_A_FUNCTION=25
export E_NOT_A_FILE=26
export E_NOT_A_DIRECTORY=27
export E_NOT_A_LINK=28
export E_NOT_A_SOCKET=29
export E_NOT_A_PIPE=30
export E_NOT_A_DEVICE=31
export E_NOT_A_BLOCK_DEVICE=32
export E_NOT_A_CHARACTER_DEVICE=33
export E_NOT_A_USER=34
export E_NOT_A_GROUP=35
export E_NOT_A_DATE=36
export E_NOT_AN_IP=37
export E_NOT_A_PORT=38
export E_NOT_A_URL=39


# 46-59 - Filesystem

export E_FILE_NOT_FOUND=46
export E_FILE_EXISTS=47
export E_PERMISSION_DENIED=48
export E_FILE_NOT_READABLE=49
export E_FILE_NOT_WRITABLE=50
export E_FILE_NOT_EXECUTABLE=51
export E_FILE_NOT_EMPTY=52


# 60-70 - Git

export E_NOT_A_REPOSITORY=60
export E_INVALID_COMMIT=61

# 80-89 - Commands / Functions

export E_COMMAND_NOT_FOUND=80
export E_FUNCTION_NOT_FOUND=81
export E_INVALID_COMMAND=82
export E_INVALID_FUNCTION=83
export E_INVALID_COMMAND_OR_FUNCTION=84

# 90-99 - Flow Control
export E_CONTINUE=90
export E_BREAK=91
export E_EXIT=92
