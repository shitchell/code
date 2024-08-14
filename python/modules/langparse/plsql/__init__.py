"""
ANTLR4 grammar, lexer, and parser for PL/SQL.

Supported versions:
- Oracle 11g
- Oracle 19c (WIP)
"""

from . import oracle_11g
from . import oracle_19c

# Set the latest as the default
from .oracle_19c.PlSqlLexer import PlSqlLexer, PlSqlLexerBase
from .oracle_19c.PlSqlParser import PlSqlParser, PlSqlParserBase
from .oracle_19c.PlSqlParserListener import PlSqlParserListener

__all__ = [
    "oracle_11g",
    "oracle_19c",
    "PlSqlLexer",
    "PlSqlLexerBase",
    "PlSqlParser",
    "PlSqlParserBase",
    "PlSqlParserListener",
]
