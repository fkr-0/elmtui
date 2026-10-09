#!/usr/bin/env python3
"""Private-tmux PTY tests for repaired examples and scrollback restoration.

Run: python3 tests/e2e/tmux-scrollback-restoration.py
No fake TTY or mocked terminal renderer: every app starts in its own tmux
server, and the original pane/history is captured before app initialization.
"""
import importlib.util
from pathlib import Path
import re
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
HARNESS = ROOT / "scripts" / "test-terminal-apps.py"
spec = importlib.util.spec_from_file_location("elmtui_terminal_harness", HARNESS)
terminal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(terminal)


class Options:
    terminal = "tmux"
    timeout = 9
    output = None


class AdditionalExamplesPTY(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="elmtui-examples-tmux-")
        Options.output = Path(cls.temp.name)
        terminal.OPTIONS = Options()

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def launch(self, name, expression, *, prelude=""):
        app = terminal.TerminalApp(name, expression, prelude=prelude,
                                   use_launcher=False)
        self.addCleanup(app.close)
        app.start()
        return app

    def assert_exited_cleanly(self, app):
        deadline = time.monotonic() + Options.timeout
        # Exit-code is written immediately before the shell restoration marker.
        # Poll past exit-code to avoid mistaking that harmless ordering for a crash.
        while "ELMTUI_E2E_SHELL_RESTORED" not in app.screen():
            if time.monotonic() >= deadline:
                self.fail("shell did not resume after application exit")
            time.sleep(0.05)
        self.assertEqual((app.directory / "exit-code").read_text().strip(), "0")
        self.assertEqual((app.directory / "before.stty").read_text(),
                         (app.directory / "after.stty").read_text())
        self.assertEqual(app.tmux("display-message", "-p", "-t", "app:0.0",
                                  "#{cursor_flag}").stdout.strip(), "1")
        stderr = (app.directory / "stderr.txt").read_text(errors="replace")
        self.assertNotRegex(stderr, r"Unhandled |fatal error|undefined function")

    def test_dirli_selection_does_not_enter_directory(self):
        app = self.launch("dirli",
                          "(elmtui.examples.dirli:run-dirli)")
        app.expect("DIRLI")
        app.expect("selection 1")
        app.key("Down")
        app.expect("selection 2")
        app.key("q", literal=True)
        self.assert_exited_cleanly(app)

    def test_both_rainbows_show_colored_stable_frames(self):
        cases = [
            ("rainbow", "(elmtui.examples.rainbow-app:run-rainbow-example-app)",
             "CHROMATIC / 08", "Layout:"),
            ("mini-rainbow", "(elmtui.examples.mini-rainbow:run-mini-rainbow)",
             "RAINBOW / mini", "Direction:"),
        ]
        for name, expression, title, status in cases:
            with self.subTest(name=name):
                app = self.launch(name, expression)
                app.expect(title)
                app.expect(status + " ROW")
                app.key("Space")
                app.expect(status + " COLUMN")
                app.key("Space")
                app.expect(status + " ROW")
                raw = (app.directory / "terminal.raw").read_bytes()
                self.assertIn(b"\x1b[38;2;", raw)
                app.key("q", literal=True)
                self.assert_exited_cleanly(app)

    def test_key_tester_edit_backspace_and_escape(self):
        app = self.launch("key-tester",
                          "(elmtui-examples.key-tester:run-key-tester-app)")
        app.expect("Elm TUI Key Tester")
        app.key("a", literal=True)
        app.key("b", literal=True)
        app.expect("Input: ab")
        app.key("BSpace")
        app.expect("Input: a")
        app.key("Escape")
        app.wait(lambda screen: "Input: a" not in screen and "Input:" in screen,
                 "Escape clears typed buffer")
        app.key("q", literal=True)
        self.assert_exited_cleanly(app)

    def exercise_scrollback_restoration(self, name, expression, title):
        permit = Options.output / (name + ".start")
        prelude = (
            'for n in $(seq -w 1 70); do printf "HISTORY-MARKER-%s\\n" "$n"; done\n'
            'printf "UNDERLAY-ALPHA\\nUNDERLAY-BETA\\n"\n'
            'until test -e "' + str(permit) + '"; do sleep .05; done'
        )
        app = self.launch(name, expression, prelude=prelude)
        app.expect("UNDERLAY-BETA")
        before = app.screen()
        history_before = app.tmux("capture-pane", "-p", "-S", "-",
                                  "-t", "app:0.0").stdout
        self.assertEqual(history_before.count("HISTORY-MARKER-"), 70)
        self.assertEqual(before.count("UNDERLAY-ALPHA"), 1)
        permit.touch()
        app.expect(title)
        if name == "tmux-hover":
            app.key("Right")
            app.expect("Cursor: (1, 0)")
            app.key("r", literal=True)
            app.expect("tmux capture refreshed")
        else:
            first_frame = app.screen()
            time.sleep(1.2)
            self.assertNotEqual(first_frame, app.screen(),
                                "Idle screen should animate after terminal bootstrap")
        app.key("q", literal=True)
        self.assert_exited_cleanly(app)
        after = app.screen()
        history_after = app.tmux("capture-pane", "-p", "-S", "-",
                                 "-t", "app:0.0").stdout
        self.assertEqual(history_after.count("HISTORY-MARKER-"), 70)
        for n in range(1, 71):
            self.assertIn(f"HISTORY-MARKER-{n:02d}", history_after)
        self.assertEqual(after.count("UNDERLAY-ALPHA"), 1)
        self.assertEqual(after.count("UNDERLAY-BETA"), 1)
        self.assertNotIn(title, after, "Tmux app overlay must be fully restored")

    def test_hover_restores_underlay_and_historical_scrollback(self):
        self.exercise_scrollback_restoration(
            "tmux-hover",
            "(elmtui-examples.tmux-hover-demo:run-tmux-hover-demo)",
            "tmux-hover-demo [TMUX]")

    def test_idle_restores_underlay_and_historical_scrollback(self):
        self.exercise_scrollback_restoration(
            "tmux-idle",
            "(elmtui.examples.tmux-idle:run-tmux-idle)",
            "Press any key to exit")


if __name__ == "__main__":
    unittest.main(verbosity=2)
