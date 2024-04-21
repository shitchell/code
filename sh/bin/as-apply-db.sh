#!/usr/bin/env bash
#
# This script will be used to apply database changes to an AssetSuite
# environment.

## usage functions #############################################################
################################################################################

function help-epilogue() {
    echo "apply database changes to an AssetSuite environment"
}

function help-full() {
    help-usage
    help-epilogue
    echo
    echo "This script will be used to apply database changes to an AssetSuite"
    echo "environment. It requires \`sqlplus\` to be installed and available on"
    echo "the PATH."
    echo
    echo "If a password is required, it must be set using the AS_DB_PASSWORD"
    echo "environment variable."
    echo
    echo "Options:"
    cat << EOF
    -h/--help               display this help message
    -H/--host <host>        the database host, defaults to localhost
    -P/--port <port>        the database port, defaults to 1521
    -S/--schema <schema>    the database schema to connect to
    -U/--username <user>    the database username to use
EOF
    echo
    echo "Environment Variables:"
    cat << EOF
    AS_DB_HOST              the database host, defaults to localhost
    AS_DB_PORT              the database port, defaults to 1521
    AS_DB_SCHEMA            the database schema to connect to
    AS_DB_USERNAME          the database username to use
    AS_DB_PASSWORD          the database password to use
EOF
}

function parse-args() {
    # Default values
    DB_HOST="${AS_DB_HOST:-localhost}"
    DB_PORT="${AS_DB_PORT:-1521}"
    DB_SCHEMA="${AS_DB_SCHEMA}"
    DB_PASSWORD="${AS_DB_PASSWORD}"
    DB_USERNAME="${AS_DB_USERNAME}"
    FILELIST_PATH="./db-files.txt"

    # Loop over the arguments
    while [ ${#} -gt 0 ]; do
        case "${1}" in
            -h)
                help-usage
                help-epilogue
                exit 0
                ;;
            --help)
                help-full
                exit 0
                ;;
            -H | --host)
                DB_HOST="${2}"
                shift 2
                ;;
            -P | --port)
                DB_PORT="${2}"
                shift 2
                ;;
            -S | --schema)
                DB_SCHEMA="${2}"
                shift 2
                ;;
            -U | --username)
                DB_USERNAME="${2}"
                shift 2
                ;;
            -f | --file-list)
                FILELIST_PATH="${2}"
                shift 2
                ;;
            -*)
                echo-error "unknown option: ${1}"
                help-usage
                exit 1
                ;;
        esac
    done
}

function help-usage() {
    echo "usage: $(basename "${0}") [-h] [-H <host>] [-P <port>] [-S <schema>] [-U <user>] [-f <file-list>]"
}


## helpful functions ###########################################################
################################################################################

function echo-stderr() {
    echo -e "\e[31m${@}\e[0m" >&2
}

function echo-error() {
    echo-stderr "error: ${@}"
}


## main ########################################################################
################################################################################

function main() {
    parse-args "${@}"

    # Do stuff...
}


## run #########################################################################
################################################################################

[ "${BASH_SOURCE[0]}" != "${0}" ] || main "${@}"
