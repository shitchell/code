#!/usr/bin/env python3
"""Run commands with Windows administrator privileges from WSL.

Supports a persistent daemon mode: the first invocation triggers a UAC prompt
and starts a long-lived elevated process. Subsequent invocations within the
timeout window connect to the existing daemon without additional UAC prompts.

Environment variables:
    WSL_SUDO_TIMEOUT    Daemon inactivity timeout in seconds (default: 900)
    ELEVATED_SHELL      Set to '1' inside elevated processes -- nested
                        wsl-sudo calls exec the command directly
"""
from __future__ import annotations

import argparse
import fcntl
import json
import os
import pickle
import pty
import select
import signal
import socket
import struct
import subprocess
import sys
import tempfile
import time
import traceback
import tty
from contextlib import ExitStack, closing, contextmanager
from typing import Optional, Tuple

import termios

# -- Protocol commands -----------------------------------------------------

CMD_STDIN = 1
CMD_STDOUT = 2
CMD_STDERR = 3
CMD_WINSZ = 4
CMD_RETURN = 5

# -- Daemon configuration -------------------------------------------------

DAEMON_TIMEOUT_SECONDS = int(os.environ.get('WSL_SUDO_TIMEOUT', '900'))
DAEMON_STARTUP_TIMEOUT_SECONDS = 10
DAEMON_POLL_INTERVAL_SECONDS = 0.2

# -- Exit codes for timeout -----------------------------------------------

EXIT_TIMEOUT = 124  # Matches GNU timeout(1) convention


# =========================================================================
#  Session file management
# =========================================================================

def get_session_dir() -> str:
    """Return the directory for storing the daemon session file."""
    # Prefer /run/user/<uid> (tmpfs, auto-cleaned on reboot)
    run_dir = f"/run/user/{os.getuid()}"
    if os.path.isdir(run_dir):
        return os.path.join(run_dir, "wsl-sudo")
    return f"/tmp/wsl-sudo-{os.getuid()}"


def get_session_path() -> str:
    return os.path.join(get_session_dir(), "session.json")


