#!/usr/bin/env python3
"""Check the public example launcher does not pollute the terminal at startup."""
from pathlib import Path
import json
import subprocess
import unittest

ROOT = Path(__file__).resolve().parent.parent


class StartupOutput(unittest.TestCase):
    def test_fresh_process_list_is_quiet(self):
        result = subprocess.run(
            [str(ROOT / "scripts/examples.sh"), "list"], cwd=ROOT,
            text=True, capture_output=True, timeout=60,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        self.assertIn("wifi-menu", result.stdout.splitlines())
        self.assertNotIn("compiling file", result.stdout)
        self.assertNotIn("Running example", result.stdout)

    def test_unrelated_warnings_are_visible(self):
        # Emit the sentinel inside the loader's handler scope, through the
        # ASDF entry point it invokes, rather than after that scope ends.
        loader = json.dumps(str(ROOT / "scripts/load-examples-cli.lisp"))
        expression = f'''(let ((original (symbol-function 'asdf:load-system)))
          (unwind-protect
              (progn
                (setf (symbol-function 'asdf:load-system)
                      (lambda (&rest args)
                        (declare (ignore args))
                        (warn "STARTUP-WARNING-SENTINEL")))
                (load {loader}))
            (setf (symbol-function 'asdf:load-system) original)))'''
        result = subprocess.run(
            ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
             "--noinform", "--non-interactive", "--no-sysinit", "--no-userinit",
             "--eval", "(require :asdf)",
             "--eval", "(setf *compile-verbose* nil *load-verbose* nil)",
             "--eval", expression],
            cwd=ROOT, text=True, capture_output=True, timeout=60,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("WARNING: STARTUP-WARNING-SENTINEL", result.stderr)


if __name__ == "__main__":
    unittest.main()
