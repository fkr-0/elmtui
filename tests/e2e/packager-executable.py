#!/usr/bin/env python3
"""Release gate: elmtui-packager produces a clean, self-contained executable.

1. Run the packager entry point (`elmtui.packager::run-packager`, what the
   `elmtui-packager` executable's MAIN calls) and check its usage text.
2. Use it to dump the maintained minimal example to a standalone binary.
3. Copy that binary into an empty directory and start it there inside a
   private tmux server, without CLPM, ASDF registry or source tree on hand.
4. The binary must render, quit on Ctrl-C with status 0, and leave stty, cursor
   visibility and the 70-line normal-screen history exactly as before.

Run: python3 tests/e2e/packager-executable.py
"""
import importlib.util
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "packager_harness", ROOT / "scripts/test-terminal-apps.py")
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)

MARKER = re.compile(r"HISTORY-MARKER-(\d{2})")


class Options:
    terminal = "tmux"
    timeout = 30
    output = None


def sbcl(*forms, timeout=900):
    command = ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
               "--noinform", "--non-interactive", "--no-sysinit", "--no-userinit",
               "--eval", "(require :asdf)"]
    for form in forms:
        command.extend(["--eval", form])
    return subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                          timeout=timeout)


class PackagerExecutable(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="elmtui-packager-")
        Options.output = Path(cls.tmp.name)
        harness.OPTIONS = Options()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_packager_dumps_a_standalone_minimal_executable(self):
        work = Path(self.tmp.name)
        usage = sbcl('(asdf:load-system "elmtui-packager")',
                     '(elmtui.packager::run-packager (list "--help"))', timeout=300)
        self.assertIn("Usage: elmtui-packager", usage.stdout, usage.stderr[-1500:])

        # RUN-PACKAGER is exactly what the elmtui-packager executable's MAIN runs.
        binary = work / "minimal-dumped"
        dump = sbcl('(asdf:load-system "elmtui-packager")',
                    '(elmtui.packager::run-packager (list "-s" "elmtui-examples" '
                    '"-E" "elmtui.examples.minimal::run-minimal" '
                    f'"-o" "{binary}"))')
        self.assertTrue(binary.exists() and os.access(binary, os.X_OK),
                        dump.stdout[-1500:] + dump.stderr[-1500:])

        isolated = work / "isolated"
        isolated.mkdir()
        shutil.copy2(binary, isolated / "minimal")
        prelude = ('cd ' + str(isolated) + '\n'
                   'for n in $(seq -w 1 70); do printf "HISTORY-MARKER-%s\\n" "$n"; done')
        app = harness.TerminalApp(
            "packaged-minimal", None, prelude=prelude, use_launcher=False,
            command=["env", "-u", "CLPM_HOME", "-u", "CL_SOURCE_REGISTRY",
                     "-u", "SBCL_HOME", str(isolated / "minimal")])
        app.start()
        self.addCleanup(app.close)
        app.expect("HISTORY-MARKER-70")
        app.expect("Hello slurp")
        baseline = [int(n) for n in MARKER.findall(
            app.tmux("capture-pane", "-p", "-S", "-", "-t", "app:0.0").stdout)]
        self.assertEqual(baseline, list(range(1, 71)))
        app.key("C-c")  # the minimal example quits on the interrupt key
        app.wait(lambda screen: "ELMTUI_E2E_SHELL_RESTORED" in screen,
                 "packaged binary returned to the shell", allow_exit=True)
        self.assertEqual((app.directory / "exit-code").read_text().strip(), "0",
                         (app.directory / "stderr.txt").read_text()[-1500:])
        self.assertEqual((app.directory / "before.stty").read_text(),
                         (app.directory / "after.stty").read_text())
        self.assertEqual(app.tmux("display-message", "-p", "-t", "app:0.0",
                                  "#{cursor_flag}").stdout.strip(), "1")
        restored = [int(n) for n in MARKER.findall(
            app.tmux("capture-pane", "-p", "-S", "-", "-t", "app:0.0").stdout)]
        self.assertEqual(restored, list(range(1, 71)))
        raw = (app.directory / "terminal.raw").read_bytes()
        for seq in (b"\x1b[?1049h", b"\x1b[?1047h", b"\x1b[?47h", b"\x1b[2J", b"\x1b[3J"):
            self.assertNotIn(seq, raw)


if __name__ == "__main__":
    unittest.main(verbosity=2)
