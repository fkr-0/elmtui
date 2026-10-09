"""Opt-in black-box workbench tests on a *real* launched ElmTUI process.

Configure only after W5 supplies its launcher:
  ELMTUI_WORKBENCH_TEST_CMD='clpm bundle exec --with-client sbcl -- ...'
and, if necessary, ELMTUI_WORKBENCH_READY_PATTERN.

Unlike the fixture driver tests, these must NOT report green before the real
application exists. Each missing-launcher test is explicitly skipped.
"""
import os
import shlex
import unittest

from pty_driver import PrivateTmuxPTY

_COMMAND = os.environ.get("ELMTUI_WORKBENCH_TEST_CMD", "").strip()
_READY = os.environ.get("ELMTUI_WORKBENCH_READY_PATTERN", r"CL-USER|Lisp Workbench")


@unittest.skipUnless(_COMMAND, "W5 application launcher unavailable; set ELMTUI_WORKBENCH_TEST_CMD")
@unittest.skipUnless(PrivateTmuxPTY.available(), "private tmux/stty unavailable")
class ApplicationBlackBoxTests(unittest.TestCase):
    def open_workbench(self, cols, rows):
        session = PrivateTmuxPTY(shlex.split(_COMMAND), cols=cols, rows=rows)
        session.start()
        self.addCleanup(session.stop)
        session.wait_for(_READY, timeout=20)
        return session

    def test_repl_evaluation_and_resize_80_120_160(self):
        session = self.open_workbench(80, 24)
        session.send_text("(+ 6 7)")
        session.send_key("Enter")
        session.wait_for(r"\b13\b", timeout=12)
        for geometry in ((120, 40), (160, 50), (80, 24)):
            with self.subTest(size=geometry):
                session.resize(*geometry)
                self.assertEqual(geometry, session.geometry())
                self.assertTrue(session.capture().strip())

    def test_completion_selection_is_visible(self):
        session = self.open_workbench(120, 40)
        session.send_text("(mapc")
        session.send_key("C-Space")
        screen = session.wait_for(r"MAPCAR", timeout=12)
        self.assertIn("MAPCAR", screen)
        # W5/W6 should add an emulator-geometry test for above-cursor placement.

    def test_empty_ctrl_d_quits_and_restores_termios(self):
        session = self.open_workbench(80, 24)
        session.send_key("C-d")
        code, restored = session.wait_for_exit(timeout=12)
        self.assertEqual(code, 0)
        self.assertTrue(restored, "stty -g changed across application lifecycle")


if __name__ == "__main__":
    unittest.main()
