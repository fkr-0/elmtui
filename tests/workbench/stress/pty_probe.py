"""Raw PTY harness for real W5 output/CPU gates (not a screen fixture).

Does not manipulate host terminal, signals only its own child process group,
caps descendants/process observations, and reports unavailable CPU proof.
"""
from __future__ import annotations

import fcntl
import os
import pty
import re
import select
import signal
import subprocess
import termios
import time
from pathlib import Path


class RealPTY:
    def __init__(self, argv, cwd: Path):
        self.argv = list(argv)
        self.cwd = Path(cwd)
        self.master = self.slave = self.process = None
        self.original = None
        self.output = bytearray()

    def __enter__(self):
        if not self.argv:
            raise ValueError("Real application command required")
        self.master, self.slave = pty.openpty()
        self.original = termios.tcgetattr(self.slave)

        def child_tty():
            fcntl.ioctl(self.slave, termios.TIOCSCTTY, 0)

        try:
            self.process = subprocess.Popen(
                self.argv, cwd=self.cwd, stdin=self.slave, stdout=self.slave,
                stderr=self.slave, start_new_session=True, preexec_fn=child_tty,
                close_fds=True,
            )
        except BaseException:
            os.close(self.master)
            os.close(self.slave)
            raise
        return self

    def send(self, data: bytes):
        os.write(self.master, data)

    def drain(self, seconds: float):
        """Collect actual emitted bytes within a finite monotonic interval."""
        deadline = time.monotonic() + seconds
        data = bytearray()
        while time.monotonic() < deadline:
            remaining = deadline - time.monotonic()
            ready, _, _ = select.select([self.master], [], [], min(0.05, remaining))
            if not ready:
                continue
            try:
                chunk = os.read(self.master, 65536)
            except OSError:
                break
            if not chunk:
                break
            data.extend(chunk)
            self.output.extend(chunk)
        return bytes(data)

    def wait_for(self, pattern: str, seconds: float):
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            self.drain(min(0.12, end - time.monotonic()))
            if re.search(pattern, self.output.decode("utf-8", errors="replace"), re.I):
                return
            if self.process.poll() is not None:
                break
        raise AssertionError(f"Missing real W5 output pattern {pattern!r}; tail={bytes(self.output[-600:])!r}")

    def editor_echo_disabled(self):
        return not bool(termios.tcgetattr(self.slave)[3] & termios.ECHO)

    def sbcl_pid(self):
        """Find the actual SBCL descendant, never mistake CLPM for UI CPU."""
        if not Path("/proc").is_dir():
            return None
        candidates = [self.process.pid]
        seen = set()
        while candidates and len(seen) < 64:
            pid = candidates.pop(0)
            if pid in seen:
                continue
            seen.add(pid)
            try:
                if Path(f"/proc/{pid}/comm").read_text().strip().lower() == "sbcl":
                    return pid
                children = Path(f"/proc/{pid}/task/{pid}/children").read_text()
                candidates.extend(int(x) for x in children.split())
            except (OSError, ValueError):
                continue
        return None

    @staticmethod
    def cpu_ticks(pid):
        # /proc/$pid/stat utime + stime (14th and 15th fields).
        raw = Path(f"/proc/{pid}/stat").read_text()
        fields = raw[raw.rfind(")") + 2:].split()
        return int(fields[11]) + int(fields[12])

    def terminal_restored(self):
        return termios.tcgetattr(self.slave) == self.original

    def __exit__(self, *_):
        if self.process:
            if self.process.poll() is None:
                try:
                    os.killpg(self.process.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                try:
                    self.process.wait(timeout=1.5)
                except subprocess.TimeoutExpired:
                    try:
                        os.killpg(self.process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    self.process.wait(timeout=1.5)
            else:
                self.process.wait()
        if self.master is not None:
            os.close(self.master)
        if self.slave is not None:
            os.close(self.slave)
