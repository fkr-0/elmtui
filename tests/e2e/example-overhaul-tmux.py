#!/usr/bin/env python3
"""Inspector contract fixtures and real isolated tmux PTYs."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("tmux_harness", ROOT / "scripts/test-terminal-apps.py")
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)


class Options:
    terminal = "tmux"
    timeout = 12
    output = None


def check_lisp(expr):
    # Static fixture forms were structurally validated at authoring time;
    # keep the test runner independent of the developer's skill installation.
    result = subprocess.run(
        ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
         "--noinform", "--non-interactive", "--eval", "(require :asdf)",
         "--eval", '(asdf:load-system "elmtui-examples")',
         "--eval", expr], cwd=ROOT, text=True, capture_output=True, timeout=40)
    if result.returncode:
        raise AssertionError(result.stdout[-1200:] + result.stderr[-2200:])


class DeterministicInspector(unittest.TestCase):
    def test_unicode_and_clamps(self):
        check_lisp(r"""(progn
          (assert (= 4 (elmtui-examples.cursor-inspector:%display-width "A界B")))
          (assert (= 2 (elmtui-examples.cursor-inspector:%display-width "éx")))
          (assert (equal '("界" 1 2)
                         (elmtui-examples.cursor-inspector:%inspected-cell "A界B" 2)))
          (multiple-value-bind (x y)
              (elmtui-examples.cursor-inspector:%clamp-position #("A界B" "z") 999 999)
            (assert (and (= x 0) (= y 1)))))""")

    def test_non_tmux_fallback_and_empty_history(self):
        check_lisp(r"""(let* ((state '(:tmux-enabled nil :lines #() :mode :pane
                                      :cursor-x 0 :cursor-y 0 :title "INSPECTOR"
                                      :status "No tmux session"))
                             (view (elmtui-examples.cursor-inspector:cursor-inspector-view state))
                             (printed (prin1-to-string view)))
                        (assert (search "[NO-TMUX]" printed))
                        (assert (search "No tmux session" printed)))""")

    def test_visible_pane_rows_exclude_terminator_and_keep_sgr(self):
        check_lisp(r"""(let* ((raw (format nil "ROW0~%~C[31mROW1~C[0m~%~%"
                                       #\Escape #\Escape))
                            (lines (elmtui-examples.cursor-inspector::%visible-pane-lines raw)))
                           (assert (= 3 (length lines)))
                           (assert (string= "ROW0" (aref lines 0)))
                           (assert (search "ROW1" (aref lines 1)))
                           (assert (find #\Escape (aref lines 1)))
                           (assert (string= "" (aref lines 2))))""")

    def test_overlay_capture_guard(self):
        check_lisp(r"""(progn
          (assert (elmtui-examples.cursor-inspector:%capture-safe-p #("history")))
          (assert (not (elmtui-examples.cursor-inspector:%capture-safe-p
                         #("tmux-hover-demo [TMUX]"))))
          (assert (not (elmtui-examples.cursor-inspector:%capture-safe-p
                         #("CURSOR INSPECTOR [TMUX]")))))""")


class LiveTmuxInspector(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="elmtui-tmux-inspector-")
        Options.output = Path(cls.tmp.name)
        harness.OPTIONS = Options()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def launch(self, name, expression, width=80, height=24):
        prelude = ('for n in $(seq -w 1 70); do printf "HISTORY-MARKER-%s\\n" "$n"; done\n'
                   'printf "UNDERLAY-ALPHA\\nUNDERLAY-BETA\\n"')
        app = harness.TerminalApp(name, expression, prelude=prelude, use_launcher=False)
        self.addCleanup(app.close)
        app.start()
        app.tmux("resize-window", "-t", "app:0", "-x", str(width), "-y", str(height))
        return app

    def restored(self, app, title):
        app.wait(lambda s: "ELMTUI_E2E_SHELL_RESTORED" in s, "shell restored")
        self.assertEqual((app.directory / "exit-code").read_text().strip(), "0")
        self.assertEqual((app.directory / "before.stty").read_text(),
                         (app.directory / "after.stty").read_text())
        history = app.tmux("capture-pane", "-p", "-S", "-", "-t", "app:0.0").stdout
        self.assertEqual(history.count("HISTORY-MARKER-"), 70)
        self.assertEqual(history.count("UNDERLAY-ALPHA"), 1)
        self.assertEqual(history.count("UNDERLAY-BETA"), 1)
        self.assertNotIn(title, app.screen())

    def test_modes_resize_idle_exit_both_sizes(self):
        for cols, rows in [(80, 24), (120, 40)]:
            with self.subTest(size=(cols, rows)):
                app = self.launch("hover-%dx%d" % (cols, rows),
                    "(elmtui-examples.tmux-hover-demo:run-tmux-hover-demo)", cols, rows)
                app.expect("tmux-hover-demo [TMUX]")
                app.key("Right")
                app.expect("Cursor: (1, 0)")
                app.key("s", literal=True)
                app.expect("SCROLLBACK")
                app.key("p", literal=True)
                app.expect("PANE")
                app.key("r", literal=True)
                app.expect("tmux capture refreshed")
                time.sleep(0.5)
                before = (app.directory / "terminal.raw").read_bytes()
                time.sleep(0.6)
                self.assertEqual(before, (app.directory / "terminal.raw").read_bytes())
                app.tmux("resize-window", "-t", "app:0", "-x",
                         str(120 if cols == 80 else 80),
                         "-y", str(40 if rows == 24 else 24))
                app.key("q", literal=True)
                self.restored(app, "tmux-hover-demo [TMUX]")

    def test_escape_and_repeated_launches(self):
        for i in range(2):
            with self.subTest(repeat=i):
                app = self.launch("cursor-%d" % i,
                   "(elmtui-examples.cursor-inspector:run-cursor-inspector)")
                app.expect("CURSOR INSPECTOR [TMUX]")
                app.key("Escape")
                self.restored(app, "CURSOR INSPECTOR [TMUX]")

    def test_control_interruption(self):
        app = self.launch("ctrl-c",
            "(elmtui-examples.cursor-inspector:run-cursor-inspector)")
        app.expect("CURSOR INSPECTOR [TMUX]")
        app.key("C-c")
        self.restored(app, "CURSOR INSPECTOR [TMUX]")


if __name__ == "__main__":
    unittest.main(verbosity=2)
