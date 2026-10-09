#!/usr/bin/env python3
"""Offline weather example checks; opt-in live network smoke.

python3 tests/e2e/example-overhaul-async-weather.py
ELMTUI_WEATHER_LIVE_SMOKE=1 python3 tests/e2e/example-overhaul-async-weather.py
"""
import os
import pty
import fcntl
import select
import signal
import struct
import subprocess
import termios
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COMMAND = ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
           "--noinform", "--non-interactive", "--eval",
           '(asdf:load-system :elmtui)', "--load", "examples/async-weather.lisp"]
GEO = '(list (list :name "Berlin" :country "Germany" :lat "52.5" :lon "13.4"))'
DATA = '(list :temperature "19.4" :humidity "40" :feels "18" :wind "3" :code "0" :hours (list (list "08:00" "19" "0")))'
FAKE = f'(lambda (url phase id) (declare (ignore url id)) (if (eq phase :geocode) {GEO} {DATA}))'


def interactive(rows=24, columns=80, live=False, trace=False):
    expression = "(elmtui.examples.async-weather:run-async-weather)"
    if not live:
        expression = ("(let ((elmtui.examples.async-weather:*weather-transport* "
                      + FAKE + ")) " + expression + ")")
    pid, master = pty.fork()
    if pid == 0:
        os.chdir(ROOT)
        os.execvpe("clpm", COMMAND + ["--eval", expression],
                   {**os.environ, "TERM": "xterm-256color"})
    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", rows, columns, 0, 0))
    data = bytearray()
    status = None
    sent = False
    chosen = False
    events = []
    started = time.monotonic()
    try:
        while time.monotonic() - started < (22 if live else 9):
            if live and not chosen and b"Berlin, Germany" in data:
                os.write(master, b"\r")
                chosen = True
            if not sent and time.monotonic() - started > (18 if live else 2.5):
                os.write(master, b"q")
                sent = True
            ready, _, _ = select.select([master], [], [], .1)
            if ready:
                try:
                    chunk = os.read(master, 65536)
                    if not chunk:
                        break
                    data.extend(chunk)
                    events.append((time.monotonic() - started, bytes(chunk)))
                    # Answer terminal cursor position (DSR) to avoid nonresponsive pseudo terminals.
                    if b"\x1b[6n" in chunk:
                        os.write(master, b"\x1b[1;1R")
                except OSError:
                    break
            finished, result = os.waitpid(pid, os.WNOHANG)
            if finished:
                status = result
                break
        if status is None:
            os.kill(pid, signal.SIGKILL)
            _, status = os.waitpid(pid, 0)
    finally:
        os.close(master)
    result = (os.waitstatus_to_exitcode(status), bytes(data))
    return result + (events,) if trace else result


class AsyncWeatherTests(unittest.TestCase):
    def test_offline_state_and_json(self):
        proc = subprocess.run(COMMAND + ["--load", "tests/e2e/example-overhaul-async-weather.lisp"],
                              cwd=ROOT, capture_output=True, text=True, timeout=25)
        self.assertEqual(proc.returncode, 0, proc.stdout[-1400:] + proc.stderr[-1400:])
        for label in ("PASS url-and-coordinates", "PASS json-fixtures",
                      "PASS teastart-disambiguate-ready"):
            self.assertIn(label, proc.stdout)

    def test_pty_80x24_and_120x40(self):
        for rows, cols in ((24, 80), (40, 120), (20, 40)):
            with self.subTest(size=(rows, cols)):
                code, data = interactive(rows, cols)
                text = data.decode("utf-8", errors="replace")
                self.assertEqual(code, 0, text[-1400:])
                self.assertIn("OPEN METEO", text)
                # Inline viewport: never enter alternate screen, restore cursor on exit.
                self.assertNotIn(b"\x1b[?1049h", data)
                self.assertIn(b"\x1b[?25h", data)
                # The native diff renderer emits changed cells, not complete lines.
                self.assertIn("Updated", text)
                self.assertIn("19", text)

    def test_idle_writes(self):
        code, data, events = interactive(trace=True)
        self.assertEqual(code, 0)
        self.assertIn(b"Updated", data)
        # Ignore startup writes and the finishing diff; verify a stable quiet window.
        cumulative = b""
        ready_at = None
        for seconds, chunk in events:
            cumulative += chunk
            if ready_at is None and b"Updated" in cumulative:
                ready_at = seconds
        self.assertIsNotNone(ready_at)
        self.assertFalse(any(t > ready_at + .4 and t < 2.4
                             for t, _ in events), "idle terminal output after READY")

    def test_twice(self):
        for n in range(2):
            with self.subTest(repetition=n):
                code, data = interactive()
                self.assertEqual(code, 0, data.decode("utf-8", errors="replace")[-1200:])

    @unittest.skipUnless(os.environ.get("ELMTUI_WEATHER_LIVE_SMOKE") == "1",
                         "Opt-in network smoke only")
    def test_live(self):
        code, data = interactive(live=True)
        self.assertEqual(code, 0, data.decode("utf-8", errors="replace")[-1300:])
        self.assertIn(b"OPEN METEO", data)
        self.assertIn(b"Updated", data)


if __name__ == "__main__":
    unittest.main(verbosity=2)
