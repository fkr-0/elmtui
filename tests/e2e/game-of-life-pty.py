#!/usr/bin/env python3
"""Game of Life: deterministic model + real terminal input/cleanup regression."""
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
COMMAND = [str(ROOT / "examples.sh"), "run", "game-of-life"]


def read_for(fd, seconds):
    deadline = time.monotonic() + seconds
    content = bytearray()
    while time.monotonic() < deadline:
        available, _, _ = select.select(
            [fd], [], [], min(0.05, max(0, deadline - time.monotonic()))
        )
        if available:
            try:
                data = os.read(fd, 16384)
            except OSError:
                break
            if not data:
                break
            content.extend(data)
    return bytes(content)


class GameOfLifePTY(unittest.TestCase):
    def test_glider_moves_in_four_generations(self):
        expression = (
            "(let* ((a (elmtui.examples.game-of-life:get-glider-pattern)) "
            "(b (loop repeat 4 for g = (elmtui.examples.game-of-life:next-generation a) "
            "then (elmtui.examples.game-of-life:next-generation g) "
            "finally (return g)))) "
            "(assert (= 5 (loop for y below 20 sum "
            "(loop for x below 40 count (= 1 (aref b y x)))))) "
            "(assert (= 1 (aref b 2 3))) "
            "(assert (= 1 (aref b 3 4))) "
            "(assert (= 1 (aref b 4 2))) "
            "(assert (= 1 (aref b 4 3))) "
            "(assert (= 1 (aref b 4 4))))"
        )
        proc = subprocess.run(
            ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
             "--noinform", "--non-interactive",
             "--eval", "(require :asdf)",
             "--eval", '(asdf:load-system "elmtui-examples")',
             "--eval", expression],
            cwd=ROOT, text=True, capture_output=True, timeout=60,
        )
        self.assertEqual(proc.returncode, 0, proc.stdout[-1000:] + proc.stderr[-3000:])

    def test_real_pty_animation_pause_step_quit(self):
        master, slave = pty.openpty()
        proc = None
        try:
            fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 32, 90, 0, 0))
            baseline = termios.tcgetattr(slave)

            def control_tty():
                os.setsid()
                fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

            proc = subprocess.Popen(
                COMMAND, cwd=ROOT, stdin=slave, stdout=slave, stderr=slave,
                preexec_fn=control_tty, close_fds=True,
                env={**os.environ, "TERM": "xterm-256color"},
            )
            output = bytearray()
            deadline = time.monotonic() + 20
            while time.monotonic() < deadline and b"GLIDER LAB" not in output:
                output.extend(read_for(master, 0.2))
                if proc.poll() is not None:
                    break
            self.assertIn(b"GLIDER LAB", output, bytes(output)[-3000:])
            self.assertFalse(termios.tcgetattr(slave)[3] & termios.ECHO,
                             "Kernel ECHO must be disabled for interactive keys")
            output.extend(read_for(master, 0.75))
            self.assertIn(b"GEN", output)
            os.write(master, b" ")
            output.extend(read_for(master, 0.4))
            self.assertIn(b"PAUSED", output, bytes(output)[-1800:])
            read_for(master, 0.12)
            quiet = read_for(master, 0.45)
            self.assertEqual(quiet, b"", f"paused game wrote {len(quiet)} idle bytes")
            os.write(master, b"s")
            self.assertTrue(read_for(master, 0.35), "step did not trigger a frame")
            os.write(master, b"r")
            self.assertTrue(read_for(master, 0.35), "reset did not trigger a frame")
            os.write(master, b"q")
            deadline = time.monotonic() + 6
            while proc.poll() is None and time.monotonic() < deadline:
                read_for(master, 0.15)
            self.assertIsNotNone(proc.poll(), "Quit key did not exit")
            self.assertEqual(proc.returncode, 0, "Game of Life exit code")
            self.assertEqual(termios.tcgetattr(slave)[3], baseline[3],
                             "TTY local flags must be restored")
        finally:
            if proc and proc.poll() is None:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait(timeout=5)
            os.close(master)
            os.close(slave)


if __name__ == "__main__":
    unittest.main()
