#!/usr/bin/env python3
"""Exercise real Wi-Fi launcher reservation at the bottom terminal row."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("terminal_apps", ROOT / "scripts/test-terminal-apps.py")
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)


class BottomRow(unittest.TestCase):
    def wifi(self):
        fixture = harness.OPTIONS.output / "nmcli-fixture"
        fixture.mkdir(exist_ok=True)
        stub = fixture / "nmcli"
        stub.write_text('#!/usr/bin/env python3\nimport json, os, sys\n'
                        'with open(os.environ["ELMTUI_NMCLI_CALLS"], "a") as f: f.write(json.dumps(sys.argv[1:])+"\\n")\n'
                        'if "list" in sys.argv: print(" :E2E-Guest:11\\\\:22\\\\:33\\\\:44\\\\:55\\\\:66:90:--:wlan0")\n'
                        'elif "connect" in sys.argv: print("fixture connected")\n'
                        'else: sys.exit(2)\n')
        stub.chmod(0o755)
        calls = harness.OPTIONS.output / ("calls-" + uuid.uuid4().hex + ".jsonl")
        prelude = "printf '\\033[2J'\n" + "\n".join(
            "printf '\\033[%d;1HROW-%02d'" % (row, row) for row in range(1, 36)
        ) + "\nprintf '\\033[35;9H'"
        app = harness.TerminalApp(
            "wifi-bottom", "", source="wifi-menu.lisp",
            environment={"PATH": str(fixture) + os.pathsep + os.environ["PATH"],
                         "ELMTUI_NMCLI_CALLS": str(calls)},
            prelude=prelude,
        )
        self.addCleanup(app.close)
        return app.start(), calls

    def check_exit(self, key, x_key):
        app, calls = self.wifi()
        screen = app.expect("E2E-Guest")
        lines = screen.splitlines()
        self.assertIn("Wi-Fi / NetworkManager", lines[15],
                      "20-row menu must reserve 20 rows below the entry cursor")
        self.assertNotIn("Wi-Fi", "\n".join(lines[:15]))
        for row in range(21, 36):
            self.assertTrue(lines[row - 21].startswith("ROW-%02d" % row),
                            "reservation must scroll existing lower rows up intact")
        started = time.monotonic()
        app.finish(key, x_key)
        self.assertLess(time.monotonic() - started, 2.0,
                        "normal key-driven shutdown must remain responsive")
        restored = app.screen().splitlines()
        self.assertNotIn("E2E-Guest", "\n".join(restored))
        self.assertNotIn("NetworkManager", "\n".join(restored))
        for row in range(21, 35):
            self.assertEqual(restored[row - 1], "ROW-%02d" % row)
        self.assertEqual(restored[34], "ROW-35  ELMTUI_E2E_SHELL_RESTORED",
                         "entry cursor must return to row 35, column 9")
        # Earlier rows may reside in scrollback after the deliberate reservation;
        # they must remain available rather than being destroyed by screen reset.
        history = app.tmux("capture-pane", "-p", "-S", "-", "-t", "app:0.0").stdout
        for row in range(1, 36):
            self.assertIn("ROW-%02d" % row, history)
        raw = (app.directory / "terminal.raw").read_bytes()
        # The fixture's initial clear precedes the application cursor query.
        application = raw.split(b"\x1b[6n", 1)[-1]
        self.assertNotRegex(application, rb"\x1b\[(?:2|3)J|\x1b\[\?1049[hl]",
                            "menu lifecycle must not clear/reset the whole terminal")
        up_steps = [int(n or b"1") for n in re.findall(rb"\x1b\[(\d*)S", application)]
        down_steps = [int(n or b"1") for n in re.findall(rb"\x1b\[(\d*)T", application)]
        up, down = sum(up_steps), sum(down_steps)
        self.assertEqual((up, down), (20, 20),
                         "reserve exactly 20 rows and reverse exactly that reservation")
        self.assertTrue(all(step == 1 for step in up_steps + down_steps),
                        "reserve/reverse through one-row scroll operations")
        erased_cells = re.findall(rb"\x1b\[(\d+);(\d+)H(?:\x1b\[[0-9;]*m)* {80}", application)
        self.assertTrue(erased_cells, "owned menu rectangle must be explicitly erased")
        self.assertTrue(all(16 <= int(row) <= 35 and int(col) == 9
                            for row, col in erased_cells),
                        "clear operations must stay inside the owned menu rectangle")
        invocations = [json.loads(line) for line in calls.read_text().splitlines()]
        self.assertTrue(invocations)
        if key == "Escape":
            self.assertTrue(all("list" in argv for argv in invocations))
        else:
            self.assertTrue(any("connect" in argv for argv in invocations))

    def test_bottom_row_abort(self):
        self.check_exit("Escape", "Escape")

    def test_bottom_row_confirm(self):
        self.check_exit("Enter", "Return")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--terminal", choices=["tmux", "urxvt"], default="tmux")
    parser.add_argument("--timeout", type=float, default=15)
    parser.add_argument("--output", type=Path)
    options = parser.parse_args()
    if options.terminal == "urxvt" and not os.environ.get("ELMTUI_E2E_PRIVATE_X"):
        return subprocess.call(["xvfb-run", "-a", "-s", "-screen 0 1280x900x24",
                                sys.executable, str(Path(__file__).resolve()), *sys.argv[1:]],
                               env=dict(os.environ, ELMTUI_E2E_PRIVATE_X="1"))
    options.output = (options.output or ROOT / "test-output" /
                      ("bottom-row-e2e-" + uuid.uuid4().hex[:8])).resolve()
    options.output.mkdir(parents=True, exist_ok=True)
    harness.OPTIONS = options
    result = unittest.TextTestRunner(verbosity=2).run(
        unittest.defaultTestLoader.loadTestsFromTestCase(BottomRow))
    (options.output / "result.json").write_text(json.dumps({
        "terminal": options.terminal, "tests": result.testsRun,
        "failures": len(result.failures), "errors": len(result.errors),
        "successful": result.wasSuccessful(),
    }, indent=2) + "\n")
    print("Artifacts: " + str(options.output))
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
