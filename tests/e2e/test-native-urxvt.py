#!/usr/bin/env python3
"""Qualify Wi-Fi in native urxvt on private Xvfb, without tmux emulation."""
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[2]
OPTIONS = None

PROBE = '''import json, os, re, select, termios, time, tty, sys
fd = os.open("/dev/tty", os.O_RDWR | os.O_NOCTTY)
saved = termios.tcgetattr(fd)
data = b""
try:
    tty.setraw(fd)
    os.write(fd, b"\\x1b[6n")
    deadline = time.monotonic() + 2
    while time.monotonic() < deadline:
        ready, _, _ = select.select([fd], [], [], max(0, deadline-time.monotonic()))
        if ready:
            data += os.read(fd, 256)
            match = re.search(rb"\\x1b\\[(\\d+);(\\d+)R", data)
            if match:
                with open(sys.argv[1], "w") as output:
                    json.dump({"row": int(match[1]), "column": int(match[2])}, output)
                break
    else:
        raise RuntimeError("Native terminal did not answer cursor query: " + repr(data))
finally:
    termios.tcsetattr(fd, termios.TCSANOW, saved)
    os.close(fd)
'''


class NativeUrxvt(unittest.TestCase):
    def scenario(self, key):
        directory = OPTIONS.output / (key + "-" + uuid.uuid4().hex[:8])
        directory.mkdir()
        fixture = directory / "fixture"
        fixture.mkdir()
        stub = fixture / "nmcli"
        stub.write_text('#!/usr/bin/env python3\nimport json, os, sys\n'
                        'with open(os.environ["ELMTUI_NMCLI_CALLS"], "a") as f: f.write(json.dumps(sys.argv[1:])+"\\n")\n'
                        'if "list" in sys.argv: print(" :E2E-Guest:11\\\\:22\\\\:33\\\\:44\\\\:55\\\\:66:90:--:wlan0")\n'
                        'elif "connect" in sys.argv: print("fixture connected")\n'
                        'else: sys.exit(2)\n')
        stub.chmod(0o755)
        (directory / "cursor-probe.py").write_text(PROBE)
        launcher = directory / "launch.sh"
        q = lambda name: shlex.quote(str(directory / name))
        launcher.write_text(
            "#!/bin/sh\ncd " + shlex.quote(str(ROOT)) + "\n"
            + "stty -g > " + q("before.stty") + "\n"
            + "printf '\\033[2J'\n"
            + "\n".join("printf '\\033[%d;1HROW-%02d'" % (row, row)
                        for row in range(1, 36))
            + "\nprintf '\\033[35;9H'\n"
            + shlex.quote(str(ROOT / "examples.sh")) + " run wifi-menu 2>" + q("stderr.txt") + "\n"
            + 'status=$?\nprintf "%s\\n" "$status" > ' + q("exit-code") + "\n"
            + "stty -g > " + q("after.stty") + "\n"
            + shlex.quote(sys.executable) + " " + q("cursor-probe.py") + " " + q("cursor.json")
            + " 2>" + q("probe.stderr") + "\n"
            + "printf 'NATIVE_SHELL_RESTORED'\nsleep 120\n")
        env = dict(os.environ, PATH=str(fixture) + os.pathsep + os.environ["PATH"],
                   ELMTUI_NMCLI_CALLS=str(directory / "nmcli-calls.jsonl"))
        env.pop("TMUX", None)
        env.pop("TMUX_PANE", None)
        title = "elmtui-native-" + directory.name
        process = subprocess.Popen(
            ["urxvt", "-name", title, "-title", title, "-geometry", "100x35",
             "-fn", "xft:DejaVu Sans Mono:size=12", "-fg", "black", "-bg", "white",
             "-e", "script", "-q", "-f", "-c", "sh " + shlex.quote(str(launcher)),
             str(directory / "terminal.raw")],
            env=env, stdout=subprocess.DEVNULL,
            stderr=(directory / "urxvt.stderr").open("w"))
        self.addCleanup(self.stop, process)
        window = None
        deadline = time.monotonic() + OPTIONS.timeout
        while time.monotonic() < deadline:
            search = subprocess.run(["xdotool", "search", "--name", "^" + title + "$"],
                                    capture_output=True, text=True)
            if search.returncode == 0:
                window = search.stdout.splitlines()[0]
                break
            time.sleep(.05)
        self.assertIsNotNone(window, "Native urxvt window did not appear")
        subprocess.run(["xdotool", "windowfocus", "--sync", window],
                       check=True, capture_output=True, timeout=5)
        self.wait(directory, lambda: b"E2E-Guest" in self.raw(directory), "visible scanned network")
        before_ocr = self.wait_screenshot(window, directory / "menu.png",
                                          r"(?i)E2E[- ]?Guest")
        if before_ocr is not None:
            self.assertRegex(before_ocr, r"(?i)E2E[- ]?Guest")
        started = time.monotonic()
        subprocess.run(["xdotool", "key", "--clearmodifiers", "--window", window, key],
                       check=True, timeout=5)
        self.wait(directory, lambda: (directory / "cursor.json").exists(), "normal input-driven shutdown")
        shutdown_seconds = time.monotonic() - started
        (directory / "latency.json").write_text(json.dumps({
            "key": key, "shutdown_seconds": shutdown_seconds,
        }, indent=2) + "\n")
        self.assertLess(shutdown_seconds, 2.5)
        self.wait(directory, lambda: b"NATIVE_SHELL_RESTORED" in self.raw(directory),
                  "restored shell output")
        self.assertEqual((directory / "exit-code").read_text().strip(), "0")
        self.assertEqual((directory / "before.stty").read_text(),
                         (directory / "after.stty").read_text(), "termios restoration")
        self.assertEqual(json.loads((directory / "cursor.json").read_text()),
                         {"row": 35, "column": 9}, "actual native terminal cursor response")
        after_ocr = self.wait_screenshot(window, directory / "restored.png",
                                         r"NATIVE[ _]SHELL[ _]RESTORED")
        if after_ocr is not None:
            self.assertNotRegex(after_ocr, r"(?i)E2E[- ]?Guest|NetworkManager")
            self.assertRegex(after_ocr, r"NATIVE[ _]SHELL[ _]RESTORED")
            for row in range(21, 36):
                self.assertRegex(after_ocr, r"(?i)ROW-%02d" % row,
                                 "surrounding native terminal content must survive")
        raw = self.raw(directory).split(b"\x1b[6n", 1)[-1]
        self.assertNotRegex(raw, rb"\x1b\[(?:2|3)J|\x1b\[\?1049[hl]")
        up = [int(n or b"1") for n in re.findall(rb"\x1b\[(\d*)S", raw)]
        down = [int(n or b"1") for n in re.findall(rb"\x1b\[(\d*)T", raw)]
        self.assertEqual((up, down), ([1] * 20, [1] * 20))
        diagnostics = (directory / "stderr.txt").read_text()
        self.assertEqual(diagnostics, "", "launcher/runtime stderr must remain clean")
        calls = [json.loads(line) for line in (directory / "nmcli-calls.jsonl").read_text().splitlines()]
        self.assertTrue(calls)
        if key == "Escape":
            self.assertTrue(all("list" in argv for argv in calls))
        else:
            self.assertTrue(any("connect" in argv for argv in calls))

    def raw(self, directory):
        path = directory / "terminal.raw"
        return path.read_bytes() if path.exists() else b""

    def wait(self, directory, predicate, description):
        deadline = time.monotonic() + OPTIONS.timeout
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(.05)
        self.fail("Timed out waiting for " + description + "; artifacts: " + str(directory))

    def screenshot(self, window, path):
        if not shutil.which("import"):
            return None
        subprocess.run(["import", "-window", window, str(path)], check=True, timeout=10)
        if not shutil.which("tesseract"):
            return None
        result = subprocess.run(["tesseract", str(path), "stdout", "--psm", "6"],
                                check=True, capture_output=True, text=True, timeout=10)
        path.with_suffix(".ocr.txt").write_text(result.stdout)
        return result.stdout

    def wait_screenshot(self, window, path, expected):
        # Transcript bytes can arrive before urxvt has painted the X11 window.
        # Poll the independently observed screen rather than assuming a redraw
        # has completed as soon as the PTY relay flushes those bytes.
        deadline = time.monotonic() + 5
        while True:
            text = self.screenshot(window, path)
            if text is None or re.search(expected, text) or time.monotonic() >= deadline:
                return text
            time.sleep(.05)

    @staticmethod
    def stop(process):
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)

    def test_native_bottom_abort(self):
        self.scenario("Escape")

    def test_native_bottom_confirm(self):
        self.scenario("Return")


