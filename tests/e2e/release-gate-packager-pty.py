#!/usr/bin/env python3
"""Build a maintained example binary and smoke its real PTY startup.

A redirected non-PTY invocation is NOT a valid terminal-runtime qualification.
"""
import importlib.util
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests/workbench/independent"))
from pty_driver import PrivateTmuxPTY


class PackageExamplePTY(unittest.TestCase):
    @unittest.skipUnless(PrivateTmuxPTY.available() and shutil.which("clpm"),
                         "tmux and CLPM required")
    def test_build_and_start_minimal_binary_under_private_tmux(self):
        with tempfile.TemporaryDirectory(prefix="elmtui-packager-pty-") as temp:
            binary = Path(temp) / "minimal"
            built = subprocess.run(
                ["./scripts/examples.sh", "build", "minimal-app", str(binary)],
                cwd=ROOT, capture_output=True, text=True, timeout=60)
            self.assertEqual(0, built.returncode, built.stderr[-3500:])
            self.assertTrue(binary.is_file())
            with PrivateTmuxPTY([str(binary)], cols=100, rows=35,
                                timeout=12) as terminal:
                rendered = terminal.wait_for("Hello slurp", timeout=12)
                self.assertIn("Hello slurp", rendered)


if __name__ == "__main__":
    unittest.main(verbosity=2)