def write_session(port: int, token: bytes) -> None:
    """Write daemon session info.  Readable only by the current user."""
    session_dir = get_session_dir()
    os.makedirs(session_dir, mode=0o700, exist_ok=True)
    path = get_session_path()
    data = json.dumps({"port": port, "token": token.hex(), "pid": os.getpid()})
    # Atomic write: temp file -> rename
    tmp_path = path + ".tmp"
    fd = os.open(tmp_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    try:
        os.write(fd, data.encode())
    finally:
        os.close(fd)
    os.rename(tmp_path, path)


def read_session() -> Optional[Tuple[int, bytes, int]]:
    """Read daemon session info.  Returns (port, token, pid) or None."""
    path = get_session_path()
    try:
        fd = os.open(path, os.O_RDONLY)
        try:
            raw = os.read(fd, 4096)
        finally:
            os.close(fd)
        info = json.loads(raw)
        return info["port"], bytes.fromhex(info["token"]), info["pid"]
    except (OSError, KeyError, json.JSONDecodeError, ValueError):
        return None


def cleanup_session() -> None:
    """Remove the session file (best-effort)."""
    try:
        os.unlink(get_session_path())
    except OSError:
        pass


# =========================================================================
#  Daemon lifecycle helpers
# =========================================================================

def is_wsl_sudo_daemon(pid: int) -> bool:
    """Check whether a PID belongs to a wsl-sudo daemon (not a reused PID)."""
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            cmdline = f.read()
        return b"wsl-sudo" in cmdline and b"--daemon" in cmdline
    except OSError:
        return False


def kill_daemon() -> None:
    """Terminate the running daemon and clean up the session file."""
    session = read_session()
    if session is None:
        print("wsl-sudo: no daemon running")
        return

    _port, _token, pid = session

    if not is_wsl_sudo_daemon(pid):
        print("wsl-sudo: stale session (daemon already exited)")
        cleanup_session()
        return

    try:
        os.kill(pid, signal.SIGTERM)
        print(f"wsl-sudo: daemon (pid {pid}) terminated")
    except ProcessLookupError:
        print("wsl-sudo: daemon was not running (stale session)")
    cleanup_session()


def ensure_daemon(visibility: int) -> Optional[Tuple[int, bytes]]:
    """Make sure a daemon is running.  Returns (port, token) or None.

    If a daemon is already running, returns its info.  Otherwise starts a
    new one via UAC (which may show a dialog) and waits for it to be ready.
    """
    # Check for existing daemon
    session = read_session()
    if session is not None:
        port, token, pid = session
        sock = UnprivilegedClient.try_connect(port)
        if sock is not None:
            sock.close()
            return port, token
        cleanup_session()

    # Start a new daemon
    cleanup_session()
    window_style = ['Hidden', 'Minimized', 'Normal'][visibility]
    try:
        subprocess.check_call(
            ["powershell.exe", "Start-Process", "-Verb", "runas",
             "-WindowStyle", window_style,
             "-FilePath", "wsl", "-ArgumentList",
             '"{}"'.format(subprocess.list2cmdline([
                 sys.executable, os.path.abspath(__file__),
                 '--daemon',
                 'visible' if visibility else 'hidden']))])
    except subprocess.CalledProcessError:
        print("wsl-sudo: failed to start elevated daemon", file=sys.stderr)
        return None

    # Poll for session file
    deadline = time.monotonic() + DAEMON_STARTUP_TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        session = read_session()
        if session is not None:
            port, token, _pid = session
            sock = UnprivilegedClient.try_connect(port)
            if sock is not None:
                sock.close()
                return port, token
        time.sleep(DAEMON_POLL_INTERVAL_SECONDS)

    print("wsl-sudo: timed out waiting for daemon to start", file=sys.stderr)
    return None


# =========================================================================
#  Low-level helpers
# =========================================================================

class PartialRead(Exception):
    pass


class MessageChannel:
    """Length-prefixed message protocol over a TCP socket."""

    def __init__(self, sock: socket.socket):
        self.sock = sock

    def recv_n(self, n: int) -> bytes:
        d: list[bytes] = []
        while n > 0:
            s = self.sock.recv(n)
            if not s:
                break
            d.append(s)
            n -= len(s)
        if n > 0:
            raise PartialRead('EOF while reading')
        return b''.join(d)

    def recv_message(self) -> bytes:
        length = struct.unpack('I', self.recv_n(4))[0]
        return self.recv_n(length)

    def recv_object(self):
        return pickle.loads(self.recv_message())

    def recv_command(self) -> Tuple[int, bytes]:
        """Returns (cmd_type, data)."""
        message = self.recv_message()
        return struct.unpack('I', message[:4])[0], message[4:]

    def send_message(self, data: bytes) -> None:
        length = len(data)
        self.sock.send(struct.pack('I', length))
        self.sock.send(data)

    def send_object(self, obj) -> None:
        self.send_message(pickle.dumps(obj))

    def send_command(self, cmd: int, data: bytes) -> None:
        self.send_message(struct.pack('I', cmd) + data)


# =========================================================================
#  Elevated side: runs commands with administrator privileges
# =========================================================================

class ElevatedServer:
    """Handles running a single command over an authenticated socket.

    Public entry points:
        one_shot_main(argv)  -- legacy one-shot mode (--elevated)
        handle_command()     -- run one command on an already-authenticated
                                socket stored in self.sock / self.channel
    """

    # -- Shared command execution ------------------------------------------

    def handle_command(self) -> None:
        """Receive a command over self.channel, execute it, relay I/O,
        and send the exit code back to the client."""
        child_argv = self.channel.recv_object()
        child_cwd = self.channel.recv_object()
        child_winsize = self.channel.recv_message()
        child_pty_flags = self.channel.recv_object()
        child_env = self.channel.recv_object()

        print("> " + b" ".join(child_argv).decode())

        child_pid, child_fds = self.pty_fork(child_pty_flags)
        if child_pid == 0:
            self.child_process(child_argv, child_cwd, child_winsize, child_env)
        else:
            self.child_pid = child_pid
            self.child_fds = child_fds
            self.relay_and_wait()

    def relay_and_wait(self) -> None:
        """Relay I/O between socket and child PTY, then send exit code."""
        self.transfer_loop()
        for fd in set(self.child_fds):
            os.close(fd)

        print('pty closed, getting return value')
        (_, exit_status) = os.waitpid(self.child_pid, 0)
        if not os.WIFEXITED(exit_status):
            return_code = 1
            print('process did not shut down normally, no return value')
        else:
            return_code = os.WEXITSTATUS(exit_status)
            print('process finished with return value', return_code)
        self.channel.send_command(CMD_RETURN, struct.pack('i', return_code))
        self.sock.shutdown(socket.SHUT_WR)

    # -- One-shot mode (legacy --elevated) ---------------------------------

    def one_shot_main(self, argv: list[str]) -> None:
        try:
            port = int(argv[1])
            password_file = argv[2]
            with open(password_file, 'rb') as f:
                password = f.read()

            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            with closing(self.sock):
                self.sock.connect(('127.0.0.1', port))
                self.channel = MessageChannel(self.sock)
                received_password = self.channel.recv_message()
                if received_password != password:
                    print("ERROR: invalid password")
                    sys.exit(1)

                print("Elevated sudo server running:")
                self.handle_command()
        except Exception:
            if argv[0] == "visible":
                print("\nSudo server crashed:")
                traceback.print_exc()
                time.sleep(10)
                sys.exit(1)

    # -- Child process setup -----------------------------------------------

    def child_process(self, argv, cwd, winsize, envdict) -> None:
        try:
            os.chdir(cwd)
            if os.isatty(0):
                fcntl.ioctl(0, termios.TIOCSWINSZ, winsize)
            envdict[b'ELEVATED_SHELL'] = b'1'
            if b'WSL_INTEROP' in os.environb:
                envdict[b'WSL_INTEROP'] = os.environb[b'WSL_INTEROP']
            try:
                os.execvpe(argv[0], argv, envdict)
            except FileNotFoundError:
                print("wsl-sudo: {}: command not found".format(
                    os.fsdecode(argv[0])))
        except BaseException:
            traceback.print_exc()
        finally:
            os._exit(1)

    # -- I/O relay ---------------------------------------------------------

    def transfer_loop(self) -> None:
        try:
            while True:
                sock_fd = self.sock.fileno()
                fdset = {*self.child_fds[1:3], sock_fd}
                for fd in select.select(fdset, (), ())[0]:
                    if fd == sock_fd:
                        cmd, data = self.channel.recv_command()
                        if cmd == CMD_STDIN:
                            os.write(self.child_fds[0], data)
                        elif cmd == CMD_WINSZ:
                            fcntl.ioctl(
                                self.child_fds[1], termios.TIOCSWINSZ, data)
                            os.kill(self.child_pid, signal.SIGWINCH)
                        else:
                            raise ValueError("Unexpected command:", cmd)
                    else:
                        chunk = os.read(fd, 8192)
                        if not chunk:
                            return
                        command = (CMD_STDOUT if fd == self.child_fds[1]
                                   else CMD_STDERR)
                        self.channel.send_command(command, chunk)
        except OSError:
            return
        except PartialRead:
            pass

    # -- PTY fork ----------------------------------------------------------

    def pty_fork(self, pty_flags):
        """Fork a child process, connecting to a new pty.

        Args:
            pty_flags: list of 3 booleans -- whether each fd (stdin, stdout,
                       stderr) should be connected to the pty.
        Returns:
            (pid, fds): fork result and a list of the child's 3 standard
            streams.  The child gets (0, None).
        """
        pipes = [os.pipe() if not is_pty else None for is_pty in pty_flags]
        if not pty_flags[0]:
            # stdin goes the other direction
            pipes[0] = tuple(reversed(pipes[0]))

        has_pty = any(pty_flags)
        if has_pty:
            pid, child_pty = pty.fork()
        else:
            pid = os.fork()

        if pid == 0:
            for i, pipe in enumerate(pipes):
                if pipe:
                    os.dup2(pipe[1], i)
            return pid, None
        else:
            for pipe in pipes:
                if pipe:
                    os.close(pipe[1])
            return pid, [pipe[0] if pipe else child_pty for pipe in pipes]


class ElevatedDaemon:
    """Long-lived elevated server that accepts multiple command connections.

    Launched via UAC on the first wsl-sudo invocation.  Stays alive for
    DAEMON_TIMEOUT_SECONDS of inactivity, allowing subsequent invocations
    to skip the UAC prompt entirely.
    """

    def main(self, argv: list[str]) -> None:
        visibility = argv[0]
        try:
            token = os.urandom(32)

            listen_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            listen_sock.setsockopt(
                socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            listen_sock.bind(('127.0.0.1', 0))
            port = listen_sock.getsockname()[1]
            listen_sock.listen(5)

            write_session(port, token)

            # Clean up the session file on SIGTERM
            signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))

            print(f"wsl-sudo daemon listening on port {port}")
            print(f"Timeout: {DAEMON_TIMEOUT_SECONDS}s of inactivity")

            try:
                self.accept_loop(listen_sock, token)
            finally:
                cleanup_session()
                listen_sock.close()

            print("wsl-sudo daemon exiting")
        except Exception:
            if visibility == "visible":
                print("\nDaemon crashed:")
                traceback.print_exc()
                time.sleep(10)
            cleanup_session()
            sys.exit(1)

    def accept_loop(
        self,
        listen_sock: socket.socket,
        token: bytes,
    ) -> None:
        """Accept client connections until the inactivity timeout expires."""
        last_activity = time.monotonic()
        active_children: set[int] = set()

        while True:
            # Reap finished children before checking timeout
            self.reap_children(active_children)

            remaining = DAEMON_TIMEOUT_SECONDS - (
                time.monotonic() - last_activity)
            if remaining <= 0:
                if active_children:
                    # Commands still running -- extend the timeout
                    print("wsl-sudo daemon: timeout reached but commands "
                          "still active, extending")
                    last_activity = time.monotonic()
                    continue
                print("wsl-sudo daemon: timed out after inactivity")
                return

            listen_sock.settimeout(remaining)
            try:
                client_sock, _ = listen_sock.accept()
            except socket.timeout:
                continue  # Re-check timeout (might have active children)

            last_activity = time.monotonic()

            pid = os.fork()
            if pid == 0:
                # Child: handle this client connection
                listen_sock.close()
                try:
                    self.handle_client(client_sock, token)
                except Exception:
                    traceback.print_exc()
                finally:
                    os._exit(0)
            else:
                # Parent: track the child, close our copy of the client socket
                client_sock.close()
                active_children.add(pid)

    def handle_client(self, sock: socket.socket, token: bytes) -> None:
        """Authenticate a client and run its command."""
        with closing(sock):
            channel = MessageChannel(sock)

            received_token = channel.recv_message()
            if received_token != token:
                print("wsl-sudo daemon: authentication failed")
                return

            print("wsl-sudo daemon: client connected")

            server = ElevatedServer()
            server.sock = sock
            server.channel = channel
            server.handle_command()

    @staticmethod
    def reap_children(active_children: set[int]) -> None:
        """Non-blocking reap of any finished child processes."""
        while True:
            try:
                pid, _ = os.waitpid(-1, os.WNOHANG)
                if pid == 0:
                    break  # Children exist but none have exited
                active_children.discard(pid)
            except ChildProcessError:
                active_children.clear()
                break  # No children at all


