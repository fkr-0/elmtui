"""Prove ASDF runs real checks and propagates an injected FiveAM failure."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("clpm"), "CLPM required")
class AsdfAcceptance(unittest.TestCase):
    def run_asdf(self, inject=False):
        forms = ['(asdf:load-system "elmtui-tests")']
        if inject:
            forms.extend([
                '(fiveam:def-suite asdf-failure-probe)',
                '(fiveam:in-suite asdf-failure-probe)',
                '(fiveam:test injected-failure (fiveam:fail "INTENTIONAL-ASDF-FAILURE"))',
            ])
        forms.append('(asdf:test-system "elmtui-tests")')
        command = ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
                   "--noinform", "--non-interactive"]
        for form in forms:
            command.extend(["--eval", form])
        return subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=90)

    def test_asdf_runs_default_acceptance_suites(self):
        result = self.run_asdf()
        self.assertEqual(0, result.returncode, result.stderr[-4000:])
        self.assertRegex(result.stdout, r"Did [1-9][0-9]* checks")
        for suite in ("API-CONTRACT-TESTS", "CORE-SLIM-TESTS", "DEV-TEST-SUITE",
                      "BENCHMARK-TEST-SUITE"):
            self.assertIn("Running test suite " + suite, result.stdout)

    def test_asdf_propagates_fiveam_failure(self):
        result = self.run_asdf(inject=True)
        self.assertNotEqual(0, result.returncode, result.stdout[-4000:])
        self.assertIn("INTENTIONAL-ASDF-FAILURE", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