def main():
    global OPTIONS
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeout", type=float, default=15)
    parser.add_argument("--output", type=Path)
    OPTIONS = parser.parse_args()
    missing = [name for name in ("urxvt", "xvfb-run", "xdotool", "script", "clpm", "sbcl")
               if not shutil.which(name)]
    if missing:
        parser.error("Missing required executables: " + ", ".join(missing))
    if not os.environ.get("ELMTUI_NATIVE_PRIVATE_X"):
        return subprocess.call(["xvfb-run", "-a", "-s", "-screen 0 1280x900x24",
                                sys.executable, str(Path(__file__).resolve()), *sys.argv[1:]],
                               env=dict(os.environ, ELMTUI_NATIVE_PRIVATE_X="1"))
    OPTIONS.output = (OPTIONS.output or ROOT / "test-output" /
                      ("native-urxvt-e2e-" + uuid.uuid4().hex[:8])).resolve()
    OPTIONS.output.mkdir(parents=True, exist_ok=True)
    result = unittest.TextTestRunner(verbosity=2).run(
        unittest.defaultTestLoader.loadTestsFromTestCase(NativeUrxvt))
    (OPTIONS.output / "result.json").write_text(json.dumps({
        "terminal": "native-urxvt", "tmux": False, "tests": result.testsRun,
        "failures": len(result.failures), "errors": len(result.errors),
        "successful": result.wasSuccessful(),
    }, indent=2) + "\n")
    print("Artifacts: " + str(OPTIONS.output))
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
