#!/usr/bin/env python3
"""Tmux-native Conway glider overlay: real animation, styled underlay, no history loss."""
import importlib.util
from pathlib import Path
import os
import re
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("glider_term_harness", ROOT / "scripts/test-terminal-apps.py")
terminal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(terminal)


class Options:
    terminal = "tmux"
    timeout = 17
    output = None


class GliderTerminalPTY(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="elmtui-tmux-glider-")
        Options.output = Path(cls.tmp.name)
        terminal.OPTIONS = Options()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def app(self, name, expr, *, prelude=""):
        proc = terminal.TerminalApp(name, expr, source="tmux-glider.lisp",
                                    prelude=prelude, use_launcher=False)
        self.addCleanup(proc.close)
        proc.start()
        return proc

    def await_exit(self, app):
        app.expect("ELMTUI_E2E_SHELL_RESTORED")
        self.assertEqual("0", (app.directory / "exit-code").read_text().strip())
        self.assertEqual((app.directory / "before.stty").read_text(),
                         (app.directory / "after.stty").read_text())

    def test_evolving_five_cells_and_styled_history_restoration(self):
        gate = Options.output / "history-gate"
        prelude = (
            'for n in $(seq -w 1 73); do printf "GLIDER-HISTORY-%s\\n" "$n"; done\n'
            'printf "\\033[38;5;196mSTYLED-GLIDER-UNDERLAY\\033[0m\\n"\n'
            'printf "GLIDER-PANE-ANCHOR\\n"\n'
            f'until test -f "{gate}"; do sleep .05; done'
        )
        app = self.app("tmux-glider-walk",
                       "(elmtui.examples.tmux-glider:run-tmux-glider :speed 0.16)",
                       prelude=prelude)
        app.expect("GLIDER-PANE-ANCHOR")
        original = app.tmux("capture-pane", "-p", "-e", "-S", "-", "-t", "app:0.0").stdout
        self.assertEqual(original.count("GLIDER-HISTORY-"), 73)
        self.assertIn("\x1b[", original)
        gate.touch()
        frames = []
        deadline = time.monotonic() + 8.0
        while time.monotonic() < deadline and len(frames) < 7:
            pane = app.screen()
            if "█" in pane and (not frames or pane != frames[-1]):
                frames.append(pane)
            time.sleep(.12)
        self.assertGreaterEqual(len(frames), 5, "Expected living glider in at least five distinct frames")
        self.assertTrue(all(frame.count("█") == 5 for frame in frames[:5]),
                        "Glider must keep exactly five live cells")
        self.assertTrue(all("GLIDER-PANE-ANCHOR" in frame for frame in frames[:5]),
                        "All unrelated underlying text must remain visible")
        app.key("Space")
        time.sleep(.45)
        paused = app.screen()
        time.sleep(.42)
        self.assertEqual(paused, app.screen())
        app.key("n", literal=True)
        time.sleep(.4)
        self.assertNotEqual(paused, app.screen(), "Step must evolve paused glider")
        app.key("q", literal=True)
        self.await_exit(app)
        restored = app.tmux("capture-pane", "-p", "-e", "-S", "-", "-t", "app:0.0").stdout
        for i in range(1, 74):
            self.assertIn(f"GLIDER-HISTORY-{i:02d}", restored)
        self.assertEqual(restored.count("GLIDER-HISTORY-"), 73)
        self.assertIn("STYLED-GLIDER-UNDERLAY", restored)
        self.assertIn("GLIDER-PANE-ANCHOR", restored)
        self.assertIn("\x1b[", restored)

    def test_conway_four_generations_translate_up_left_and_bounce(self):
        """The glider is a genuine B3/S23 oscillator: four ticks = (-1,-1)."""
        expression = """(let* ((start (elmtui.examples.tmux-glider:initial-grid 40 20))
                  (grid start))
           (dotimes (step 4)
             (setf grid (elmtui.examples.tmux-glider:life-step grid)))
           (assert (= 5 (elmtui.examples.tmux-glider:population grid)))
           (dotimes (y 20)
             (dotimes (x 40)
               (when (= 1 (aref start y x))
                 (assert (= 1 (aref grid (1- y) (1- x)))))))
           (let ((border (elmtui.examples.tmux-glider:initial-grid 8 30))
                 (direction -1)
                 (bounced nil))
             (dotimes (i 16)
               (multiple-value-bind (next dir)
                   (elmtui.examples.tmux-glider::%advance border direction)
                 (when (plusp dir) (setf bounced t))
                 (setf border next direction dir)))
             (assert bounced))
           (format t "GLIDER-GOL-PARITY-PASS~%"))"""
        proc = subprocess.run(
            ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
             "--noinform", "--non-interactive",
             "--eval", '(asdf:load-system "elmtui")',
             "--load", "examples/tmux-glider.lisp",
             "--eval", expression],
            cwd=ROOT, text=True, capture_output=True, timeout=30)
        self.assertEqual(proc.returncode, 0, proc.stderr[-2000:])
        self.assertIn("GLIDER-GOL-PARITY-PASS", proc.stdout)

    def test_underlay_restoration_preserves_sgr_cell_style(self):
        expression = r"""(let* ((cells (make-array '(2 2) :initial-element
                           (cons #\Space nil)))
                  (snapshot (list :width 2 :height 2 :cells cells)))
            (setf (aref cells 0 0)
                  (cons #\X '(:fg :red :bg :blue :attrs (:bold))))
            (let ((rendered
                     (with-output-to-string (*standard-output*)
                       (elmtui.examples.tmux-glider::%draw-point
                        snapshot '(0 0) nil))))
              (assert (search (format nil "~C[31m" #\Escape) rendered))
              (assert (search (format nil "~C[44m" #\Escape) rendered))
              (assert (find #\X rendered)))
            (format t "GLIDER-SGR-RESTORE-PASS~%"))"""
        proc = subprocess.run(
            ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
             "--noinform", "--non-interactive",
             "--eval", '(asdf:load-system "elmtui")',
             "--load", "examples/tmux-glider.lisp",
             "--eval", expression],
            cwd=ROOT, text=True, capture_output=True, timeout=30)
        self.assertEqual(proc.returncode, 0, proc.stderr[-2000:])
        self.assertIn("GLIDER-SGR-RESTORE-PASS", proc.stdout)

    def test_finite_generation_exit_restores_original_pane(self):
        app = self.app("tmux-glider-finite",
                       "(elmtui.examples.tmux-glider:run-tmux-glider :speed 0.06 :frames 6)",
                       prelude='printf "PRESERVE-ME-EXACTLY\\n"')
        self.await_exit(app)
        self.assertIn("PRESERVE-ME-EXACTLY", app.screen())
        self.assertNotIn("█", app.screen())
        raw = (app.directory / "terminal.raw").read_bytes()
        for destructive_escape in (b"\x1b[?1049h", b"\x1b[2J", b"\x1b[3J"):
            self.assertNotIn(destructive_escape, raw,
                             "Tmux glider must never clear or switch the pane")

    def test_fails_closed_without_tmux(self):
        env = dict(os.environ)
        env.pop("TMUX", None)
        env.pop("TMUX_PANE", None)
        result = subprocess.run([str(ROOT / "run-glider.sh")], cwd=ROOT, env=env,
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 2)
        self.assertIn("requires a live tmux pane", result.stderr)
        self.assertNotIn("\x1b[", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
