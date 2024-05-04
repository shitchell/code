#!/usr/bin/env bash

[[ -t 0 ]] && echo ": -t 0"
[[ -t 1 ]] && echo ": -t 1"
[[ -t 2 ]] && echo ": -t 2"
[ -p /dev/stdout ] && echo ": -p /dev/stdout"
[ -p /dev/stdin ]  && echo ": -p /dev/stdin"
