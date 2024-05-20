#!/usr/bin/env bash
: '
A list of exit codes for use in shell scripts.
'

# General

declare -xri E_SUCCESS=0
declare -xri E_ERROR=1
declare -xri E_UNKNOWN=2


# Argument parsing - 100

declare -xri E_INVALID_ARGUMENT=100
declare -xri E_MISSING_ARGUMENT=101
declare -xri E_UNKNOWN_ARGUMENT=102
declare -xri E_INVALID_OPTION=103
declare -xri E_MISSING_OPTION=104
declare -xri E_UNKNOWN_OPTION=105
declare -xri E_INVALID_VALUE=106
declare -xri E_MISSING_VALUE=107
declare -xri E_UNKNOWN_VALUE=108


# Type checking - 200

declare -xri E_INVALID_TYPE=200
declare -xri E_NOT_A_NUMBER=201
declare -xri E_NOT_A_STRING=202
declare -xri E_NOT_AN_ARRAY=203
declare -xri E_NOT_A_MAP=204
declare -xri E_NOT_A_FUNCTION=205
declare -xri E_NOT_A_FILE=206
declare -xri E_NOT_A_DIRECTORY=207
declare -xri E_NOT_A_LINK=208
declare -xri E_NOT_A_SOCKET=209
declare -xri E_NOT_A_PIPE=210
declare -xri E_NOT_A_DEVICE=211
declare -xri E_NOT_A_BLOCK_DEVICE=212
declare -xri E_NOT_A_CHARACTER_DEVICE=213
declare -xri E_NOT_A_USER=214
declare -xri E_NOT_A_GROUP=215
declare -xri E_NOT_A_DATE=216
declare -xri E_NOT_AN_IP=217
declare -xri E_NOT_A_PORT=218
declare -xri E_NOT_A_URL=219


# Filesystem - 300

declare -xri E_FILE_NOT_FOUND=300
declare -xri E_FILE_EXISTS=301
declare -xri E_PERMISSION_DENIED=302
declare -xri E_FILE_NOT_READABLE=303
declare -xri E_FILE_NOT_WRITABLE=304
declare -xri E_FILE_NOT_EXECUTABLE=305
declare -xri E_FILE_NOT_EMPTY=306


# Git - 400

declare -xri E_NOT_A_REPOSITORY=400
declare -xri E_INVALID_COMMIT=401
