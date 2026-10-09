"""Private tmux terminal exerciser for interactive Common Lisp app black-box tests.

It owns a unique tmux socket, never attaches to or kills a user's tmux server.
Uses argv quoting with no interpolation of untrusted input into a shell.
"""
from __future__ import annotations

import os
import re
import shlex
import shutil
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Callable, Sequence

ROOT = Path(__file__).resolve().parents[3]


class MissingTerminalDependency(RuntimeError):
    pass


class PrivateTmuxPTY:
    def __init__(self, command: Sequence[str], *, cols: int = 100, rows: int = 35,
                 timeout: float = 9.0, cwd: Path = ROOT, env: dict | None = None):
        if not command or not all(isinstance(x, str) and x for x in command):
            raise ValueError("Nonempty command argv required")
        if min(cols, rows) <= 0:
            raise ValueError("Positive PTY geometry required")
        self.command = list(command)
        self.cols, self.rows, self.timeout = cols, rows, timeout
        self.cwd = Path(cwd).resolve()
        self.env = env
        self._temporary = None
        self.root = None
        self.socket = None
        self.screens: list[tuple[float, str]] = []

    @staticmethod
    def available():
        return shutil.which("tmux") is not None and shutil.which("stty") is not None

    def _tmux(self, *argv, timeout=None, check=True):
        if self.socket is None:
            raise RuntimeError("Terminal not started")
        result = subprocess.run(
            ["tmux", "-S", str(self.socket), *argv],
            env=self.env, text=True, capture_output=True, check=False,
            timeout=timeout or self.timeout,
        )
        if check and result.returncode:
            raise AssertionError(f"tmux {argv!r}: {result.returncode}\n{result.stderr}")
        return result

    def start(self):
        if not self.available():
            raise MissingTerminalDependency("tmux and stty required")
        if self.root is not None:
            raise RuntimeError("Already started")
        self._temporary = tempfile.TemporaryDirectory(prefix="wb-private-pty-")
        self.root = Path(self._temporary.name)
        self.socket = self.root / "isolated-tmux.sock"
        shell = self.root / "launch.sh"
        shell.write_text(
            "#!/bin/sh\n"
            "cd " + shlex.quote(str(self.cwd)) + "\n"
            "stty -g > " + shlex.quote(str(self.root / "before.stty")) + "\n"
            + shlex.join(self.command) + " 2> "
            + shlex.quote(str(self.root / "stderr.txt")) + "\n"
            "code=$?\nprintf '%s\\n' \"$code\" > "
            + shlex.quote(str(self.root / "exit-code.txt")) + "\n"
            "stty -g > " + shlex.quote(str(self.root / "after.stty")) + "\n"
            "printf '\\nWB_DRIVER_APP_EXIT:%s\\n' \"$code\"\n"
            "sleep 30\n",
            encoding="utf-8",
        )
        shell.chmod(0o700)
        self._tmux("-f", "/dev/null", "new-session", "-d", "-s", "wb",
                   "-x", str(self.cols), "-y", str(self.rows),
                   "sh " + shlex.quote(str(shell)))
        self._tmux("set-option", "-g", "status", "off")
        return self

    def capture(self):
        text = self._tmux("capture-pane", "-p", "-J", "-t", "wb:0.0").stdout
        self.screens.append((time.monotonic(), text))
        return text

    def send_text(self, value: str):
        self._tmux("send-keys", "-t", "wb:0.0", "-l", value)

    def send_key(self, name: str):
        self._tmux("send-keys", "-t", "wb:0.0", name)

    def resize(self, cols: int, rows: int):
        self.cols, self.rows = cols, rows
        self._tmux("resize-window", "-t", "wb:0", "-x", str(cols), "-y", str(rows))

    def geometry(self):
        size = self._tmux("display-message", "-p", "-t", "wb:0",
                          "#{window_width} #{window_height}").stdout.strip()
        cols, rows = map(int, size.split())
        return cols, rows

    def wait_for(self, expected: str | Callable[[str], bool], *, timeout=None):
        deadline = time.monotonic() + (timeout or self.timeout)
        predicate = (lambda snapshot: bool(re.search(expected, snapshot)))
        if callable(expected):
            predicate = expected
        last = ""
        while time.monotonic() < deadline:
            last = self.capture()
            if predicate(last):
                return last
            time.sleep(0.045)
        raise AssertionError(f"Expected {expected!r} before deadline;\nlast screen:\n{last[-3500:]}")

    def wait_for_exit(self, *, timeout=None):
        self.wait_for("WB_DRIVER_APP_EXIT:", timeout=timeout)
        code = int((self.root / "exit-code.txt").read_text().strip())
        before = (self.root / "before.stty").read_text().strip()
        after = (self.root / "after.stty").read_text().strip()
        return code, before == after

    def stop(self):
        if self.socket is not None:
            try:
                self._tmux("kill-server", check=False, timeout=5)
            except (OSError, subprocess.TimeoutExpired):
                pass
        self.socket = None
        if self._temporary is not None:
            self._temporary.cleanup()
            self._temporary = None
        self.root = None

    def __enter__(self):
        return self.start()

    def __exit__(self, *_):
        self.stop()
