#!/usr/bin/env bash
#
# Build script for langparse module.

# Ensure `antlr4` is installed
command -v antlr4 >/dev/null 2>&1 || {
    echo 'error: `antlr4` is not found, run `pip install antlr4-tools`' >&2
    exit 1
}

# Get the langparse source directory (in case we are building out of tree)
LANGPARSE_DIR=$(dirname "${0}")

# We need to find all **/grammar/*Lexer.g4 files and **/grammar/*Parser.g4 files
# and generate the corresponding .py files. These will be placed in the parent
# directory of the grammar files, e.g.:
#   langparse/plsql/oracle_19c/grammar/PlSqlLexer.g4
#   -> langparse/plsql/oracle_19c/grammar/__build__/PlSqlLexer.interp
#   -> langparse/plsql/oracle_19c/grammar/__build__/PlSqlLexer.tokens
#   -> langparse/plsql/oracle_19c/PlSqlLexer.py

# Find all the grammar directories
shopt -s globstar
GRAMMAR_DIRS=( "${LANGPARSE_DIR}"/**/grammar )

# Antlr4 build alias
function build_g4() { antlr4 -Dlanguage=Python3 -o "." "${@}"; }

# For each grammar directory, generate the lexer, then the parser, then any
# remaining .g4 files
for GRAMMAR_DIR in "${GRAMMAR_DIRS[@]}"; do
    echo "# generating ${GRAMMAR_DIR}"
    GRAMMAR_DIR=$(realpath "${GRAMMAR_DIR}")
    (
        mkdir -p "${GRAMMAR_DIR}/__pybuild__" || {
            echo "error: failed to create build directory" >&2
            exit 1
        }
        cd "${GRAMMAR_DIR}/__pybuild__"

        # Generate the lexer
        for LEXER_PATH in "${GRAMMAR_DIR}"/*Lexer.g4; do
            LEXER_NAME=$(basename "${LEXER_PATH}")
            echo -n "  * building lexer '${LEXER_NAME}' ... "
            if ! output=$(build_g4 "${LEXER_PATH}" 2>&1); then
                echo "failed"
                echo "${output}" >&2
                exit 1
            fi
            echo "done"
        done

        # Generate the parser
        for PARSER_PATH in "${GRAMMAR_DIR}"/*Parser.g4; do
            PARSER_NAME=$(basename "${PARSER_PATH}")
            echo -n "  * building parser '${PARSER_NAME}' ... "
            if ! output=$(build_g4 "${PARSER_PATH}" 2>&1); then
                echo "failed"
                echo "${output}" >&2
                exit 1
            fi
            echo "done"
        done

        # Generate any remaining .g4 files
        for GRAMMAR_PATH in "${GRAMMAR_DIR}"/*.g4; do
            GRAMMAR_NAME=$(basename "${GRAMMAR_PATH}")
            if [[
                "${GRAMMAR_NAME}" == *Lexer.g4
                || "${GRAMMAR_NAME}" == *Parser.g4
            ]]; then
                continue
            fi
            echo -n "  * building grammar '${GRAMMAR_NAME}' ... "
            if ! output=$(build_g4 "${GRAMMAR_PATH}" 2>&1); then
                echo "failed"
                echo "${output}" >&2
                exit 1
            fi
        done

        # Move the generated files to the parent of the grammar directory
        mv *.py "${GRAMMAR_DIR}/.."
    )
done