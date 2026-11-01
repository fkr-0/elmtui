#!/usr/bin/env python3
"""Real PTY framebuffer color qualification for the rainbow examples.

Isolated PTYs only: no network access, no persistent tmux sessions, and no
application-owned terminal escape sequences in the fixture.
"""
import fcntl
import os
import pty
import re
import select
import signal
import struct
import subprocess
import termios
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CSI = re.compile(r"\x1b\[([0-9;?]*)([@-~])")
BAND_CHARS = frozenset("#█")


def foreground_cells(raw, width, height):
    """Replay final visible glyph+foreground cells, including overwrites/erasures."""
    text = raw.decode("utf-8", errors="replace")
    grid = {}
    x = y = 0
    fg = None
    cursor_stack = []
    i = 0
    while i < len(text):
        char = text[i]
        if char == "\x1b":
            match = CSI.match(text, i)
            if match:
                args, op = match.groups()
                parts = [int(value) if value.isdigit() else 0
                         for value in args.lstrip("?").split(";")]
                num = (parts[0] or 1) if parts else 1
                if op == "m":
                    k = 0
                    while k < len(parts):
                        value = parts[k]
                        if value in (0, 39):
                            fg = None
                        elif value == 38 and k + 4 < len(parts) and parts[k + 1] == 2:
                            fg = ("rgb", tuple(parts[k + 2:k + 5]))
                            k += 4
                        elif value == 38 and k + 2 < len(parts) and parts[k + 1] == 5:
                            fg = ("indexed", parts[k + 2])
                            k += 2
                        elif 30 <= value <= 37 or 90 <= value <= 97:
                            fg = ("basic", value)
                        k += 1
                elif op in ("H", "f"):
                    y, x = (parts[0] - 1 if parts and parts[0] else 0,
                            parts[1] - 1 if len(parts) > 1 and parts[1] else 0)
                elif op == "G":
                    x = num - 1
                elif op == "A":
                    y -= num
                elif op == "B":
                    y += num
                elif op == "C":
                    x += num
                elif op == "D":
                    x -= num
                elif op == "J" and parts[0] in (2, 3):
                    grid.clear()
                elif op == "K":
                    for pos in tuple(grid):
                        if pos[0] == y and pos[1] >= x:
                            del grid[pos]
                elif op == "s":
                    cursor_stack.append((x, y))
                elif op == "u" and cursor_stack:
                    x, y = cursor_stack.pop()
                i = match.end()
                continue
            if i + 1 < len(text) and text[i + 1] in "78":
                if text[i + 1] == "7":
                    cursor_stack.append((x, y))
                elif cursor_stack:
                    x, y = cursor_stack.pop()
                i += 2
                continue
            i += 1
            continue
        if char == "\r":
            x = 0
        elif char == "\n":
            y += 1
        elif char == "\b":
            x = max(0, x - 1)
        elif char >= " " and char != "\x7f":
            if 0 <= y < height and 0 <= x < width:
                grid[(y, x)] = (char, fg)
            x += 1
        i += 1
    return grid


def read_until(fd, expected, timeout=16.0):
    result = bytearray()
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        ready, _, _ = select.select([fd], [], [], .08)
        if ready:
            try:
                chunk = os.read(fd, 32768)
            except OSError:
                break
            if not chunk:
                break
            result.extend(chunk)
        if expected in result:
            # Allow renderer to finish its initial frame without a timer.
            settle = time.monotonic() + .5
            while time.monotonic() < settle:
                ready, _, _ = select.select([fd], [], [], .04)
                if ready:
                    try:
                        result.extend(os.read(fd, 32768))
                    except OSError:
                        break
            break
    return bytes(result)


