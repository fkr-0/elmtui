#!/usr/bin/env python3
"""Real public-launcher PTY regression: no duplicate nmcli and prompt abort.

The fake nmcli is injected through PATH; this test never operates host Wi-Fi.
Run: python tests/e2e/remainder-wifi-robustness.py
"""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("terminal_apps", ROOT / "scripts/test-terminal-apps.py")
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)


class WifiRobustness(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="elmtui-wifi-")
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        harness.OPTIONS = type("Options", (), {"output": root, "terminal": "tmux", "timeout": 20})()
        stub = root / "nmcli"
        stub.write_text("""#!/usr/bin/env python3
import json, os, sys, time
with open(os.environ["ELMTUI_NMCLI_CALLS"], "a") as log:
    log.write(json.dumps(sys.argv[1:]) + "\\n")
    log.flush()
if "list" in sys.argv:
    print(" :E2E-Slow:11\\\\:22\\\\:33\\\\:44\\\\:55\\\\:66:90:--:wlan0")
elif "connect" in sys.argv:
    with open(os.environ["ELMTUI_NMCLI_PID"], "w") as f:
        f.write(str(os.getpid()))
    time.sleep(12)
    print("completed")
else:
    sys.exit(2)
""")
        stub.chmod(0o755)
        self.calls = root / "calls.jsonl"
        self.pidfile = root / "child.pid"
        self.app = harness.TerminalApp(
            "wifi-slow", "(elmtui.examples.wifi-menu:run-wifi-menu)",
            source="wifi-menu.lisp",
            environment={"PATH": str(root) + os.pathsep + os.environ["PATH"],
                         "ELMTUI_NMCLI_CALLS": str(self.calls),
                         "ELMTUI_NMCLI_PID": str(self.pidfile)},
            prelude="printf '\\033[2J\\033[HKEEP-ABOVE\\033[6;9H'").start()
        self.addCleanup(self.app.close)

    def test_rapid_enter_and_abort(self):
        self.app.expect("E2E-Slow")
        for _ in range(4):
            self.app.key("Enter", "Return")
        deadline = time.monotonic() + 4
        while not self.pidfile.exists() and time.monotonic() < deadline:
            time.sleep(.05)
        self.assertTrue(self.pidfile.exists(), "fixture connect did not start")
        self.app.key("r", "r", literal=True)
        self.app.key("d", "d", literal=True)
        self.app.key("Enter", "Return")
        # While the fake command is still sleeping, no second operation starts.
        self.assertEqual(sum("connect" in x for x in self.invocations()), 1)
        self.assertEqual(sum("disconnect" in x for x in self.invocations()), 0)
        started = time.monotonic()
        self.app.finish("Escape", "Escape")
        self.assertLess(time.monotonic() - started, 1.5)
        self.assertNotIn("E2E-Slow", self.app.screen())
        self.assertIn("KEEP-ABOVE", self.app.screen().splitlines()[0])
        pid = int(self.pidfile.read_text())
        deadline = time.monotonic() + 3
        while Path("/proc", str(pid)).exists() and time.monotonic() < deadline:
            time.sleep(.05)
        self.assertFalse(Path("/proc", str(pid)).exists(),
                         "pending nmcli child survived menu shutdown")

    def test_command_timeout_reaps_child(self):
        # A short dynamic deadline tests the actual Lisp subprocess path.
        # The fixture is a standalone Python process, not host nmcli.
        child = Path(self.tmp.name) / "sleep-child.py"
        child.write_text(
            "import os,sys,time\n"
            "open(sys.argv[1], 'w').write(str(os.getpid()))\n"
            "time.sleep(10)\n")
        pidfile = Path(self.tmp.name) / "timeout.pid"
        form = ('(let ((elmtui.examples.wifi-menu::+nmcli-command-deadline-seconds+ 1)) '
                '(handler-case '
                '(progn (elmtui.examples.wifi-menu::%run-command '
                '(list "python3" "' + str(child) + '" "' + str(pidfile) + '")) '
                '(sb-ext:exit :code 4)) '
                '(sb-ext:timeout () (write-line "TIMEOUT-OK"))))')
        command = ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
                   "--noinform", "--non-interactive",
                   "--eval", "(require :asdf)",
                   "--eval", '(asdf:load-system "elmtui")',
                   "--load", str(ROOT / "examples/wifi-menu.lisp"),
                   "--eval", form]
        started = time.monotonic()
        result = subprocess.run(command, cwd=ROOT, text=True,
                                capture_output=True, timeout=25)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("TIMEOUT-OK", result.stdout)
        self.assertLess(time.monotonic() - started, 8.0)
        self.assertTrue(pidfile.exists())
        pid = int(pidfile.read_text())
        deadline = time.monotonic() + 3
        while Path("/proc", str(pid)).exists() and time.monotonic() < deadline:
            time.sleep(.05)
        self.assertFalse(Path("/proc", str(pid)).exists(),
                         "timeout left a live or unreaped child")

    def invocations(self):
        return [json.loads(line) for line in self.calls.read_text().splitlines()]


if __name__ == "__main__":
    unittest.main(verbosity=2)
