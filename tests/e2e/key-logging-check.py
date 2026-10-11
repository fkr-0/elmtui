#!/usr/bin/env python3
"""Hot-path key events must never escape through application INFO logs."""
import fcntl
import os
from pathlib import Path
import pty
import select
import signal
import struct
import subprocess
import termios
import time
import unittest


ROOT = Path(__file__).resolve().parents[2]

CASES = {
    "minimal-app": b"minimal:>",
    "key-tester": b"Rendering Key Tester App",
    "rainbow-app": b"Rainbow: RECEIVED MESSAGE",
    "mini-rainbow": b"mini-rainbow: key event",
}


def read_for(fd, seconds):
    deadline = time.monotonic() + seconds
    collected = bytearray()
    while time.monotonic() < deadline:
        r, _, _ = select.select([fd], [], [], min(.06, max(0, deadline - time.monotonic())))
        if r:
            try:
                part = os.read(fd, 32768)
            except OSError:
                break
            if not part:
                break
            collected.extend(part)
    return bytes(collected)


class LogIsolation(unittest.TestCase):
    def test_interactive_keys_do_not_emit_info_log_lines(self):
        for example, forbidden in CASES.items():
            with self.subTest(example=example):
                master, slave = pty.openpty()
                proc = None
                try:
                    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 32, 100, 0, 0))
                    baseline = termios.tcgetattr(slave)

                    def tty_child():
                        os.setsid()
                        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

                    proc = subprocess.Popen(
                        [str(ROOT / "scripts/examples.sh"), "run", example],
                        cwd=ROOT, stdin=slave, stdout=slave, stderr=slave,
                        close_fds=True, preexec_fn=tty_child,
                        env={**os.environ, "TERM": "xterm-256color"},
                    )
                    output = bytearray()
                    deadline = time.monotonic() + 16
                    while time.monotonic() < deadline:
                        output.extend(read_for(master, .16))
                        if proc.poll() is not None:
                            break
                        if not (termios.tcgetattr(slave)[3] & termios.ECHO):
                            break
                    self.assertIsNone(proc.poll(), output[-1900:])
                    self.assertFalse(termios.tcgetattr(slave)[3] & termios.ECHO,
                                     f"{example}: kernel echo not disabled")
                    read_for(master, .2)
                    os.write(master, b"x")
                    fresh = read_for(master, .5)
                    self.assertNotIn(forbidden, fresh, f"{example}: key logs reached TTY")
                    os.write(master, b"q")
                    timeout = time.monotonic() + 3
                    while proc.poll() is None and time.monotonic() < timeout:
                        read_for(master, .12)
                    if proc.poll() is not None:
                        self.assertEqual(termios.tcgetattr(slave)[3], baseline[3],
                                         f"{example}: terminal flags not restored")
                finally:
                    if proc and proc.poll() is None:
                        os.killpg(proc.pid, signal.SIGKILL)
                        proc.wait(timeout=5)
                    os.close(master)
                    os.close(slave)


if __name__ == "__main__":
    unittest.main()
