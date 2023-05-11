"""
Functions and classes for debugging.
"""
import code as _code
import inspect as _inspect
import select as _select
import sys as _sys

from typing import Callable


def ask_for_shell(
    timeout: int = 0,
    prompt: str = "Do you want to start an interactive shell? [y/N] ",
    confirm: Callable = lambda response: response.lower().startswith("y"),
    locals: dict = None,
) -> bool:
    """
    Ask the user if they want to start an interactive shell

    Returns:
        bool: _description_
    """
    print(prompt, end="")
    _sys.stdout.flush()

    try:
        if timeout:
            # If timeout is set, stop waiting for input after timeout seconds
            i, o, e = _select.select([_sys.stdin], [], [], timeout)
        else:
            # If timeout is not set, wait indefinitely for input
            i, o, e = _select.select([_sys.stdin], [], [])
    except KeyboardInterrupt:
        # If the user presses Ctrl+C, stop waiting for input
        return None

    if i:
        # If there is input, read it
        response = _sys.stdin.readline().strip()
        # Determine if the response warrants starting a shell
        if confirm(response):
            del response, i, o, e
            try:
                # If locals is not set, use the calling function's globals + locals
                if locals is None:
                    frame = _inspect.currentframe()
                    try:
                        locals = {**frame.f_back.f_globals, **frame.f_back.f_locals}
                    except AttributeError:
                        locals = {}

                # Setup tab completion, persistent history, and a colorized prompt
                try:
                    import readline
                except ImportError:
                    pass
                else:
                    import atexit
                    import os
                    import rlcompleter

                    hist_path: str = os.path.expanduser(
                        f"~/.python{_sys.version_info.major}_history"
                    )
                    try:
                        readline.read_history_file(hist_path)
                    except FileNotFoundError:
                        pass
                    atexit.register(readline.write_history_file, hist_path)
                    readline.set_completer(rlcompleter.Completer(locals).complete)
                    readline.parse_and_bind("tab: complete")
                # Start the shell
                _code.interact(
                    banner="",
                    local=locals,
                    readfunc=lambda prompt: input(f"\x1b[1;32m{prompt}\x1b[0m"),
                )
            except SystemExit:
                pass
            return True
    else:
        print("No shell for you!")
        return False


def _ask_for_shell_readfunc(prompt: str) -> str:
    """
    Read a line of input from stdin using a custom readline setup.
    """
    import os

    # Completion!
    try:
        import readline
    except ImportError:
        print("Module readline not available.")
    else:
        # persistent history
        import atexit
        import rlcompleter

        histfile = os.path.expanduser("~/.python%i_history" % _sys.version_info.major)
        try:
            readline.read_history_file(histfile)
        except IOError:
            pass
        atexit.register(readline.write_history_file, histfile)
        del histfile, atexit
        # tab completion
        readline.parse_and_bind("tab: complete")
        readline.set_completer(rlcompleter.Completer(locals).complete)
    return input(f"\033[0;32m{prompt}\033[0m")
