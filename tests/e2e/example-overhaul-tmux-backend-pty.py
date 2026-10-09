#!/usr/bin/env python3
"""Private tmux/PTY qualification of the styled capture underlay.

Run: python3 tests/e2e/example-overhaul-tmux-backend-pty.py
Requires installed tmux, CLPM and SBCL. Every case uses a private tmux
server, private terminal capture, real driver initialization, and normal quit.
"""
import importlib.util
from pathlib import Path
import re
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("elmtui_private_tmux_harness",
                                               ROOT / "scripts/test-terminal-apps.py")
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)


class Options:
    terminal = "tmux"
    timeout = 18
    output = None


class StyledTmuxUnderlayPTY(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="elmtui-tmux-capture-")
        Options.output = Path(cls.temp.name)
        harness.OPTIONS = Options()

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    @staticmethod
    def styled_line(snapshot, marker):
        return next(line.rstrip() for line in snapshot.splitlines()
                    if marker in line)

    def test_styled_underlay_survives_overlay_in_private_tmux(self):
        fixtures = (
            ("backend-hover-80x24", "tmux-hover",
             "(elmtui-examples.tmux-hover-demo:run-tmux-hover-demo)",
             "tmux-hover-demo [TMUX]", 80, 24),
            ("backend-idle-120x40", "tmux-idle",
             "(elmtui.examples.tmux-idle:run-tmux-idle)",
             "Press any key to exit", 120, 40),
        )
        for identifier, sample, expr, visible, width, height in fixtures:
            with self.subTest(geometry=(width, height), sample=sample):
                ready = Options.output / (identifier + ".ready")
                prelude = (
                    'for n in $(seq 1 75); do printf "HISTORY-BACKEND-%03d\\n" "$n"; done\n'
                    "printf '\\033[31;44;1;4mSTYLED-UNDERLAY-ALPHA\\n"
                    "STYLED-UNDERLAY-BETA\\033[0m\\n'\n"
                    'until test -e "' + str(ready) + '"; do sleep .05; done'
                )
                app = harness.TerminalApp(identifier, expr,
                                           prelude=prelude, use_launcher=False)
                self.addCleanup(app.close)
                app.start()
                try:
                    app.expect("STYLED-UNDERLAY-BETA")
                    app.tmux("resize-window", "-t", "app:0", "-x", str(width),
                             "-y", str(height))
                    self.assertEqual(
                        app.tmux("display-message", "-p", "-t", "app:0.0",
                                 "#{pane_width}x#{pane_height}").stdout.strip(),
                        f"{width}x{height}")
                    history_before = app.tmux("capture-pane", "-e", "-p",
                                              "-S", "-", "-t", "app:0.0").stdout
                    self.assertEqual(history_before.count("HISTORY-BACKEND-"), 75)
                    line_before = self.styled_line(history_before,
                                                   "STYLED-UNDERLAY-ALPHA")
                    self.assertRegex(line_before, r"\x1b\[[0-9;:]*m")
                    ready.touch()
                    app.expect(visible)
                    app.key("q", literal=True)
                    app.wait(lambda s: "ELMTUI_E2E_SHELL_RESTORED" in s,
                             "shell restored after overlay")
                    self.assertEqual((app.directory / "exit-code").read_text().strip(),
                                     "0")
                    self.assertEqual((app.directory / "before.stty").read_text(),
                                     (app.directory / "after.stty").read_text())
                    self.assertEqual(
                        app.tmux("display-message", "-p", "-t", "app:0.0",
                                 "#{cursor_flag}").stdout.strip(), "1")
                    after_screen = app.screen()
                    self.assertIn("STYLED-UNDERLAY-ALPHA", after_screen)
                    self.assertIn("STYLED-UNDERLAY-BETA", after_screen)
                    self.assertNotIn(visible, after_screen)
                    history_after = app.tmux("capture-pane", "-e", "-p", "-S",
                                             "-", "-t", "app:0.0").stdout
                    self.assertEqual(history_after.count("HISTORY-BACKEND-"), 75)
                    positions = [history_after.index(f"HISTORY-BACKEND-{n:03d}")
                                 for n in range(1, 76)]
                    self.assertEqual(positions, sorted(positions))
                    self.assertEqual(
                        self.styled_line(history_after, "STYLED-UNDERLAY-ALPHA"),
                        line_before,
                        "captured foreground/background/attributes must survive")
                    self.assertNotRegex(
                        (app.directory / "stderr.txt").read_text(errors="replace"),
                        r"Unhandled |fatal error|undefined function")
                finally:
                    app.close()


if __name__ == "__main__":
    unittest.main(verbosity=2)
