#!/usr/bin/env python3
"""Real private-tmux Ctrl+S, dirty state and normal-screen restoration gate."""

import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "elmtui_release_terminal", ROOT / "scripts/test-terminal-apps.py")
terminal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(terminal)


class Options:
    terminal = "tmux"
    timeout = 15
    output = Path(tempfile.mkdtemp(prefix="elmtui-release-mini-editor-"))


class MiniEditorSavePTY(unittest.TestCase):
    def test_ctrl_s_persists_and_clears_dirty_state(self):
        terminal.OPTIONS = Options()
        with tempfile.TemporaryDirectory(prefix="elmtui-editor-file-") as directory:
            target = Path(directory) / "saved.txt"
            app = terminal.TerminalApp(
                "release-editor-save",
                "(elmtui.examples.mini-text-editor:run-mini-text-editor)",
                source="mini-text-editor.lisp",
                use_launcher=False,
                environment={"ELMTUI_EDITOR_FILE": str(target)},
            )
            self.addCleanup(app.close)
            app.start()
            app.expect("Mini Text Editor")
            pane_tty = app.tmux("display-message", "-p", "-t", "app:0.0",
                               "#{pane_tty}").stdout.strip()
            tty_flags = subprocess.run(["stty", "-F", pane_tty, "-a"],
                                       text=True, capture_output=True,
                                       check=True).stdout
            self.assertIn("-ixon", tty_flags, "Ctrl+S must not be swallowed by XOFF")
            app.key("a", literal=True)
            app.wait(lambda screen: "saved.txt *" in screen,
                     "editor marks the unsaved buffer")
            app.key("C-s")
            app.wait(lambda screen: "Saved" in screen and "saved.txt *" not in screen,
                     "saved version clears the dirty marker")
            self.assertEqual(target.read_text(encoding="utf-8"), "a")
            app.key("C-q")
            app.wait(lambda screen: "ELMTUI_E2E_SHELL_RESTORED" in screen,
                     "clean exit restores the shell")
            self.assertEqual("0", (app.directory / "exit-code").read_text().strip())
            self.assertEqual(
                (app.directory / "before.stty").read_text(),
                (app.directory / "after.stty").read_text(),
                "terminal modes must be restored exactly")
            self.assertEqual(
                "1", app.tmux("display-message", "-p", "-t", "app:0.0",
                              "#{cursor_flag}").stdout.strip(),
                "cursor must be visible after exit")
            raw = (app.directory / "terminal.raw").read_bytes()
            self.assertNotIn(bytes((27,)) + b"[?1049h", raw)
            self.assertNotIn(bytes((27,)) + b"[?1049l", raw)
            # Quicklisp Log4CL emits these three known declaration warnings
            # before ElmTUI starts. Reject any additional diagnostics.
            allowed_warnings = {
                "WARNING: redefining LOG4CL-IMPL:APPENDER-ADDED in DEFGENERIC",
                "WARNING: redefining LOG4CL-IMPL:APPENDER-REMOVED in DEFGENERIC",
                "WARNING: redefining LOG4CL-IMPL::PROPERTY-ALIST in DEFGENERIC",
            }
            stderr = (app.directory / "stderr.txt").read_text()
            unexpected = set(stderr.splitlines()) - allowed_warnings - {""}
            self.assertFalse(unexpected, f"Unexpected runtime diagnostics: {unexpected}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
