"""Flagship REPL entry: exercise the examples CLI against a real isolated tmux.

The Workbench must remain a regular ElmTUI defapplication; its launcher must
not start a second REPL, enter an alternate screen, or leave terminal modes
changed on exit.
"""

import shutil
import unittest

from pty_driver import PrivateTmuxPTY, ROOT


class NativeReplPresentation(unittest.TestCase):
    def test_only_one_repl_implementation_and_declarative_app(self):
        launcher = (ROOT / "examples/repl.lisp").read_text(encoding="utf-8")
        app = (ROOT / "src/workbench/app.lisp").read_text(encoding="utf-8")
        view = (ROOT / "src/workbench/view.lisp").read_text(encoding="utf-8")
        self.assertIn('(asdf:load-system "elmtui-workbench")', launcher)
        self.assertIn('find-symbol "RUN-WORKBENCH"', launcher)
        self.assertIn("(:use :cl)", launcher)
        self.assertIn("(elmtui.app:defapplication workbench", app)
        self.assertIn(":view-fn #'workbench-view", app)
        self.assertIn(":update-fn #'workbench-update", app)
        self.assertIn(":subscriptions-fn workbench-subscriptions", app)
        self.assertIn(":use-alternate-screen nil", launcher)
        self.assertIn(":root-viewport", app)
        # Pending native styled-fragment layout: don't quietly move rendering
        # to a raw terminal painter to avoid the ElmTUI layout limitation.
        for source in (launcher, view):
            self.assertNotIn("(sb-posix:tcsetattr", source)
            self.assertNotIn("(write-char #\\Escape", source)

    @unittest.skipUnless(PrivateTmuxPTY.available() and shutil.which("clpm"),
                         "real private tmux and CLPM required")
    def test_examples_cli_repl_evaluates_and_restores(self):
        command = ["./scripts/examples.sh", "run", "repl"]
        with PrivateTmuxPTY(command, cols=120, rows=40, timeout=30) as terminal:
            screen = terminal.wait_for("Lisp Workbench", timeout=30)
            self.assertIn("REPL", screen)
            self.assertIn("IMAGE / PACKAGES", screen)
            terminal.send_text("(+ 40 2)")
            terminal.send_key("Enter")
            transcript = terminal.wait_for(
                lambda text: "COMMON-LISP-USER>" in text
                and any(line.lstrip().startswith("42 ") for line in text.splitlines()),
                timeout=15)
            self.assertIn("42", transcript)
            terminal.send_key("C-d")
            code, restored = terminal.wait_for_exit(timeout=15)
            self.assertEqual(code, 0)
            self.assertTrue(restored)
            stderr = (terminal.root / "stderr.txt").read_text(errors="replace")
            self.assertNotIn("Unhandled", stderr)
            # No alternate screen must be requested by this application.
            # PrivateTmuxPTY captures visible content, so a raw-protocol
            # check is covered separately by pty-workbench.py.

    @unittest.skipUnless(PrivateTmuxPTY.available() and shutil.which("clpm"),
                         "real private tmux and CLPM required")
    def test_examples_cli_completion_and_inspector(self):
        with PrivateTmuxPTY(
            ["./scripts/examples.sh", "run", "repl"],
            cols=120, rows=40, timeout=30,
        ) as terminal:
            terminal.wait_for("Lisp Workbench", timeout=30)
            terminal.send_text("(mapc")
            terminal.send_key("C-Space")
            terminal.wait_for("MAPCAR", timeout=12)
            terminal.send_key("F2")
            terminal.wait_for(
                lambda view: "IMAGE /" in view and "|  INSPECTOR" in view,
                timeout=12)
            terminal.send_key("F2")
            terminal.wait_for(lambda view: "|  EDITOR" in view, timeout=12)
            for _ in range(5):
                terminal.send_key("BSpace")
            terminal.wait_for(lambda view: " > |" in view, timeout=12)
            terminal.send_key("C-d")
            code, restored = terminal.wait_for_exit(timeout=15)
            self.assertEqual(0, code)
            self.assertTrue(restored)


if __name__ == "__main__":
    unittest.main()
