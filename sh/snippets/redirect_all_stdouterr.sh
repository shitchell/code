#!/bin/bash

# Redirect both stdout and stderr to ~/somefile.log
exec > >(tee "$HOME/somefile.log") 2>&1

# Redirect stdout to ~/somefile.out and stderr to ~/somefile.err
# exec 3>&1
# exec > >(tee "$HOME/somefile.out") 2>&3

echo "stdout: hello world"
echo "stderr: this is an error" >&2
