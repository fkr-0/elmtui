#!/usr/bin/env python3
"""Normal-buffer tmux review contracts.

Default run exercises executable API docs, SGR parsing and the hard prohibition
on alternate-screen mode. The two intentionally RED integration contracts
require ELMTUI_STRICT_TMUX_ACCEPTANCE=1: the real physical B2 focus box and
lossless reverse resize. Their explicit opt-in prevents a known blocked
feature from silently breaking unrelated CI while retaining a runnable
release qualification gate. A skipped strict test is NEVER a release PASS.

Run:
  python3 tests/e2e/example-overhaul-tmux-review-contracts.py
  ELMTUI_STRICT_TMUX_ACCEPTANCE=1 python3 tests/e2e/example-overhaul-tmux-review-contracts.py
"""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
HARNESS = ROOT / "scripts" / "test-terminal-apps.py"
spec = importlib.util.spec_from_file_location("tmux_review_harness", HARNESS)
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)
STRICT = os.environ.get("ELMTUI_STRICT_TMUX_ACCEPTANCE") == "1"


class Options:
    terminal = "tmux"
    timeout = 19
    output = None


def lisp_check(form):
    result = subprocess.run(
        ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
         "--noinform", "--non-interactive",
         "--eval", '(asdf:load-system "elmtui-examples")',
         "--eval", form],
        cwd=ROOT, capture_output=True, text=True, timeout=45)
    if result.returncode != 0:
        raise AssertionError(
            "Lisp contract failed.\n"
            + result.stdout[-1200:] + "\n" + result.stderr[-2200:])


class DocumentationAndStyle(unittest.TestCase):
    def test_docstrings_disclose_viewport_and_preview_limits(self):
        lisp_check(r"""(progn
          (flet ((must-document (symbol fragment)
                   (let ((doc (documentation symbol 'function)))
                     (assert (and (stringp doc) (search fragment doc))))))
            (must-document 'elmtui.platform.tmux:save-tmux-capture "scrollback")
            (must-document 'elmtui.platform.tmux:restore-to-tmux-capture "physical")
            (must-document 'elmtui.platform.tmux:prefill-backend-from-tmux "resize-safe")
            (must-document 'elmtui-examples.cursor-inspector::%b2-focus-rows "PREVIEW")
            (must-document 'elmtui-examples.cursor-inspector::%style-at "SGR")
            (must-document 'elmtui-examples.cursor-inspector::%display-width "columns")))""")

    def test_inspector_sgr_rgb_palette_and_wide_cell(self):
        lisp_check(r"""(progn
          (let* ((raw (format nil "~C[38;2;12;34;56;48;5;77mA界B~C[0m"
                              #\Escape #\Escape))
                 (style0 (elmtui-examples.cursor-inspector::%style-at raw 0))
                 (style1 (elmtui-examples.cursor-inspector::%style-at raw 1))
                 (style2 (elmtui-examples.cursor-inspector::%style-at raw 2)))
            (assert (equal (getf style0 :fg) '(:rgb 12 34 56)))
            (assert (equal (getf style0 :bg) '(:256 77)))
            (assert (equal (getf style1 :fg) (getf style2 :fg)))
            (assert (= 4 (elmtui-examples.cursor-inspector:%display-width "A界B"))))
          (let ((rows (elmtui-examples.cursor-inspector::%b2-focus-rows
                        "ABCDEFGH" 5)))
            (assert (char= (char (second rows) 5) #\F))
            (assert (string= (subseq (first rows) 4 7) "┌─┐"))
            (assert (string= (subseq (third rows) 4 7) "└─┘"))))""")

    def test_alternate_mode_rejected_before_any_backend_io(self):
        lisp_check(r"""(let ((elmtui.platform.driver::*backend* :untouched)
                          (elmtui.platform.driver::*app-spec* :untouched))
          (handler-case
              (progn
                (elmtui.platform.driver:run-app-platform
                  nil :backend-type :terminal
                  :platform-options '(:use-alternate-screen t))
                (error "Alternate mode erroneously accepted"))
            (error (condition)
              (assert (search "does not support alternate-screen"
                              (princ-to-string condition)))))
          (assert (eq elmtui.platform.driver::*backend* :untouched))
          (assert (eq elmtui.platform.driver::*app-spec* :untouched)))""")


