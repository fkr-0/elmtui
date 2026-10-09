#!/usr/bin/env python3
"""Example CLI logs are discarded or sent to a file, never the terminal."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
PROBES = ("ELMTUI_WARN_SINK_PROBE_20261009", "ELMTUI_INFO_SINK_PROBE_20261009")
COMMAND = [
    "clpm", "bundle", "exec", "--with-client", "sbcl", "--",
    "--noinform", "--non-interactive",
    "--eval", "(require :asdf)",
    "--eval", "(asdf:load-system :elmtui-examples-cli)",
    "--eval", "(elmtui.examples.runner::%configure-cli-logging)",
    "--eval", '(log4cl:log-warn "ELMTUI_WARN_SINK_PROBE_20261009")',
    "--eval", '(log4cl:log-info "ELMTUI_INFO_SINK_PROBE_20261009")',
]


class CliDiagnosticIsolation(unittest.TestCase):
    def check(self, env, path=None):
        proc = subprocess.run(
            COMMAND, cwd=ROOT, env={**os.environ, **env},
            text=True, capture_output=True, timeout=50,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr[-1800:])
        for probe in PROBES:
            self.assertNotIn(probe, proc.stdout, "log leaked to stdout")
            self.assertNotIn(probe, proc.stderr, "log leaked to stderr")
        if path is not None:
            contents = path.read_text()
            for probe in PROBES:
                self.assertIn(probe, contents, "diagnostic file lost message")

    def test_default_does_not_write_logs_to_terminal(self):
        self.check({"ELMTUI_LOG_FILE": "", "ELMTUI_VERBOSE_LOGS": "0"})

    def test_verbose_without_file_still_does_not_log_to_terminal(self):
        self.check({"ELMTUI_LOG_FILE": "", "ELMTUI_VERBOSE_LOGS": "1"})

    def test_verbose_explicit_log_file_receives_messages(self):
        with tempfile.TemporaryDirectory() as root:
            logfile = Path(root) / "test.log"
            self.check(
                {"ELMTUI_LOG_FILE": str(logfile), "ELMTUI_VERBOSE_LOGS": "1"},
                logfile,
            )


if __name__ == "__main__":
    unittest.main()
