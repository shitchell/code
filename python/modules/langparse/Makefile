# Build all of the language parsers
#
# Directory structure should be:
# - langparse
#   - Makefile
#   - {language}/ (e.g.: plsql)
#     - {version}/
#       - grammar/
#         - Lexer.g4
#         - Parser.g4
#
# The `all` target will loop through all of the directories and build the
# Lexer then the Parser for each version of each language. If a directory is
# prefixed with a `_` (e.g.: __pycache__ or _old), it will be skipped.
#
# Lexers and parsers will be built using `antlr4 -Dlanguage=Python3` and the
# generated files will be placed in the language version directory (e.g.:
# plsql/19c).

# Define the wildcard patterns for finding Lexer and Parser files
LEXERS := $(wildcard */*/grammar/*Lexer.g4)
PARSERS := $(wildcard */*/grammar/*Parser.g4)

# Targets
all: lexers parsers

lexers: $(LEXERS)

parsers: $(PARSERS)

# Generate the lexer files
$(LEXERS):
	@echo "Generating lexer for $@"
	antlr4 -Dlanguage=Python3 $@ -o $(dir $@)

# Generate the parser files
$(PARSERS): lexers
	@echo "Generating parser for $@"
	antlr4 -Dlanguage=Python3 $@ -o $(dir $@)

clean:
	@echo "Cleaning generated files..."
	find . -type f \( -name "*.py" -o -name "*.tokens" -o -name "*.interp" \) -exec rm -v {} \;

.PHONY: all lexers parsers clean
