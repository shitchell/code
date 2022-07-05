# -*- encoding: utf-8 -*-

class TUI:
    import argparse

    options: argparse.Namespace
    _parser: argparse.ArgumentParser
    _history: History
    _organizer: Organizer
    _key_actions: Dict[str, str] = {
        "?": "help",
        "-": "delete",
        "\r": "preview",
        "\n": "preview",
        "\x1b[A": "up"
        # "\x1b[B": "down",
        # "\x1b[C": "right",
        # "\x1b[D": "left",
    }
    V_MAX = 6 # Only print if verbose
    V_DEF = 3 # Default verbosity
    V_MIN = 0 # Minimum required for functionality

    def __init__(self, args: List[str] = None):
        self._parse_args(args)
        self._history = History()
        self._history.load(self.options.history)
        # If skip_organized is set, filter out previously organized files
        files: List[OrganizedFile]
        if self.options.skip_organized:
            files = []
            for path in self.options.paths:
                file = OrganizedFile(path)
                if file not in self._history.files:
                    files.append(file)
        else:
            files = [OrganizedFile(x) for x in self.options.paths]
        self._organizer = Organizer(files)
        # Add loaded shortcuts to current organizer
        self._organizer.shortcuts.update(self._history.shortcuts)

    def _parse_args(self, args: List[str] = None):
        import argparse

        # Setup settings
        parser = argparse.ArgumentParser(formatter_class=argparse.RawTextHelpFormatter)
        #parser.add_argument("-r", "--recursive", help="TODO", action="store_true")
        #parser.add_argument("-d", "--depth", help="TODO", type=int, default=0)
        parser.add_argument("--history", help="TODO", default=Path.home().joinpath(".declutterpy.json"))
        parser.add_argument("-i", "--ignore-history", help="TODO", action="store_true")
        #parser.add_argument("-S", "--ignore-history-shortcuts", help="TODO", action="store_true")
        #parser.add_argument("-P", "--ignore-history-filepaths", help="TODO", action="store_true")
        #parser.add_argument("-n", "--no-save", help="TODO", action="store_true")
        parser.add_argument("-s", "--skip-setup", help="TODO", action="store_true")
        parser.add_argument("-S", "--skip-organized", help="TODO", action="store_true")
        parser.add_argument("-q", "--quiet", help="TODO", action="store_true")
        parser.add_argument("-v", "--verbose", help="TODO", action="count", default=TUI.V_DEF)
        parser.add_argument("paths", nargs="+", help="Files and directories to organize")
        parser.epilog = __doc__
        
        # Parse provided options if given, else command line options
        if args:
            self.options = parser.parse_args(args)
        else:
            self.options = parser.parse_args()

    @staticmethod
    def _shortcut_completer(text: str, state: int) -> Optional[str]:
        buffer = readline.get_line_buffer()
        line = readline.get_line_buffer().split()

        # Only autocomplete the second item
        if len(line) != 2 and not buffer.endswith(" "):
            return None

        # Get the base directory typed
        list_dir: str
        if not line or buffer.endswith(" "):
            list_dir = "."
        else:
            # Current entire filepath
            cur_path: str = os.path.expanduser(line[-1])
            list_dir = os.path.dirname(cur_path)

        # Put together the base directory, filename, and an asterisk
        term = text + "*"
        query = str(os.path.join(list_dir, term))
        files = glob(os.path.expanduser(query))
        matches = [Path(x).stem + os.path.sep for x in files if Path(x).is_dir()]
        if state < len(matches):
            return matches[state]
        else:
            return None

    def input_shortcut(self, prompt: str = "") -> Dict[str, Path]:
        """
        Input that accepts a single character followed by a filepath, eg:

        $ a /path/to/file
        
        Provides filepath completion, eg:

        $ p ~/Down<tab>
        becomes
        $ p ~/Downloads
        """
        readline.set_completer(TUI._shortcut_completer)
        readline.parse_and_bind("tab: complete")

        line: str = input(prompt)
        # Empty line given
        if not line.strip():
            raise EmptyInputException()

        parts: list = line.split(maxsplit=1)

        # Must be 2 words/parts
        if len(parts) != 2:
            raise InputFormatException()

        # Collect the parts
        char: str = parts[0]
        filepath: str = parts[1]
        path: Path = Path(filepath).expanduser()

        # Cannot use reserved keys
        if char in self._key_actions:
            raise ReservedShortcutException(char)

        # Shortcut can only be one character
        if len(char) > 1:
            raise InputFormatException()

        # Path must exist and be a directory
        if not path.is_dir():
            raise NotADirectoryError(path)

        # Directory must be writable
        if not os.access(path, os.W_OK):
            raise PermissionError(path)

        return {char: path}

    def printv(self, *args, level: int = V_DEF, **kwargs):
        """
        Prints information based on an integer verbosity level. 3 variables are
        defined to distinguish the main types of output:

        TUI.V_MAX -> Print when verbose
        TUI.V_DEF -> Default setting
        TUI.V_MIN -> Only the minimum required to function
        """
        # If quiet is set, only V_MIN is allowed
        if self.options.quiet and level != TUI.V_MIN:
            return

        if level <= self.options.verbose:
            print(*args, **kwargs)
            sys.stdout.flush()

    @staticmethod
    def getch() -> str:
        """
        Returns a single byte from stdin (not necessarily the full keycode for
        certain special keys)
        https://gist.github.com/jasonrdsouza/1901709#gistcomment-2734411
        """
        import os
        ch = ''
        if os.name == 'nt': # how it works on windows
            import msvcrt
            ch = msvcrt.getch() # type: ignore[attr-defined]
        else:
            import tty, termios, sys
            fd = sys.stdin.fileno()
            old_settings = termios.tcgetattr(fd)
            try:
                tty.setraw(sys.stdin.fileno())
                ch = sys.stdin.read(1)
            finally:
                termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        if ord(ch) == 3:
            return "" # handle ctrl+C
        return ch

    @staticmethod
    def getkey() -> str:
        """
        Returns the (full) keycode for a single keypress from standard input
        https://pypi.org/project/readchar/
        """
        c1 = TUI.getch()
        if ord(c1) != 0x1b:
            return c1
        c2 = TUI.getch()
        if ord(c2) != 0x5b:
            return c1 + c2
        c3 = TUI.getch()
        if ord(c3) != 0x33:
            return c1 + c2 + c3
        c4 = TUI.getch()
        return c1 + c2 + c3 + c4

    def _print_startup_information(self):
        self.printv()
 
    # Handle certain events / states
    def _handle_file_exists(self, ctx: dict):
        # Get a new name
        filename: str = input("Rename: ")
        destination: Optional[Path] = ctx.get("destination")

        # Create new destination with new filename
        if destination:
            if destination.is_file():
                destination = destination.parent
            ctx["destination"] = destination.joinpath(destination, filename)
        else:
            ctx["destination"] = Path(filename)

    # Interactive file organization actions
    def _get_action(self, action):
        if hasattr(self, "do_" + action):
            return getattr(self, "do_" + action)

    def do_delete(self, ctx):
        ctx.get('file').delete()

    def do_move(self, ctx):
        file: OrganizedFile = ctx.get('file')
        shortcut: Shortcut = ctx.get('shortcut')
        destination: str = shortcut.path

        # Keep trying to move the file until successful
        moved: bool = False
        # TODO
        # Handle errors either here or in the run() method. trying here for now
        file.move(destinadtion)
        return str(destination)
        while not moved:
            try:
                file.move(destination)
            except FileExistsError:
                _handle_file_exists(file, destination)
            except PermissionError:
                self.printv("")
                _handle_permission_error(file, destination)
            else:
                moved = True
                file.organized = True

    def _handle_exception(self, exception: Exception) -> str:
        e: SimpleException = SimpleException(exception)
        message: str = ""
        if self.options.verbose > TUI.V_DEF:
            message = f"[{e.name}: {e.line}] {e.reason}"
        else:
            if e.name == 'NameError':
                message = f"NameError"
        return message

    def organize_files(self):
        """
        Loop over the organizer's list of files, using keyboard commands to
        manipulate file locations
        """
        i: int = 0
        new_files: bool = False
        organized_count = 0
        self.printv("Type a shortcut key or ?:")
        for i in range(len(self._organizer.files)):
            # Never let the file index drop below 0
            if i < 0:
                i = 0

            i = True

            # Get the next file
            file: OrganizedFile = self._organizer.files[i]
            logging.info(f"organizing: {file}")
            self.printv(f"{file} -> ", end="", level=TUI.V_MIN)

            # Get a single keypress from the user
            valid_key: bool = False
            while not valid_key:
                key: str = TUI.getkey()

                action: str
                # See if there is a shortcut associated with the key
                shortcut: Shortcut = self._organizer.get_shortcut(key)
                if shortcut:
                    # If the key is a shortcut, then move the file
                    action = "move"
                else:
                    # See if the key is associated with an action
                    action = TUI._key_actions.get(key)
                logging.info("key: " + str(key.encode())[1:] + " shortcut: " + str(shortcut))

                if action:
                    action_func: Callable = self._get_action(action)
                    if action_func:
                        logging.info("action: " + str(action))
                        try:
                            res: str = str(action_func(locals())) 
                        except Exception as e:
                            message = self._handle_exception(e)
                            if message:
                                self.printv(message)
                        else:
                            valid_key = True
                            self.printv(res, level=TUI.V_MIN)
                    else:
                        # Key was defined, but has no defined "do_*" function
                        logging.info(f"Action '{action}' needs to be defined")
                else:
                    # key pressed is not associated with an action or shortcut
                    logging.info(f"")

    def run(self):
        """
        Launch a text based interface to organize files
        """
        # Startup info -> Number of files passed in and saved shortcuts
        if not self.options.skip_setup:
            self.printv("Processing {} files".format(len(self._organizer.files)))
            self.printv("")
            if len(self._history.shortcuts) > 0:
                self.printv("Loaded shortcuts:")
                for (key, path) in self._history.shortcuts.items():
                    self.printv(f"- {key}: {path}")
                self.printv("")

        # Setup shortcuts
        if not self.options.skip_setup:
            empty_or_EOF = False
            while not empty_or_EOF:
                try:
                    shortcut = self.input_shortcut("Enter a shortcut and path (empty line when done): ")
                except (EOFError, EmptyInputException):
                    empty_or_EOF = True
                except InputFormatException:
                    self.printv("Shortcut must be a single character followed by a file path, eg: d ~/Downloads")
                except InvalidPathException as e:
                    self.printv(f"{e} is not a directory")
                except PermissionError as e:
                    self.printv(f"You do not have permission to access {e}")
                else:
                    self._organizer.shortcuts.update(shortcut)

        # Start organizing files
        self.organize_files()

    # Organize files
if __name__ == '__main__':
    TUI().run()
