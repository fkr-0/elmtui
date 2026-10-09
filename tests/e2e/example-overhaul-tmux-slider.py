#!/usr/bin/env python3
"""EX-10 private tmux/PTY and reproducible animated-overlay contract tests.

Runs the real CLPM/SBCL driver in an isolated tmux server. This file intentionally
does not alter the shared test harness or examples manifest.
"""
import importlib.util
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
HARNESS = ROOT / "scripts" / "test-terminal-apps.py"
spec = importlib.util.spec_from_file_location("elmtui_slider_harness", HARNESS)
terminal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(terminal)


class Options:
    terminal = "tmux"
    timeout = 18
    output = None


class SliderPTY(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="elmtui-slider-pty-")
        Options.output = Path(cls.tmp.name)
        terminal.OPTIONS = Options()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def launch(self, name, expression, *, prelude=""):
        app = terminal.TerminalApp(name, expression, source="tmux-slider.lisp",
                                   prelude=prelude, use_launcher=False)
        self.addCleanup(app.close)
        app.start()
        return app

    def wait_for_overlay(self, app):
        """Observe real rendered SGR output while rejecting alternate screen."""
        deadline = time.monotonic() + Options.timeout
        while time.monotonic() < deadline:
            raw_path = app.directory / "terminal.raw"
            raw = raw_path.read_bytes() if raw_path.exists() else b""
            self.assertNotIn(b"\x1b[?1049h", raw, "Slider entered alternate mode")
            self.assertNotIn(b"\x1b[2J", raw, "Slider cleared pane contents")
            if b"\x1b[0;1;38;2;235;255;255;48;2;16;126;182m" in raw:
                return raw
            if (app.directory / "exit-code").exists():
                self.fail("Slider exited before first painted frame: " +
                          (app.directory / "stderr.txt").read_text()[-1800:])
            time.sleep(.08)
        self.fail("No in-place frame produced; stderr: " +
                  (app.directory / "stderr.txt").read_text()[-1800:])

    def await_exit(self, app):
        deadline = time.monotonic() + Options.timeout
        while time.monotonic() < deadline:
            if "ELMTUI_E2E_SHELL_RESTORED" in app.screen():
                break
            time.sleep(.08)
        else:
            self.fail("Shell was not restored on exit")
        self.assertEqual((app.directory / "exit-code").read_text().strip(), "0")
        self.assertEqual((app.directory / "before.stty").read_text(),
                         (app.directory / "after.stty").read_text())
        self.assertEqual(app.tmux("display-message", "-p", "-t", "app:0.0",
                                  "#{cursor_flag}").stdout.strip(), "1")

    def test_real_styled_snapshot_and_70_scrollback_markers(self):
        permit = Options.output / "permit"
        prelude = (
            'for n in $(seq -w 1 70); do printf "HISTORY-MARKER-%s\\n" "$n"; done\n'
            'printf "\\033[38;5;196mSTYLED-UNDERLAY-RED\\033[0m\\n"\n'
            'printf "VISIBLE-BOTTOM-ANCHOR\\n"\n'
            f'until test -f "{permit}"; do sleep .05; done'
        )
        app = self.launch("slider-history",
                          "(elmtui.examples.tmux-slider:run-tmux-slider)",
                          prelude=prelude)
        app.expect("VISIBLE-BOTTOM-ANCHOR")
        old_plain = app.tmux("capture-pane", "-p", "-S", "-",
                             "-t", "app:0.0").stdout
        old_style = app.tmux("capture-pane", "-p", "-e", "-S", "-",
                             "-t", "app:0.0").stdout
        self.assertEqual(old_plain.count("HISTORY-MARKER-"), 70)
        self.assertIn("STYLED-UNDERLAY-RED", old_plain)
        self.assertIn("\x1b[", old_style)
        permit.touch()
        self.wait_for_overlay(app)
        images = []
        deadline = time.monotonic() + 7
        while time.monotonic() < deadline and len(images) < 6:
            screen = app.tmux("capture-pane", "-p", "-e",
                              "-t", "app:0.0").stdout
            if not images or screen != images[-1]:
                images.append(screen)
            time.sleep(.12)
        self.assertGreaterEqual(len(images), 6, "At least five transitions required; first=" + repr(images[0][:500]) + " raw=" + repr((app.directory / "terminal.raw").read_bytes()[-400:]))
        self.assertTrue(all("VISIBLE-BOTTOM-ANCHOR" in re.sub(r"\x1b\[[0-9;]*m", "", frame) for frame in images[1:]),
                        "Slider must display full original glyphs while animating: " + repr(images[-1][-600:]))
        app.key("q", literal=True)
        self.await_exit(app)
        after = app.tmux("capture-pane", "-p", "-e", "-S", "-",
                         "-t", "app:0.0").stdout
        after_plain = app.tmux("capture-pane", "-p", "-S", "-",
                               "-t", "app:0.0").stdout
        for n in range(1, 71):
            self.assertIn(f"HISTORY-MARKER-{n:02d}", after_plain)
        self.assertEqual(after_plain.count("HISTORY-MARKER-"), 70)
        self.assertIn("STYLED-UNDERLAY-RED", after_plain)
        self.assertIn("VISIBLE-BOTTOM-ANCHOR", after_plain)
        self.assertNotIn("SLIDER-ROW", after_plain)
        self.assertIn("\x1b[", after)

    def test_pause_has_no_output(self):
        app = self.launch("slider-pause",
                          "(elmtui.examples.tmux-slider:run-tmux-slider)",
                          prelude='printf "SLIDER-PAUSE-UNDERLAY\\n"')
        self.wait_for_overlay(app)
        time.sleep(.7)
        app.key("Space")
        time.sleep(.35)  # in-flight tick cancellation/grace period
        before = (app.directory / "terminal.raw").stat().st_size
        time.sleep(.7)
        after = (app.directory / "terminal.raw").stat().st_size
        self.assertEqual(before, after, "Paused loop wrote terminal bytes")
        app.key("q", literal=True)
        self.await_exit(app)

    def test_deterministic_finite_frames(self):
        app = self.launch("slider-finite",
                          "(elmtui.examples.tmux-slider:run-tmux-slider :frames 8)",
                          prelude='printf "SLIDER-FINITE-UNDERLAY\\n"')
        self.wait_for_overlay(app)
        self.await_exit(app)
        self.assertIn("SLIDER-FINITE-UNDERLAY", app.screen())

    def test_lossless_history_on_early_exit(self):
        """The alternate-screen lifecycle must not displace main scrollback."""
        gate = Options.output / "restore-gate"
        prelude = (
            'for n in $(seq -w 1 75); do printf "EX10-HISTORY-%s\\n" "$n"; done\n'
            'printf "\\033[38;5;196mEX10-STYLED-RED\\033[0m\\n"\n'
            'printf "EX10-VISIBLE-UNDERLAY\\n"\n'
            f'until test -f "{gate}"; do sleep .05; done'
        )
        app = self.launch("slider-early-restore",
                          "(elmtui.examples.tmux-slider:run-tmux-slider)",
                          prelude=prelude)
        app.expect("EX10-VISIBLE-UNDERLAY")
        original = app.tmux("capture-pane", "-p", "-e", "-S", "-",
                             "-t", "app:0.0").stdout
        self.assertEqual(original.count("EX10-HISTORY-"), 75)
        self.assertIn("EX10-STYLED-RED", original)
        gate.touch()
        self.wait_for_overlay(app)
        app.key("Escape")
        self.await_exit(app)
        restored = app.tmux("capture-pane", "-p", "-e", "-S", "-",
                            "-t", "app:0.0").stdout
        self.assertEqual(restored.count("EX10-HISTORY-"), 75)
        for n in range(1, 76):
            self.assertIn(f"EX10-HISTORY-{n:02d}", restored)
        self.assertIn("EX10-VISIBLE-UNDERLAY", restored)
        self.assertIn("EX10-STYLED-RED", restored)
        self.assertNotIn("TMUX / CYAN SHIFT", restored)

    def test_without_tmux_is_safe(self):
        env = os.environ.copy()
        env.pop("TMUX", None)
        env.pop("TMUX_PANE", None)
        result = subprocess.run(
            ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
             "--noinform", "--non-interactive",
             "--eval", '(asdf:load-system "elmtui")',
             "--load", "examples/tmux-slider.lisp",
             "--eval", "(elmtui.examples.tmux-slider:run-tmux-slider)"],
            cwd=ROOT, env=env, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr[-1200:])
        self.assertIn("requires a live tmux pane", result.stderr)
        self.assertNotIn("\x1b[?1049", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
