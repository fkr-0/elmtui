"""Black-box self-tests: prove that the independent PTY harness truly interacts.

These are *fixture tests*, not workbench application passes.
"""
from __future__ import annotations

import sys
import unittest
from pty_driver import PrivateTmuxPTY

TTY_FIXTURE = r'''
import sys
import termios
import tty
fd = sys.stdin.fileno()
saved = termios.tcgetattr(fd)
try:
    tty.setraw(fd)
    sys.stdout.write("WB_FIXTURE_READY\r\n")
    sys.stdout.flush()
    while True:
        key = sys.stdin.buffer.read(1)
        if not key or key == b"q":
            break
        sys.stdout.write("KEY=" + key.hex() + "\r\n")
        sys.stdout.flush()
finally:
    termios.tcsetattr(fd, termios.TCSANOW, saved)
sys.stdout.write("WB_FIXTURE_DONE\r\n")
sys.stdout.flush()
'''


@unittest.skipUnless(PrivateTmuxPTY.available(), "private tmux/stty unavailable")
class PrivatePtyDriverTests(unittest.TestCase):
    def test_real_tty_input_and_terminal_state_restoration(self):
        with PrivateTmuxPTY([sys.executable, "-u", "-c", TTY_FIXTURE],
                            cols=80, rows=24) as session:
            self.assertIn("WB_FIXTURE_READY", session.wait_for("WB_FIXTURE_READY"))
            session.send_text("z")
            self.assertIn("KEY=7a", session.wait_for("KEY=7a"))
            session.send_text("q")
            code, restored = session.wait_for_exit()
            self.assertEqual(code, 0)
            self.assertTrue(restored, "termios not restored after quitting fixture")

    def test_pty_resize_does_not_change_input_stream(self):
        with PrivateTmuxPTY([sys.executable, "-u", "-c", TTY_FIXTURE],
                            cols=80, rows=24) as session:
            session.wait_for("WB_FIXTURE_READY")
            self.assertEqual((80, 24), session.geometry())
            session.resize(120, 40)
            self.assertEqual((120, 40), session.geometry())
            session.resize(160, 50)
            self.assertEqual((160, 50), session.geometry())
            session.send_text("A")
            self.assertIn("KEY=41", session.wait_for("KEY=41"))
            session.send_text("q")
            code, restored = session.wait_for_exit()
            self.assertEqual(code, 0)
            self.assertTrue(restored)


if __name__ == "__main__":
    unittest.main()
