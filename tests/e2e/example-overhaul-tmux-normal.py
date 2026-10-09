#!/usr/bin/env python3
"""Focused normal-buffer tmux inspector contract; no alternate screen allowed."""
import importlib.util
from pathlib import Path
import tempfile
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("tmux_normal_harness", ROOT / "scripts/test-terminal-apps.py")
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)


class Options:
    terminal = "tmux"
    timeout = 16
    output = None


class NormalBufferInspector(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="elmtui-normal-restore-")
        Options.output = Path(cls.tmp.name)
        harness.OPTIONS = Options()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_b2_exactly_one_selected_cell(self):
        form = r"""(let* ((rows (elmtui-examples.cursor-inspector::%b2-focus-rows
                                         "ABCDEFG" 3))
                        (mid (second rows)))
                   ;; B2's 1-column interior must coincide with the selected cell.
                   (assert (char= (char mid 3) #\D))
                   (assert (string= (subseq mid 2 5) "│D│"))
                   (assert (string= (subseq (first rows) 2 5) "┌─┐"))
                   (assert (string= (subseq (third rows) 2 5) "└─┘"))
                   (let ((edge (elmtui-examples.cursor-inspector::%b2-focus-rows
                                 "ABC" 0)))
                     (assert (char= (char (second edge) 0) #\A))
                     (assert (search "─┐" (first edge)))))"""
        result = subprocess.run(
            ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
             "--noinform", "--non-interactive",
             "--eval", '(asdf:load-system "elmtui-examples")',
             "--eval", form], cwd=ROOT, capture_output=True, text=True, timeout=45)
        self.assertEqual(result.returncode, 0, result.stderr[-1800:])

    def test_b1_reports_captured_sgr_metadata(self):
        form = r"""(let* ((raw (format nil "~C[1;31;44mA~C[0m" #\Escape #\Escape))
                         (state (list :tmux-enabled t :lines (vector raw)
                                      :cursor-x 0 :cursor-y 0 :title "INSPECTOR"
                                      :mode :pane :status "captured"))
                         (view (elmtui-examples.cursor-inspector:cursor-inspector-view state))
                         (printed (prin1-to-string view)))
                    (assert (search "B1 / GLYPH + STYLE" printed))
                    (assert (search "FG: :RED" printed))
                    (assert (search "BG: :BLUE" printed))
                    (assert (search ":BOLD" printed))
                    (assert (search "Parsed:" printed))
                    (assert (search "Specimen:" printed)))"""
        result = subprocess.run(
            ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
             "--noinform", "--non-interactive",
             "--eval", '(asdf:load-system "elmtui-examples")',
             "--eval", form], cwd=ROOT, capture_output=True, text=True, timeout=45)
        self.assertEqual(result.returncode, 0, result.stderr[-1800:])

    def test_real_underlay_restore_without_resize(self):
        gate = Options.output / "begin"
        prelude = (
            'for n in $(seq -w 1 70); do printf "HISTORY-MARKER-%s\n" "$n"; done\n'
            'printf "UNDERLAY-ALPHA\nUNDERLAY-BETA\n"\n'
            f'until test -e "{gate}"; do sleep .05; done'
        )
        app = harness.TerminalApp("hover-normal", 
            "(elmtui-examples.tmux-hover-demo:run-tmux-hover-demo)",
            prelude=prelude, use_launcher=False)
        self.addCleanup(app.close)
        app.start()
        app.expect("UNDERLAY-BETA")
        original = app.tmux("capture-pane", "-p", "-S", "-", "-t", "app:0.0").stdout
        for n in range(1, 71):
            self.assertEqual(original.count(f"HISTORY-MARKER-{n:02d}"), 1)
        gate.touch()
        app.expect("B1 / GLYPH + STYLE")
        app.expect("B2 focus / B1 style")
        app.key("Right")
        app.expect("Cursor: (1, 0)")
        app.key("q", literal=True)
        app.wait(lambda screen: "ELMTUI_E2E_SHELL_RESTORED" in screen, "shell restore")
        after = app.tmux("capture-pane", "-p", "-S", "-", "-t", "app:0.0").stdout
        for n in range(1, 71):
            self.assertEqual(after.count(f"HISTORY-MARKER-{n:02d}"), 1)
        self.assertEqual(after.count("UNDERLAY-ALPHA"), 1)
        self.assertEqual(after.count("UNDERLAY-BETA"), 1)
        self.assertNotIn("B1 / GLYPH + STYLE", app.screen())
        raw = (app.directory / "terminal.raw").read_bytes()
        self.assertNotIn(b"\x1b[?1049h", raw)
        self.assertNotIn(b"\x1b[?1049l", raw)
        self.assertEqual((app.directory / "before.stty").read_text(),
                         (app.directory / "after.stty").read_text())
        self.assertEqual((app.directory / "exit-code").read_text().strip(), "0")


if __name__ == "__main__":
    unittest.main(verbosity=2)
