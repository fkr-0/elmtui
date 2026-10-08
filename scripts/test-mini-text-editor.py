#!/usr/bin/env python3
"""End-to-end mini text editor tests through the existing isolated-tmux harness."""
from __future__ import annotations

import argparse
import importlib.util
import json
import re
from pathlib import Path
import sys
import tempfile
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "terminal_apps", ROOT / "scripts/test-terminal-apps.py"
)
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)


class EditorApps(unittest.TestCase):
    def app(self, name, *, initial=None):
        path = harness.OPTIONS.output / (name + "-" + uuid.uuid4().hex[:8] + ".txt")
        if initial is not None:
            path.write_text(initial, encoding="utf-8")
        app = harness.TerminalApp(
            name,
            "(elmtui.examples.mini-text-editor:run-mini-text-editor)",
            source="mini-text-editor.lisp",
            environment={"ELMTUI_EDITOR_FILE": str(path)},
        )
        self.addCleanup(app.close)
        return app.start(), path

    def finish(self, app, key):
        """Preserve all terminal restoration checks; permit only known upstream log4cl warnings."""
        try:
            app.finish(key)
        except AssertionError as error:
            if "Compiler/runtime diagnostic in stderr:" not in str(error):
                raise
            errors = (app.directory / "stderr.txt").read_text(errors="replace")
            unexpected = [line for line in errors.splitlines() if line.strip() and not
                          re.fullmatch(r"WARNING: redefining LOG4CL-IMPL:(?::)?[A-Z-]+ in DEFGENERIC", line)]
            self.assertFalse(unexpected, f"Unexpected runtime diagnostics: {unexpected}")

    def test_edit_insert_newline_and_save(self):
        app, path = self.app("editor-file", initial="first\nsecond")
        app.expect("Mini Text Editor")
        app.expect("first")
        app.key("End")
        app.key("!", literal=True)
        app.key("Enter")
        app.key("x", literal=True)
        app.key("C-s")
        app.expect("Saved")
        self.assertEqual(path.read_text(encoding="utf-8"), "first!\nx\nsecond")
        self.finish(app, "C-q")
        self.assertEqual(path.read_text(encoding="utf-8"), "first!\nx\nsecond")

    def test_navigation_delete_and_unicode_save(self):
        app, path = self.app("editor-navigation", initial="alpha\nbeta\ngamma")
        app.expect("Mini Text Editor")
        app.key("Down")
        app.key("End")
        app.key("BSpace")
        app.key("Home")
        app.key("Delete")
        app.key(chr(233), literal=True)
        app.key("C-s")
        app.expect("Saved")
        self.assertEqual(path.read_text(encoding="utf-8"), "alpha\n" + chr(233) + "et\ngamma")
        self.finish(app, "C-q")

    def test_dirty_quit_requires_confirmation(self):
        app, path = self.app("editor-discard")
        app.expect("Mini Text Editor")
        app.key("z", literal=True)
        app.expect("Modified")
        app.key("C-q")
        app.expect("Unsaved changes")
        self.assertNotIn("ELMTUI_E2E_SHELL_RESTORED", app.screen())
        self.finish(app, "C-q")
        self.assertFalse(path.exists(), "discard must not save the buffer")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeout", type=float, default=20.0)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    args.output = (args.output or Path(tempfile.mkdtemp(prefix="mini-editor-e2e-"))).resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    harness.OPTIONS = argparse.Namespace(
        output=args.output, timeout=args.timeout, terminal="tmux"
    )
    result = unittest.TextTestRunner(verbosity=2).run(
        unittest.defaultTestLoader.loadTestsFromTestCase(EditorApps)
    )
    (args.output / "result.json").write_text(json.dumps({
        "tests": result.testsRun,
        "failures": len(result.failures),
        "errors": len(result.errors),
        "successful": result.wasSuccessful(),
    }, indent=2) + "\n")
    print("Artifacts:", args.output)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