# =========================================================================
#  Unprivileged side: connects to the elevated server or daemon
# =========================================================================

class UnprivilegedClient:

    def __init__(self):
        self.deadline: Optional[float] = None

    def remaining_time(self) -> Optional[float]:
        """Seconds left until the deadline, or None if no deadline."""
        if self.deadline is None:
            return None
        remaining = self.deadline - time.monotonic()
        if remaining <= 0:
            print("wsl-sudo: command timed out", file=sys.stderr)
            sys.exit(EXIT_TIMEOUT)
        return remaining

    def main(
        self,
        command: list[str],
        visibility: int,
        no_daemon: bool = False,
        non_interactive: bool = False,
        timeout: Optional[float] = None,
    ) -> None:
        if timeout is not None:
            self.deadline = time.monotonic() + timeout

        command_bytes = list(map(os.fsencode, command))

        if not no_daemon:
            # Try connecting to an existing daemon
            session = read_session()
            if session is not None:
                port, token, _pid = session
                sock = self.try_connect(port)
                if sock is not None:
                    self.sock = sock
                    self.channel = MessageChannel(sock)
                    self.run(token, command_bytes)
                    return
                # Stale session file -- daemon must have died
                cleanup_session()

            if non_interactive:
                print("wsl-sudo: no daemon running and -n (non-interactive) "
                      "was specified", file=sys.stderr)
                sys.exit(1)

            # No daemon running -- start one
            if self.start_daemon_and_connect(visibility, command_bytes):
                return

            # Daemon startup failed -- fall through to one-shot mode
            print("wsl-sudo: daemon startup failed, falling back to "
                  "one-shot mode", file=sys.stderr)

        elif non_interactive:
            print("wsl-sudo: -n (non-interactive) requires daemon mode",
                  file=sys.stderr)
            sys.exit(1)

        # One-shot mode (original behavior)
        self.one_shot(command_bytes, visibility)

    def launch_uac_process(
        self,
        window_style: str,
        wsl_argv: list[str],
    ) -> Optional[subprocess.Popen]:
        """Launch an elevated process via UAC.

        Uses Popen so the caller can apply a timeout and kill the requesting
        process if needed.

        Returns the Popen object, or None if the launch failed immediately.
        """
        try:
            return subprocess.Popen(
                ["powershell.exe", "Start-Process", "-Verb", "runas",
                 "-WindowStyle", window_style,
                 "-FilePath", "wsl", "-ArgumentList",
                 '"{}"'.format(subprocess.list2cmdline(wsl_argv))])
        except OSError as exc:
            print(f"wsl-sudo: failed to start powershell: {exc}",
                  file=sys.stderr)
            return None

    def wait_for_uac(self, proc: subprocess.Popen) -> bool:
        """Wait for the UAC PowerShell process to complete.

        Respects self.deadline.  On timeout, kills the PowerShell process.
        Note: the UAC dialog (consent.exe) runs as SYSTEM and cannot be
        dismissed programmatically.  It auto-dismisses after ~2 minutes.

        Returns True if the process exited successfully (UAC accepted).
        """
        remaining = self.remaining_time()
        try:
            returncode = proc.wait(timeout=remaining)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            print("wsl-sudo: UAC dialog timed out", file=sys.stderr)
            sys.exit(EXIT_TIMEOUT)

        return returncode == 0

    def start_daemon_and_connect(
        self,
        visibility: int,
        command_bytes: list[bytes],
    ) -> bool:
        """Launch a new daemon via UAC and connect to it.

        Returns True if the command was successfully dispatched.
        """
        cleanup_session()

        window_style = ['Hidden', 'Minimized', 'Normal'][visibility]
        proc = self.launch_uac_process(window_style, [
            sys.executable, os.path.abspath(__file__),
            '--daemon', 'visible' if visibility else 'hidden'])

        if proc is None:
            return False

        if not self.wait_for_uac(proc):
            print("wsl-sudo: failed to start elevated daemon",
                  file=sys.stderr)
            return False

        # Poll for the session file (daemon writes it once ready)
        startup_timeout = DAEMON_STARTUP_TIMEOUT_SECONDS
        if self.deadline is not None:
            startup_timeout = min(startup_timeout,
                                  self.deadline - time.monotonic())
            if startup_timeout <= 0:
                print("wsl-sudo: command timed out", file=sys.stderr)
                sys.exit(EXIT_TIMEOUT)

        poll_deadline = time.monotonic() + startup_timeout
        while time.monotonic() < poll_deadline:
            session = read_session()
            if session is not None:
                port, token, _pid = session
                sock = self.try_connect(port)
                if sock is not None:
                    self.sock = sock
                    self.channel = MessageChannel(sock)
                    self.run(token, command_bytes)
                    return True
            time.sleep(DAEMON_POLL_INTERVAL_SECONDS)

        print("wsl-sudo: timed out waiting for daemon to start",
              file=sys.stderr)
        return False

    def one_shot(self, command_bytes: list[bytes], visibility: int) -> None:
        """Original one-shot mode: launch elevated server, run one command."""
        password = os.urandom(32)
        with tempfile.NamedTemporaryFile("wb") as pwf:
            pwf.write(password)
            pwf.flush()

            listen_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            listen_socket.bind(('127.0.0.1', 0))
            with closing(listen_socket):
                port = listen_socket.getsockname()[1]
                listen_socket.listen(1)

                window_style = ['Hidden', 'Minimized', 'Normal'][visibility]

                proc = self.launch_uac_process(window_style, [
                    sys.executable, os.path.abspath(__file__),
                    '--elevated', 'visible' if visibility else 'hidden',
                    str(port), pwf.name])

                if proc is None:
                    return

                if not self.wait_for_uac(proc):
                    print("wsl-sudo: failed to start elevated process")
                    return

                remaining = self.remaining_time()
                listen_socket.settimeout(
                    min(5, remaining) if remaining else 5)
                try:
                    self.sock, _ = listen_socket.accept()
                except socket.timeout:
                    print("wsl-sudo: elevated process did not connect back")
                    return
                self.channel = MessageChannel(self.sock)

            self.run(password, command_bytes)

    @staticmethod
    def try_connect(port: int) -> Optional[socket.socket]:
        """Try to connect to a daemon on the given port.

        Returns a connected socket, or None if connection failed.
        """
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(2)
            sock.connect(('127.0.0.1', port))
            sock.settimeout(None)
            return sock
        except (ConnectionRefusedError, socket.timeout, OSError):
            return None

    def run(self, password: bytes, command: list[bytes]) -> None:
        with closing(self.sock):
            self.channel.send_message(password)
            self.channel.send_object(command)
            self.channel.send_object(os.getcwd())
            self.channel.send_message(self.get_winsize())
            self.channel.send_object(
                (os.isatty(0), os.isatty(1), os.isatty(2)))
            self.channel.send_object(os.environb.copy())

            def handle_sigwinch(n, f):
                # TODO: fix race condition with normal send
                self.channel.send_command(CMD_WINSZ, self.get_winsize())

            signal.signal(signal.SIGWINCH, handle_sigwinch)

            with self.raw_term_mode():
                fdset = [0, self.sock.fileno()]
                while True:
                    # Apply command timeout to the I/O relay loop
                    remaining = self.remaining_time()
                    ready = select.select(fdset, (), (), remaining)
                    if not any(ready):
                        # select timed out -- deadline reached during I/O
                        print("\r\nwsl-sudo: command timed out",
                              file=sys.stderr)
                        sys.exit(EXIT_TIMEOUT)

                    for fd in ready[0]:
                        if fd == 0:
                            chunk = os.read(0, 8192)
                            if chunk:
                                self.channel.send_command(CMD_STDIN, chunk)
                            else:
                                # stdin is a pipe and is closed
                                fdset.remove(0)
                        else:
                            self.recv_command()

            self.sock.shutdown(socket.SHUT_WR)

    def recv_command(self) -> None:
        try:
            cmd, data = self.channel.recv_command()
        except PartialRead:
            print("wsl-sudo: Lost connection to elevated process")
            sys.exit(1)

        if cmd == CMD_STDOUT:
            os.write(1, data)
        elif cmd == CMD_STDERR:
            os.write(2, data)
        elif cmd == CMD_RETURN:
            sys.exit(struct.unpack('i', data)[0])
        else:
            raise ValueError("Unexpected message", cmd)

    @contextmanager
    def raw_term_mode(self):
        if not os.isatty(0):
            yield
        else:
            with ExitStack() as stack:
                attr = termios.tcgetattr(0)
                stack.callback(
                    termios.tcsetattr, 0, termios.TCSAFLUSH, attr)

                def sighandler(n, f):
                    stack.close()
                    sys.exit(2)

                tty.setraw(0)
                for sig in (signal.SIGINT, signal.SIGTERM):
                    signal.signal(sig, sighandler)

                yield

    @staticmethod
    def get_winsize() -> bytes:
        if not os.isatty(0):
            return struct.pack('HHHH', 24, 80, 640, 480)

        winsz = struct.pack('HHHH', 0, 0, 0, 0)
        return fcntl.ioctl(0, termios.TIOCGWINSZ, winsz)


