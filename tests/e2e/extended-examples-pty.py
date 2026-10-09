#!/usr/bin/env python3
"""Private-PTY integration coverage for under-tested maintained examples.

Evidence remains under /tmp/elmtui-extended-evidence-20261009.
Run: python3 tests/e2e/extended-examples-pty.py
"""
import importlib.util
from pathlib import Path
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "elmtui_extended_harness", ROOT / "scripts" / "test-terminal-apps.py")
terminal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(terminal)


class Options:
    terminal = "tmux"
    timeout = 12
    output = Path("/tmp/elmtui-extended-evidence-20261009")


class ExtendedExamplesPTY(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        Options.output.mkdir(parents=True, exist_ok=True)
        terminal.OPTIONS = Options()

    def launch(self, name, expression, source):
        app = terminal.TerminalApp(
            name, expression, source=source, use_launcher=False)
        self.addCleanup(app.close)
        return app.start()

    def exit_cleanly(self, app, key=None):
        if key is not None:
            app.key(key, literal=(len(key) == 1))
        app.wait(lambda screen: "ELMTUI_E2E_SHELL_RESTORED" in screen,
                 "shell resumed after normal exit")
        self.assertEqual((app.directory / "exit-code").read_text().strip(), "0")
        self.assertEqual((app.directory / "before.stty").read_text(),
                         (app.directory / "after.stty").read_text())
        self.assertEqual(
            app.tmux("display-message", "-p", "-t", "app:0.0",
                     "#{cursor_flag}").stdout.strip(), "1")
        errors = (app.directory / "stderr.txt").read_text(errors="replace")
        self.assertNotRegex(errors, r"Unhandled|fatal error|undefined function")

    def test_finder_filters_and_selects(self):
        app = self.launch(
            "finder", "(elmtui.examples.fzf-finder:run-fzf-finder)",
            "fzf-finder-real.lisp")
        app.expect("alpha")
        app.key("b", literal=True)
        app.key("e", literal=True)
        app.expect("Find: be")
        app.expect("beta")
        self.assertNotIn("alpha", app.screen())
        self.exit_cleanly(app, "Enter")

    @unittest.expectedFailure  # Visible-item rendering is a tracked regression.
    def test_input_selector_filters_and_escapes(self):
        app = self.launch(
            "selector",
            "(elmtui.examples.input-selector:run-input-selector-app)",
            "input-selector.lisp")
        app.expect("Option 1")
        for char in "banana":
            app.key(char, literal=True)
        app.expect("Banana")
        self.exit_cleanly(app, "Escape")

    @unittest.expectedFailure  # View is blank; no animation proof yet.
    def test_glider_animation_and_exit(self):
        app = self.launch(
            "glider",
            "(elmtui.examples.glider:run-glider-animation)",
            "glider-real.lisp")
        screen = app.expect("glider-real: q/esc quit")
        self.assertIn("tick=", screen)
        self.exit_cleanly(app, "q")

    @unittest.expectedFailure  # Inspector UI is blank in a real tmux pane.
    def test_cursor_inspector_visible_and_exit(self):
        app = self.launch(
            "cursor-inspector",
            "(elmtui-examples.cursor-inspector:run-cursor-inspector)",
            "cursor-inspector.lisp")
        app.wait(lambda screen: "Snapshot lines:" in screen
                 or "Controls:" in screen
                 or "tmux is not available." in screen,
                 "inspector panel is visible")
        self.exit_cleanly(app, "q")

    def test_inline_pong_render_and_quit(self):
        app = self.launch(
            "pong",
            "(elmtui.examples.pong-below-cursor:run-pong-below-cursor)",
            "pong-below-cursor.lisp")
        app.expect("pong | score:")
        app.expect("controls: left/right")
        app.key("Right")
        self.exit_cleanly(app, "q")

    def test_root_viewport_exit_via_escape(self):
        app = self.launch(
            "root-viewport",
            "(elmtui.examples.root-viewport-test-app:run-root-viewport-test-app)",
            "root-viewport-test-app.lisp")
        app.expect("Arrows move the block")
        app.key("Right")
        app.key("Down")
        self.exit_cleanly(app, "Escape")

    def test_mini_editor_unsaved_dialog(self):
        app = self.launch(
            "editor",
            "(elmtui.examples.mini-text-editor:run-mini-text-editor)",
            "mini-text-editor.lisp")
        app.expect("Mini Text Editor")
        app.key("a", literal=True)
        app.wait(lambda screen: "Mini Text Editor | [scratch] *" in screen,
                 "editor marks modified buffer")
        time.sleep(0.6)
        self.assertFalse((app.directory / "exit-code").exists(),
                         "typing must not exit editor")
        app.key("Escape")
        app.expect("Unsaved changes")
        app.key("d", literal=True)
        self.exit_cleanly(app)


    @unittest.expectedFailure  # Reported q shortcut does not exit reliably.
    def test_root_viewport_q_exit(self):
        app = self.launch(
            "root-viewport-q",
            "(elmtui.examples.root-viewport-test-app:run-root-viewport-test-app)",
            "root-viewport-test-app.lisp")
        app.expect("Arrows move the block")
        self.exit_cleanly(app, "q")

    @unittest.expectedFailure  # Ctrl+Q must not bypass unsaved-changes dialog.
    def test_mini_editor_ctrl_q_prompts_when_dirty(self):
        app = self.launch(
            "editor-ctrl-q",
            "(elmtui.examples.mini-text-editor:run-mini-text-editor)",
            "mini-text-editor.lisp")
        app.expect("Mini Text Editor")
        app.key("a", literal=True)
        app.wait(lambda screen: "Mini Text Editor | [scratch] *" in screen,
                 "dirty editor before Ctrl+Q")
        app.key("C-q")
        app.expect("Unsaved changes")


if __name__ == "__main__":
    unittest.main(verbosity=2)
