import re
import ast
import sys
import readline
from io import StringIO

def insert_returns(body):
    # insert return stmt if the last expression is a expression statement
    if isinstance(body[-1], ast.Expr):
        body[-1] = ast.Return(body[-1].value)
        ast.fix_missing_locations(body[-1])

    # for if statements, we insert returns into the body and the orelse
    if isinstance(body[-1], ast.If):
        insert_returns(body[-1].body)
        insert_returns(body[-1].orelse)

    # for with blocks, again we insert returns into the body
    if isinstance(body[-1], ast.With):
        insert_returns(body[-1].body)

def format_error(e):
  return f"""  {e.text.rstrip()[1:]}
  {" "*(e.offset - 2)}^
{e.__class__.__name__}[{e.lineno - 1}:{e.offset - 1}]: {e.msg}"""

cmd = ""

first_run = True
code_level = 0
empty_line = False
input_prefix = ">>>"
while (code_level > 0 or first_run) and not empty_line:
    first_run = False

    try:
        line = input(f"{input_prefix} ")
    except EOFError:
        print("")
        break

    line = re.sub("#.*", "", line)
    if line.endswith(":"):
        code_level += 1

    cmd += line
    input_prefix = "..."

    if line == "":
        empty_line = True

# add a layer of indentation
cmd = "\n".join(f" {i}" for i in cmd.splitlines() if i != "python")

# create a function out of the given code
body = f"def _fn():\n{cmd}"

try:
    parsed = ast.parse(body)
except Exception as e:
    result = format_error(e)
else:
    body = parsed.body[0].body

insert_returns(body)

try:
    exec(compile(parsed, filename="<code>", mode="exec"))
except Exception as e:
    result = format_error(e)
else:
    old_stdout = sys.stdout
    redirected_output = sys.stdout = StringIO()
    
    try:
        result = eval("_fn()")
    except Exception as e:
        result = format_error(e)
    else:
        sys.stdout = old_stdout
        redirected_output = redirected_output.getvalue()

output = redirected_output or result
output = str(output)
if output.endswith("\n"):
    output = output[:-1]
print(output)