# =========================================================================
#  Entry point
# =========================================================================

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Run a command with Windows administrator privileges")

    window_group = parser.add_mutually_exclusive_group()
    window_group.set_defaults(visibility=0)
    window_group.add_argument(
        '--minimized', action='store_const', dest='visibility', const=1,
        help="show the elevated console window as a minimized window")
    window_group.add_argument(
        '--visible', action='store_const', dest='visibility', const=2,
        help="show the elevated console window")

    parser.add_argument(
        '-k', '--reset-timestamp', action='store_true',
        help="terminate the elevation daemon (next call triggers UAC)")
    parser.add_argument(
        '-v', '--validate', action='store_true',
        help="start the daemon without running a command (pre-warm)")
    parser.add_argument(
        '-n', '--non-interactive', action='store_true',
        help="fail instead of showing UAC dialog if no daemon is running")
    parser.add_argument(
        '-s', '--shell', action='store_true',
        help="run an elevated shell (uses $SHELL, default /bin/bash)")
    parser.add_argument(
        '-T', '--command-timeout', type=float, metavar='SECONDS',
        help="total time limit for UAC dialog + command execution")
    parser.add_argument(
        '--no-daemon', action='store_true',
        help="disable daemon mode (always trigger a fresh UAC prompt)")

    # Internal flags (used when launching the elevated side)
    parser.add_argument(
        '--elevated', action='store_true', help=argparse.SUPPRESS)
    parser.add_argument(
        '--daemon', action='store_true', help=argparse.SUPPRESS)

    parser.add_argument('command', nargs=argparse.REMAINDER)

    args = parser.parse_args()

    # -- Elevated-side dispatch (internal) ---------------------------------

    if args.elevated:
        ElevatedServer().one_shot_main(args.command)
        return

    if args.daemon:
        ElevatedDaemon().main(args.command)
        return

    # -- Standalone actions (no command needed) -----------------------------

    if args.reset_timestamp:
        kill_daemon()
        return

    if args.validate:
        result = ensure_daemon(args.visibility)
        if result is None:
            sys.exit(1)
        port, _token = result
        session = read_session()
        if session:
            _, _, pid = session
            print(f"wsl-sudo: daemon running (pid {pid}, port {port})")
        return

    # -- Already elevated -- just exec directly ----------------------------

    if os.environ.get('ELEVATED_SHELL'):
        shell = os.environ.get('SHELL', '/bin/bash')
        if args.shell:
            if args.command:
                os.execvp(shell, [shell, '-c', ' '.join(args.command)])
            else:
                os.execvp(shell, [shell])
        elif args.command:
            try:
                os.execvp(args.command[0], args.command)
            except FileNotFoundError:
                print("wsl-sudo: {}: command not found".format(
                    args.command[0]), file=sys.stderr)
                sys.exit(127)
        else:
            parser.error("a command is required (or use -k, -v, -s)")
        return

    # -- Build command and dispatch to client ------------------------------

    if args.shell:
        shell = os.environ.get('SHELL', '/bin/bash')
        if args.command:
            effective_command = [shell, '-c', ' '.join(args.command)]
        else:
            effective_command = [shell]
    elif args.command:
        effective_command = args.command
    else:
        parser.error("a command is required (or use -k, -v, -s)")

    UnprivilegedClient().main(
        command=effective_command,
        visibility=args.visibility,
        no_daemon=args.no_daemon,
        non_interactive=args.non_interactive,
        timeout=args.command_timeout,
    )


if __name__ == '__main__':
    main()
