#!/usr/bin/env python3
"""Real PTY checks for the two rainbow demos at standard terminal sizes."""
import fcntl
import os
import pty
import re
import select
import signal
import struct
import subprocess
import termios
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TRUECOLOR = re.compile(rb"\x1b\[(?:38|48);2;\d+;\d+;\d+m")
INDEXED = re.compile(rb"\x1b\[(?:38|48);5;\d+m")


def receive(fd, seconds):
    deadline = time.monotonic() + seconds
    output = bytearray()
    while time.monotonic() < deadline:
        readable, _, _ = select.select([fd], [], [], min(.075, max(0, deadline - time.monotonic())))
        if readable:
            try:
                chunk = os.read(fd, 8192)
            except OSError:
                break
            if not chunk:
                break
            output.extend(chunk)
    return bytes(output)


class RainbowPTY(unittest.TestCase):
    def exercise(self, name, title, columns, rows):
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", rows, columns, 0, 0))
        original = termios.tcgetattr(slave)
        process = subprocess.Popen(
            [str(ROOT / "scripts/examples.sh"), "run", name],
            cwd=ROOT, stdin=slave, stdout=slave, stderr=slave,
            start_new_session=True,
            env={**os.environ, "TERM": "xterm-256color", "COLORTERM": "truecolor"},
        )
        try:
            output = bytearray()
            deadline = time.monotonic() + 20
            while time.monotonic() < deadline and title not in output and process.poll() is None:
                output.extend(receive(master, .15))
            self.assertIn(title, output, f"{name}: startup failed: {output[-1200:]!r}")
            output.extend(receive(master, .3))
            self.assertTrue(TRUECOLOR.search(output) or INDEXED.search(output),
                            f"{name}: no colored SGR emitted")
            if name == "mini-rainbow":
                self.assertTrue(b"\xe2\x94\x8c" in output or b"\xe2\x94\x8f" in output or
                                b"+" in output, "mini border missing")
            # Changing the terminal size must not terminate the application.
            resized = (100, 30) if (columns, rows) == (80, 24) else (80, 24)
            fcntl.ioctl(slave, termios.TIOCSWINSZ,
                        struct.pack("HHHH", resized[1], resized[0], 0, 0))
            os.kill(process.pid, signal.SIGWINCH)
            output.extend(receive(master, .4))
            self.assertIsNone(process.poll(), "unexpected exit on resize")
            # No periodic state changes should repaint the display while idle.
            self.assertEqual(receive(master, .5), b"", "idle output detected")
            os.write(master, b"q")
            deadline = time.monotonic() + 7
            while process.poll() is None and time.monotonic() < deadline:
                receive(master, .12)
            self.assertEqual(process.poll(), 0, "quit did not restore shell")
            self.assertEqual(termios.tcgetattr(slave), original, "terminal state not restored")
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=2)
            os.close(master)
            os.close(slave)

    def test_both_examples_at_two_sizes(self):
        for columns, rows in ((80, 24), (120, 40)):
            for name, title in (("mini-rainbow", b"RAINBOW / mini"),
                                ("rainbow-app", b"CHROMATIC / 07")):
                with self.subTest(name=name, columns=columns, rows=rows):
                    self.exercise(name, title, columns, rows)


if __name__ == "__main__":
    unittest.main(verbosity=2)
