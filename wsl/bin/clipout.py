#!/usr/bin/env python3
#
# Read the system clipboard using powershell with proper encoding

import os
import subprocess
import sys
import time

from io import StringIO, TextIOWrapper
from subprocess import Popen

## test

old_stdout = sys.stdout
old_stderr = sys.stderr
old_stdin = sys.stdin
sys.stdout = captured_stdout = StringIO()
sys.stderr = captured_stderr = StringIO()
sys.stdin = captured_stdin = StringIO()
ec = os.system("powershell.exe -command 'Get-Clipboard -Raw'")
sys.stdout = old_stdout
sys.stderr = old_stderr
sys.stdin = old_stdin
print("stdout", captured_stdout.getvalue())
print("stderr", captured_stderr.getvalue())
print("stdin", captured_stdin.getvalue())
sys.exit()

try:
    proc: Popen = subprocess.Popen(
        ["powershell.exe", "-command", "Get-Clipboard -Raw"],
        encoding="cp1252",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
except FileNotFoundError:
    print("error: powershell.exe not found", file=sys.stderr)
    sys.exit(1)

stdout: str = ""
# stdout_wrapper: TextIOWrapper = TextIOWrapper(
    # proc.stdout, encoding="cp1252"
# )
stderr: str = ""
# stderr_wrapper: TextIOWrapper = TextIOWrapper(
    # proc.stderr, encoding="cp1252"
# )


# Read all stdout
while line := proc.stdout.read():
    print(line, end="", file=sys.stdout)

# Read all stderr
while line := proc.stderr.read():
    print(line, end="", file=sys.stderr)

# Ensure it's done and get the return code
proc.poll()

# ~fin
sys.exit(proc.returncode)
