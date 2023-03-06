#!/bin/bash

# Redirect both stdout and stderr to ~/somefile.log
exec > >(tee "$HOME/somefile.log") 2>&1

# Redirect stdout to ~/somefile.out and stderr to ~/somefile.err
# exec 3>&1
# exec > >(tee "$HOME/somefile.out") 2>&3

echo "stdout: hello world"
echo "stderr: this is an error" >&2

# Redirect stdout & stderr to separate processes
{ command 2>&1 1>&3 3>&- | stderr_command; } 3>&1 1>&2 | stdout_command

function foo() { echo "some stdout" >&1; echo "some stderr" >&2; }
{ foo 2>&1 1>&3 3>&- | awk '{print "stderr: " $0}' | tee foo.err; } 3>&1 1>&2 | awk '{print "stdout: " $0}' | tee foo.out
