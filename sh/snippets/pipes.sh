#!/usr/bin/env bash
#
# Display file descriptor statuses for pipe testing
#
# Sample output:
#
# $ ./pipes.sh               # no pipe in / no pipe out
# : -t 0
# : -t 1
# : -t 2
# $ ./pipes.sh | cat         # no pipe in / pipe out
# : -t 0
# : -t 2
# : -p /dev/stdout
# $ echo | ./pipes.sh | cat  # pipe in    / pipe out
# : -t 2
# : -p /dev/stdout
# : -p /dev/stdin
# $ echo | ./pipes.sh        # pipe in    / no pipe out
# : -t 1
# : -t 2
# : -p /dev/stdin
#
# | condition          | pipe in | pipe out |
# | ------------------ | ------- | -------- |
# | [[ -t 0 ]]         | 1       | -        |
# | [[ -t 1 ]]         | -       | 1        |
# | [[ -t 2 ]]         | -       | -        |
# | [ -p /dev/stdin ]  | 0       | -        |
# | [ -p /dev/stdout ] | -       | 0        |
#
# tl;dr:
# - [[ -t 0 ]]: stdin is not available
# - [[ -t 1 ]]: not piping to another command
# - ! [[ -t 0 ]]: stdin is available
# - ! [[ -t 1 ]]: piping to another command

[[ -t 0 ]] && echo ": -t 0"
[[ -t 1 ]] && echo ": -t 1"
[[ -t 2 ]] && echo ": -t 2"
[ -p /dev/stdout ] && echo ": -p /dev/stdout"
[ -p /dev/stdin ]  && echo ": -p /dev/stdin"