@unittest.skipUnless(
    STRICT, "P0 release gate (enable ELMTUI_STRICT_TMUX_ACCEPTANCE=1); skip is NOT approval"
)
class PhysicalOverlayAndScrollbackAcceptance(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="elmtui-tmux-acceptance-")
        Options.output = Path(cls.tmp.name)
        harness.OPTIONS = Options()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_b2_surrounds_exact_real_pane_cell(self):
        """B2 must paint actual screen coordinates (5,6), not a panel preview."""
        gate = Options.output / "physical-b2.start"
        prelude = (
            'for n in $(seq -w 1 70); do printf "HISTORY-MARKER-%s\\n" "$n"; done\n'
            'for n in $(seq -w 1 24); do printf "VISIBLE-ROW-%s-ABCDEFGHIJKLMN\\n" "$n"; done\n'
            f'until test -e "{gate}"; do sleep .05; done'
        )
        app = harness.TerminalApp(
            "physical-b2",
            "(elmtui-examples.tmux-hover-demo:run-tmux-hover-demo)",
            prelude=prelude, use_launcher=False)
        try:
            app.start()
            app.expect("VISIBLE-ROW-24")
            before = app.tmux("capture-pane", "-p", "-t", "app:0.0").stdout.splitlines()
            self.assertGreaterEqual(len(before), 8)
            self.assertGreaterEqual(len(before[6]), 7)
            old_glyph = before[6][5]
            gate.touch()
            app.expect("B1 / GLYPH + STYLE")
            for _ in range(5):
                app.key("Right")
            for _ in range(6):
                app.key("Down")
            app.expect("Cursor: (5, 6)")
            after = app.tmux("capture-pane", "-p", "-t", "app:0.0").stdout.splitlines()
            self.assertEqual(after[5][4:7], "┌─┐", "B2 top border at real pane cell")
            self.assertEqual(after[6][4:7], f"│{old_glyph}│",
                             "B2 target must retain its own captured glyph")
            self.assertEqual(after[7][4:7], "└─┘", "B2 bottom border at real pane cell")
            raw = (app.directory / "terminal.raw").read_bytes()
            for suffix in (b"1049h", b"1049l", b"1047h", b"1047l", b"47h", b"47l"):
                self.assertNotIn(b"\x1b[?" + suffix, raw)
        finally:
            app.close()

    def test_shrink_120x40_to_80x24_preserves_all_history(self):
        """No historical row may disappear when the physical screen shrinks."""
        gate = Options.output / "reverse-shrink.start"
        prelude = (
            'for n in $(seq -w 1 70); do printf "HISTORY-MARKER-%s\\n" "$n"; done\n'
            'printf "UNDERLAY-ALPHA\\nUNDERLAY-BETA\\n"\n'
            f'until test -e "{gate}"; do sleep .05; done'
        )
        app = harness.TerminalApp(
            "reverse-shrink",
            "(elmtui-examples.tmux-hover-demo:run-tmux-hover-demo)",
            prelude=prelude, use_launcher=False)
        try:
            app.start()
            app.tmux("resize-window", "-t", "app:0", "-x", "120", "-y", "40")
            app.expect("UNDERLAY-BETA")
            def history():
                return app.tmux("capture-pane", "-p", "-S", "-", "-t", "app:0.0").stdout
            baseline = history()
            self.assertEqual(baseline.count("HISTORY-MARKER-"), 70)
            gate.touch()
            app.expect("B1 / GLYPH + STYLE")
            app.key("Right")
            app.expect("Cursor: (1, 0)")
            app.key("s", literal=True)
            app.expect("SCROLLBACK")
            app.key("p", literal=True)
            app.expect("PANE")
            app.key("r", literal=True)
            app.expect("tmux capture refreshed")
            app.tmux("resize-window", "-t", "app:0", "-x", "80", "-y", "24")
            app.key("q", literal=True)
            app.wait(lambda screen: "ELMTUI_E2E_SHELL_RESTORED" in screen,
                     "shell restored after reverse shrink")
            restored = history()
            missing = [n for n in range(1, 71)
                       if restored.count(f"HISTORY-MARKER-{n:02d}") != 1]
            self.assertEqual(missing, [],
                "All 70 historical lines must survive exactly once, not just be repainted")
            self.assertEqual(restored.count("UNDERLAY-ALPHA"), 1)
            self.assertEqual(restored.count("UNDERLAY-BETA"), 1)
            self.assertEqual((app.directory / "before.stty").read_text(),
                             (app.directory / "after.stty").read_text())
            raw = (app.directory / "terminal.raw").read_bytes()
            self.assertNotIn(b"\x1b[?1049h", raw)
        finally:
            app.close()


if __name__ == "__main__":
    unittest.main(verbosity=2)
