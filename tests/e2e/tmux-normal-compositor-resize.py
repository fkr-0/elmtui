#!/usr/bin/env python3
"""Real tmux regression gate: restore normal-screen history after resize.

The complete 70-line styled oracle must survive the application. During pane
shrink, tmux can transiently move painted rows into scrollback: this cannot
be prevented in normal-screen mode. Older protected history remains immutable,
and no painted overlays may survive restoration. A red result blocks changes.
Run with: python3 tests/e2e/tmux-normal-compositor-resize.py
"""
import importlib.util
from pathlib import Path
import re
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "elmtui_terminal_harness", ROOT / "scripts/test-terminal-apps.py")
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)

MARKER_RE = re.compile(r"HISTORY-MARKER-(\d{2})")
STYLED_RE = re.compile(r"(?P<before>(?:\x1b\[[0-9;]*m)*)"
                       r"HISTORY-MARKER-(?P<number>\d{2})"
                       r"(?P<after>(?:\x1b\[[0-9;]*m)*)")


class Options:
    terminal = "tmux"
    timeout = 12
    output = None


def styled_markers(text):
    """Map each marker to its complete SGR-decorated source line."""
    matches = {}
    for line in text.splitlines():
        found = STYLED_RE.search(line)
        if found:
            number = int(found.group("number"))
            if number in matches:
                raise AssertionError(f"Duplicate marker {number}: {line!r}")
            matches[number] = line
    return matches


class NormalScreenResizeRestoration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="elmtui-tmux-resize-")
        Options.output = Path(cls.temp.name)
        harness.OPTIONS = Options()

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def capture(self, app):
        return app.tmux("capture-pane", "-p", "-e", "-S", "-",
                        "-t", "app:0.0").stdout

    def check_history(self, reference, current, context):
        before = styled_markers(reference)
        after = styled_markers(current)
        self.assertEqual(set(before), set(range(1, 71)),
                         "broken test oracle before app launch")
        self.assertEqual(
            after, before,
            f"{context}: every one of 70 original lines and SGR styles must "
            "survive unchanged; no substitutions, duplicates, or omissions")
        self.assertNotIn("B1 / GLYPH", current,
                         f"{context}: rendered overlay leaked into scrollback")
        self.assertNotIn("B2 focus", current,
                         f"{context}: rendered overlay leaked into scrollback")

    def test_hover_preserves_styled_history_after_both_resize_directions(self):
        permit = Options.output / "hover-start"
        prelude = (
            'for n in $(seq -w 1 70); do '
            'printf "\\033[34;1mHISTORY-MARKER-%s\\033[0m\\n" "$n"; done\n'
            'printf "UNDERLAY-ALPHA\\nUNDERLAY-BETA\\n"\n'
            f'until test -e "{permit}"; do sleep .05; done'
        )
        app = harness.TerminalApp(
            "resize-hover",
            "(elmtui-examples.tmux-hover-demo:run-tmux-hover-demo)",
            prelude=prelude, use_launcher=False)
        self.addCleanup(app.close)
        app.start()
        app.expect("UNDERLAY-BETA")
        original = self.capture(app)
        permit.touch()
        app.expect("tmux-hover-demo [TMUX]")
        protected_history = {number: line for number, line in
                             styled_markers(original).items() if number <= 30}
        self.assertEqual(set(protected_history), set(range(1, 31)))
        for width, height in ((70, 22), (100, 35), (48, 12), (100, 35)):
            app.tmux("resize-window", "-t", "app:0",
                     "-x", str(width), "-y", str(height))
            time.sleep(.35)
            reported = app.tmux(
                "display-message", "-p", "-t", "app:0.0",
                "#{pane_width} #{pane_height}").stdout.strip()
            self.assertEqual(reported, f"{width} {height}")
            current_markers = styled_markers(self.capture(app))
            self.assertEqual(
                {number: current_markers.get(number)
                 for number in protected_history}, protected_history,
                f"protected original scrollback corrupted at {width}x{height}")
        app.key("q", literal=True)
        deadline = time.monotonic() + Options.timeout
        while "ELMTUI_E2E_SHELL_RESTORED" not in app.screen():
            self.assertLess(time.monotonic(), deadline,
                            "normal-screen app must exit cleanly")
            time.sleep(.05)
        self.assertEqual((app.directory / "exit-code").read_text().strip(), "0")
        self.assertEqual((app.directory / "before.stty").read_text(),
                         (app.directory / "after.stty").read_text())
        self.check_history(original, self.capture(app), "shrink/grow")
        self.assertEqual(app.screen().count("UNDERLAY-ALPHA"), 1)
        self.assertEqual(app.screen().count("UNDERLAY-BETA"), 1)
        # Final restoration checks all 70 marker lines and excludes overlays;
        # transient resize scrollback is a terminal limitation, not data loss.


    def test_ctrl_c_repeated_launch_movement_idle_and_exact_restoration(self):
        for iteration, key in enumerate(("C-c", "q")):
            with self.subTest(exit_key=key):
                permit = Options.output / f"controls-start-{iteration}"
                prelude = (
                    'for n in $(seq -w 1 70); do '
                    'printf "\\033[34;1mHISTORY-MARKER-%s\\033[0m\\n" "$n"; done\n'
                    'printf "UNDERLAY-ALPHA\\nUNDERLAY-BETA\\n"\n'
                    f'until test -e "{permit}"; do sleep .05; done'
                )
                app = harness.TerminalApp(
                    f"controls-{iteration}",
                    "(elmtui-examples.tmux-hover-demo:run-tmux-hover-demo)",
                    prelude=prelude, use_launcher=False)
                self.addCleanup(app.close)
                app.start()
                app.expect("UNDERLAY-BETA")
                original = self.capture(app)
                permit.touch()
                app.expect("tmux-hover-demo [TMUX]")
                app.key("Right")
                app.expect("Cursor: (1, 0)")
                app.key("Down")
                app.expect("Cursor: (1, 1)")
                app.key("Up")
                app.expect("Cursor: (1, 0)")
                # A settled idle inspector must not emit needless frames.
                time.sleep(.3)
                first = (app.directory / "terminal.raw").stat().st_size
                time.sleep(.7)
                second = (app.directory / "terminal.raw").stat().st_size
                self.assertEqual(first, second,
                                 "idle must not write redundant terminal frames")
                app.key(key, literal=(key == "q"))
                deadline = time.monotonic() + Options.timeout
                while "ELMTUI_E2E_SHELL_RESTORED" not in app.screen():
                    self.assertLess(time.monotonic(), deadline,
                                    "Ctrl+C and q must restore the shell")
                    time.sleep(.05)
                self.assertEqual((app.directory / "exit-code").read_text().strip(),
                                 "0")
                self.assertEqual((app.directory / "before.stty").read_text(),
                                 (app.directory / "after.stty").read_text())
                self.check_history(original, self.capture(app), key)
                self.assertEqual(app.screen().count("UNDERLAY-ALPHA"), 1)
                self.assertEqual(app.screen().count("UNDERLAY-BETA"), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
