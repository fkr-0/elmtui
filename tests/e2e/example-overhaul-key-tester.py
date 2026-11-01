#!/usr/bin/env python3
"""Deterministic tmux PTY contract for the ElmTUI key event inspector."""
import importlib.util
from pathlib import Path
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("terminal_harness", ROOT / "scripts/test-terminal-apps.py")
terminal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(terminal)


class Options:
    terminal = "tmux"
    timeout = 10
    output = None


class KeyTesterPTY(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="key-tester-pty-")
        Options.output = Path(cls.temp.name)
        terminal.OPTIONS = Options()

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_history_navigation_idle_resize_quit(self):
        app = terminal.TerminalApp(
            "key-tester", "(elmtui-examples.key-tester:run-key-tester-app)",
            use_launcher=False)
        self.addCleanup(app.close)
        app.start()
        app.expect("Elm TUI Key Tester")
        app.expect("HISTORY")
        for key in "abcdefg":
            app.key(key, literal=True)
        app.expect("Input: abcdefg")
        app.expect("Events: 7")
        app.key("Up")
        app.expect("HISTORY 2-6 / 7")
        app.key("Down")
        app.expect("HISTORY 1-5 / 7")
        app.key("BSpace")
        app.expect("Input: abcdef")
        app.key("Escape")
        app.wait(lambda s: "Input: abcdef" not in s and "Input:" in s,
                 "Escape clears input")
        app.tmux("resize-window", "-t", "app:0", "-x", "100", "-y", "32")
        app.expect("HISTORY")
        before = (app.directory / "terminal.raw").stat().st_size
        time.sleep(.65)
        after = (app.directory / "terminal.raw").stat().st_size
        self.assertEqual(before, after, "idle input caused terminal writes")
        app.key("q", literal=True)
        deadline = time.monotonic() + Options.timeout
        while "ELMTUI_E2E_SHELL_RESTORED" not in app.screen():
            if time.monotonic() > deadline:
                self.fail("quit did not restore shell")
            time.sleep(.05)
        self.assertEqual((app.directory / "exit-code").read_text().strip(), "0")
        self.assertEqual((app.directory / "before.stty").read_text(),
                         (app.directory / "after.stty").read_text())


if __name__ == "__main__":
    unittest.main()
