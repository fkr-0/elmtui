#!/usr/bin/env python3
"""Smoke a packaged ElmTUI executable through a private tmux PTY.

Usage: python3 tests/e2e/release-gate-binary-pty.py /path/to/minimal-binary
The binary should be an independently built minimal-app executable.
"""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests/workbench/independent"))
from pty_driver import PrivateTmuxPTY


class PackagedBinarySmoke(unittest.TestCase):
    def test_binary_renders_handles_keys_and_restores(self):
        self.assertEqual(len(sys.argv), 1)
        binary = BINARY
        self.assertTrue(binary.is_file(), str(binary))
        with PrivateTmuxPTY([str(binary)], cwd=binary.parent,
                            cols=100, rows=35, timeout=20) as tty:
            tty.wait_for("Hello slurp", timeout=20)
            tty.send_text("x")
            tty.wait_for("Hello X", timeout=10)
            tty.send_key("C-q")
            code, restored = tty.wait_for_exit(timeout=12)
            self.assertEqual(code, 0)
            self.assertTrue(restored, "termios must be restored")
            self.assertNotIn("Hello X", tty.capture())


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: release-gate-binary-pty.py /path/to/minimal-binary")
    BINARY = Path(sys.argv.pop()).resolve()
    unittest.main(verbosity=2)
