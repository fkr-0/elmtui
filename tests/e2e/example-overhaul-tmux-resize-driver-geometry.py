#!/usr/bin/env python3
"""Verify normal-buffer restore follows actual tmux pane dimensions after resize."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("tmux_resize_driver_harness",
                                               ROOT / "scripts/test-terminal-apps.py")
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)


class Options:
    terminal = "tmux"
    timeout = 16
    output = None


RUNNER = r"""(progn
  (let ((restore (symbol-function 'elmtui.platform.driver::%restore-saved-tmux-capture-on-backend)))
    (setf (symbol-function 'elmtui.platform.driver::%restore-saved-tmux-capture-on-backend)
      (lambda (backend)
        (let ((result (funcall restore backend)))
          (format *error-output* "RESIZE_RESTORE_GEOMETRY ~Dx~D~%"
            (elmtui.platform.api:term-w backend)
            (elmtui.platform.api:term-h backend))
          result))))
  (elmtui-examples.tmux-hover-demo:run-tmux-hover-demo))"""


class PhysicalTmuxGeometry(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dir = tempfile.TemporaryDirectory(prefix="elmtui-real-tmux-geometry-")
        Options.output = Path(cls.dir.name)
        harness.OPTIONS = Options()

    @classmethod
    def tearDownClass(cls):
        cls.dir.cleanup()

    def test_live_pane_not_stale_device_size(self):
        for start, end in [((80, 24), (120, 40)), ((120, 40), (80, 24))]:
            with self.subTest(initial=start, final=end):
                app = harness.TerminalApp("geom-%dx%d" % start, RUNNER,
                    prelude='printf "GEOMETRY-UNDERLAY\n"', use_launcher=False)
                try:
                    app.start()
                    app.tmux("resize-window", "-t", "app:0", "-x",
                             str(start[0]), "-y", str(start[1]))
                    app.expect("tmux-hover-demo [TMUX]")
                    app.tmux("resize-window", "-t", "app:0", "-x",
                             str(end[0]), "-y", str(end[1]))
                    app.key("q", literal=True)
                    app.wait(lambda screen: "ELMTUI_E2E_SHELL_RESTORED" in screen,
                             "shell restored")
                    stderr = (app.directory / "stderr.txt").read_text()
                    self.assertIn(f"RESIZE_RESTORE_GEOMETRY {end[0]}x{end[1]}", stderr)
                    self.assertEqual((app.directory / "exit-code").read_text().strip(), "0")
                    raw = (app.directory / "terminal.raw").read_bytes()
                    for seq in (b"\x1b[?1049h", b"\x1b[?1049l"):
                        self.assertNotIn(seq, raw)
                finally:
                    app.close()


if __name__ == "__main__":
    unittest.main(verbosity=2)
