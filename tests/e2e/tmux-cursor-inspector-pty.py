#!/usr/bin/env python3
"""Real tmux cursor-box/tooltip lifecycle; no fake renderer or alternate screen."""
import importlib.util
from pathlib import Path
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "cursor_term_harness", ROOT / "scripts/test-terminal-apps.py")
term = importlib.util.module_from_spec(spec)
spec.loader.exec_module(term)


class Options:
    terminal = "tmux"
    timeout = 20
    output = None


class TmuxCursorInspectorPTY(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="elmtui-tmux-cursor-")
        Options.output = Path(cls.tmp.name)
        term.OPTIONS = Options()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_move_tooltip_idle_and_restore(self):
        gate = Options.output / "start"
        prelude = (
            'for n in $(seq -w 1 64); do printf "INSPECTOR-HISTORY-%s\\n" "$n"; done\n'
            'printf "\\033[1;38;5;196;44mCURSOR-STYLE-UNDERLAY\\033[0m\\n"\n'
            'printf "CURSOR-TARGET-ABCDEFGHIJKLMN\\n"\n'
            f'until test -f "{gate}"; do sleep .05; done'
        )
        app = term.TerminalApp(
            "tmux-cursor-physical",
            "(elmtui.examples.tmux-cursor-inspector:run-tmux-cursor-inspector)",
            source="tmux-cursor-inspector.lisp",
            prelude=prelude, use_launcher=False)
        self.addCleanup(app.close)
        app.start()
        app.expect("CURSOR-TARGET")
        before = app.tmux("capture-pane", "-p", "-e", "-S", "-", "-t", "app:0.0").stdout
        self.assertEqual(before.count("INSPECTOR-HISTORY-"), 64)
        gate.touch()
        app.expect("CELL (")
        app.expect("┌")
        app.expect("width")
        app.expect("FG")
        first = app.screen()
        app.key("Right")
        app.wait(lambda text: "CELL (" in text and text != first,
                 "cursor moves while tooltip updates")
        app.key("Down")
        time.sleep(.3)
        idle_frame = app.screen()
        raw = (app.directory / "terminal.raw").read_bytes()
        time.sleep(.35)
        self.assertEqual(idle_frame, app.screen(), "No redraw while idle")
        self.assertEqual(raw, (app.directory / "terminal.raw").read_bytes(),
                         "No terminal writes while idle")
        app.key("q", literal=True)
        try:
            app.expect("ELMTUI_E2E_SHELL_RESTORED")
        except AssertionError as error:
            self.fail(f"{error}\nexit-code="
                      f"{(app.directory / 'exit-code').read_text() if (app.directory / 'exit-code').exists() else 'missing'}"
                      f"\nstderr={(app.directory / 'stderr.txt').read_text(errors='replace')[-4000:]}")
        self.assertEqual("0", (app.directory / "exit-code").read_text().strip())
        self.assertEqual((app.directory / "before.stty").read_text(),
                         (app.directory / "after.stty").read_text())
        self.assertNotIn("CELL (", app.screen())
        self.assertNotIn("┌", app.screen())
        after = app.tmux("capture-pane", "-p", "-e", "-S", "-", "-t", "app:0.0").stdout
        for i in range(1, 65):
            self.assertIn(f"INSPECTOR-HISTORY-{i:02d}", after)
        self.assertEqual(before.count("INSPECTOR-HISTORY-"),
                         after.count("INSPECTOR-HISTORY-"))
        self.assertIn("CURSOR-STYLE-UNDERLAY", after)
        self.assertIn("CURSOR-TARGET-ABCDEFGHIJKLMN", after)
        before_styled = [row for row in before.splitlines()
                         if "CURSOR-STYLE-UNDERLAY" in row]
        after_styled = [row for row in after.splitlines()
                        if "CURSOR-STYLE-UNDERLAY" in row]
        self.assertEqual(before_styled, after_styled,
                         "Restored styled underlay must retain exact SGR")
        self.assertNotIn("│", after)
        raw = (app.directory / "terminal.raw").read_bytes()
        for escape in (b"\x1b[?1049h", b"\x1b[?1047h",
                       b"\x1b[2J", b"\x1b[3J"):
            self.assertNotIn(escape, raw)

    def test_wide_and_combining_glyph_coordinates_and_box_bounds(self):
        import subprocess
        expression = r"""(let* ((snap (elmtui.examples.tmux-cursor-inspector:snapshot-from-styled-string
                                    (format nil "A界Bé~%") 14 5))
                                  (cell (multiple-value-list
                                          (elmtui.examples.tmux-cursor-inspector:inspected-cell
                                           snap 2 0)))
                                  (comb (multiple-value-list
                                          (elmtui.examples.tmux-cursor-inspector:inspected-cell
                                           snap 4 0)))
                                  (over (elmtui.examples.tmux-cursor-inspector:overlay-cells
                                         snap 2 2)))
                           (assert (equal "界" (getf (first cell) :glyph)))
                           (assert (= 1 (second cell)))
                           (assert (= 2 (third cell)))
                           (assert (equal "é" (getf (first comb) :glyph)))
                           (assert (every (lambda (entry) (and
                                            (<= 0 (first entry) 12)
                                            (<= 0 (second entry) 4))) over))
                           (format t "CURSOR-GLYPH-PASS~%"))"""
        result = subprocess.run(
            ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
             "--noinform", "--non-interactive",
             "--eval", '(asdf:load-system "elmtui")',
             "--load", "examples/tmux-cursor-inspector.lisp",
             "--eval", expression],
            cwd=ROOT, text=True, capture_output=True, timeout=40)
        self.assertEqual(result.returncode, 0, result.stderr[-3000:])
        self.assertIn("CURSOR-GLYPH-PASS", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