class RainbowColors(unittest.TestCase):
    def exercise(self, app, mode, cols=80, rows=24):
        env = dict(os.environ)
        env.pop("COLORTERM", None)
        env["TERM"] = "linux" if mode == "basic" else "xterm-256color"
        if mode == "rgb":
            env["COLORTERM"] = "truecolor"
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ,
                    struct.pack("HHHH", rows, cols, 0, 0))
        saved = termios.tcgetattr(slave)
        proc = subprocess.Popen(
            [str(ROOT / "scripts/examples.sh"), "run", app],
            cwd=ROOT, stdin=slave, stdout=slave, stderr=slave,
            start_new_session=True, env=env)
        try:
            title = b"RAINBOW / mini" if app == "mini-rainbow" else b"CHROMATIC / 07"
            raw = read_until(master, title)
            self.assertIn(title, raw, raw[-600:])
            self.assertNotIn(b"\x1b[?1049h", raw, "alternate-screen usage is forbidden")
            grid = foreground_cells(raw, cols, rows)
            colored = {color for char, color in grid.values()
                       if char in BAND_CHARS and color is not None}
            correct = {color for color in colored if color[0] == mode}
            required = 7 if cols >= 80 else 3
            self.assertGreaterEqual(
                len(correct), required,
                f"{app}/{mode}/{cols}x{rows}: visible={sorted(colored, key=str)}"
                f" raw={raw[-850:]!r}")
            self.assertEqual(correct, colored, "Swatches used unexpected color mode")
            self.assertFalse(any(v is None for char, v in grid.values()
                                 if char in BAND_CHARS), "Unstyled color glyph")
            if cols >= 80 and app == "mini-rainbow":
                corners = [(pos, char) for pos, (char, _) in grid.items()
                           if char in "┌┐└┘"]
                self.assertTrue(corners, "native sharp border not in framebuffer")
            # Check quiescence separately from one-shot startup color rendering.
            readable, _, _ = select.select([master], [], [], .55)
            self.assertFalse(readable, "unexpected idle repaint")
            os.write(master, b"q")
            proc.wait(timeout=7)
            self.assertEqual(proc.returncode, 0)
            self.assertEqual(termios.tcgetattr(slave), saved)
        finally:
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=2)
            os.close(master)
            os.close(slave)

    def test_interrupt_restores_original_terminal(self):
        """SIGINT must shut down without leaving raw mode or alternate screen."""
        for app in ("mini-rainbow", "rainbow-app"):
            with self.subTest(app=app):
                master, slave = pty.openpty()
                fcntl.ioctl(slave, termios.TIOCSWINSZ,
                            struct.pack("HHHH", 24, 80, 0, 0))
                initial = termios.tcgetattr(slave)
                proc = subprocess.Popen(
                    [str(ROOT / "scripts/examples.sh"), "run", app],
                    cwd=ROOT, stdin=slave, stdout=slave, stderr=slave,
                    start_new_session=True,
                    env={**os.environ, "TERM": "xterm-256color", "COLORTERM": "truecolor"})
                try:
                    title = b"RAINBOW / mini" if app == "mini-rainbow" else b"CHROMATIC / 07"
                    output = read_until(master, title)
                    self.assertIn(title, output)
                    self.assertNotIn(b"\x1b[?1049h", output)
                    os.killpg(proc.pid, signal.SIGINT)
                    proc.wait(timeout=7)
                    self.assertEqual(proc.returncode, 0)
                    self.assertEqual(termios.tcgetattr(slave), initial)
                finally:
                    if proc.poll() is None:
                        os.killpg(proc.pid, signal.SIGTERM)
                        try:
                            proc.wait(timeout=2)
                        except subprocess.TimeoutExpired:
                            os.killpg(proc.pid, signal.SIGKILL)
                            proc.wait(timeout=2)
                    os.close(master)
                    os.close(slave)

    def test_only_space_repaints(self):
        """Unrelated keys stay inert; Space updates the native layout tree."""
        for app in ("mini-rainbow", "rainbow-app"):
            with self.subTest(app=app):
                master, slave = pty.openpty()
                fcntl.ioctl(slave, termios.TIOCSWINSZ,
                            struct.pack("HHHH", 24, 80, 0, 0))
                initial = termios.tcgetattr(slave)
                proc = subprocess.Popen(
                    [str(ROOT / "scripts/examples.sh"), "run", app],
                    cwd=ROOT, stdin=slave, stdout=slave, stderr=slave,
                    start_new_session=True,
                    env={**os.environ, "TERM": "xterm-256color", "COLORTERM": "truecolor"})
                try:
                    title = b"RAINBOW / mini" if app == "mini-rainbow" else b"CHROMATIC / 07"
                    self.assertIn(title, read_until(master, title))
                    os.write(master, b"x")
                    readable, _, _ = select.select([master], [], [], .45)
                    self.assertFalse(readable, "irrelevant key triggered a repaint")
                    os.write(master, b" ")
                    changed = read_until(master, b"\x1b[")
                    self.assertTrue(changed, "Space did not trigger any update")
                    self.assertIsNone(proc.poll(), "Space must not quit the demo")
                    os.write(master, b"q")
                    proc.wait(timeout=7)
                    self.assertEqual(proc.returncode, 0)
                    self.assertEqual(termios.tcgetattr(slave), initial)
                finally:
                    if proc.poll() is None:
                        os.killpg(proc.pid, signal.SIGTERM)
                        try:
                            proc.wait(timeout=2)
                        except subprocess.TimeoutExpired:
                            os.killpg(proc.pid, signal.SIGKILL)
                            proc.wait(timeout=2)
                    os.close(master)
                    os.close(slave)

    def test_seven_final_foreground_bands_in_three_color_modes(self):
        for app in ("mini-rainbow", "rainbow-app"):
            for mode in ("rgb", "indexed", "basic"):
                for size in ((80, 24), (120, 40)):
                    with self.subTest(app=app, mode=mode, size=size):
                        self.exercise(app, mode, *size)

    def test_narrow_clipping_no_unsupported_palette(self):
        for app in ("mini-rainbow", "rainbow-app"):
            with self.subTest(app=app):
                self.exercise(app, "basic", 30, 10)


if __name__ == "__main__":
    unittest.main(verbosity=2)
