#!/usr/bin/env bash
#
# This allows for quick and dirty network connections using bash through file
# descriptors and redirection using *only* bash builtins

# Create a new virtual /dev/tcp file descriptor
exec {fd}<>/dev/tcp/example.com/80
# Send some data
echo $'GET / HTTP/1.1\nHost: example.com\nConnection: close\n\n' >&"${fd}"
# Read a response
while IFS= read -r -u ${fd} line; do printf '%s\n' "${line}"; done
# Close the file descriptor
exec {fd}>&-
