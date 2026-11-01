"""E3 native Workbench PTY regressions, without a second renderer or stubs.

Each case uses its own private tmux socket, a real SBCL/CLPM launcher and
termios before/after; no user tmux session or source outside Workbench is edited.
"""

import shutil
import unittest

from pty_driver import PrivateTmuxPTY


@unittest.skipUnless(shutil.which("clpm") and PrivateTmuxPTY.available(),
                     "CLPM, tmux and stty required")
class E3WorkbenchPTY(unittest.TestCase):
    command = ["./scripts/examples.sh", "run", "repl"]

    def open_repl(self, width=80, height=24):
        terminal = PrivateTmuxPTY(self.command, cols=width, rows=height,
                                 timeout=30)
        terminal.start()
        self.addCleanup(terminal.stop)
        # The header precedes input-loop readiness: never inject into startup.
        terminal.wait_for(lambda screen: "Lisp Workbench" in screen and
                          "Ready  |" in screen, timeout=30)
        return terminal

    def finish(self, terminal):
        terminal.send_key("C-d")
        code, restored = terminal.wait_for_exit(timeout=15)
        self.assertEqual(0, code)
        self.assertTrue(restored, "termios differs after Workbench exit")

    def test_small_terminal_resize_preserves_incomplete_editor_and_exit(self):
        terminal = self.open_repl(24, 8)
        terminal.send_text("(list 123")
        terminal.wait_for("list 123", timeout=15)
        for size in ((40, 12), (120, 40), (24, 8), (80, 24)):
            with self.subTest(geometry=size):
                terminal.resize(*size)
                self.assertEqual(size, terminal.geometry())
                terminal.wait_for("list 123", timeout=12)
        # Clear the incomplete edit; the empty-buffer Ctrl+D should work.
        for _ in range(len("(list 123")):
            terminal.send_key("BSpace")
        terminal.wait_for(lambda screen: "> |" in screen, timeout=12)
        self.finish(terminal)

    def test_editor_survives_evaluation_error_and_inspector_focus(self):
        terminal = self.open_repl()
        terminal.send_text('(error "E3-DIAGNOSTIC")')
        terminal.send_key("Enter")
        terminal.wait_for("ERROR:", timeout=15)
        terminal.send_key("F2")
        terminal.wait_for("IMAGE /", timeout=12)
        terminal.send_key("F2")
        terminal.wait_for("REPL", timeout=12)
        terminal.send_text("(+ 6 9)")
        terminal.send_key("Enter")
        terminal.wait_for(lambda screen: "COMMON-LISP-USER>" in screen
                          and any(row.lstrip().startswith("15 ")
                                  for row in screen.splitlines()), timeout=15)
        self.finish(terminal)

    def test_completion_selection_remains_in_visible_popup(self):
        terminal = self.open_repl()
        terminal.send_text("(c")
        terminal.wait_for(lambda screen: "> (c|" in screen, timeout=12)
        terminal.send_key("C-Space")
        first = terminal.wait_for("[ COMPLETION ]", timeout=15)
        self.assertIn("> ", first)
        for _ in range(7):
            terminal.send_key("Down")
            terminal.wait_for("[ COMPLETION ]", timeout=12)
        selected = terminal.capture()
        # At minimum the popup must remain visible after navigating beyond
        # the initial five candidates and permit an explicit dismissal.
        self.assertIn("[ COMPLETION ]", selected)
        terminal.send_key("Escape")
        terminal.wait_for(lambda screen: "[ COMPLETION ]" not in screen,
                          timeout=12)
        for _ in range(2):
            terminal.send_key("BSpace")
        self.finish(terminal)


if __name__ == "__main__":
    unittest.main()
