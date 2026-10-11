#!/usr/bin/env python3
"""Black-box Neon Quartet qualification using a private pseudo-terminal."""
import fcntl
import os
from pathlib import Path
import pty
import re
import select
import signal
import struct
import subprocess
import sys
import termios
import time

ROOT = Path(__file__).resolve().parents[1]
ANSI = re.compile(rb"\x1b\[[0-?]*[ -/]*[@-~]|\x1b\][^\x07]*(?:\x07|\x1b\\)")
CASES = (
    ("neon-pong", b"NEON CIRCUIT", b"wsi", b"q"),
    ("neon-tetris", b"STACK LAB", b"adws", b"q"),
    ("neon-nano", b"MIDNIGHT EDITOR", b"Hello", b"\x18d"),
    ("neon-less", b"DEEP FILE VIEWER", b"jfkbgG", b"q"),
)


def read_for(fd, duration, limit=250000):
    end = time.monotonic() + duration
    result = bytearray()
    while time.monotonic() < end and len(result) < limit:
        readable, _, _ = select.select([fd], [], [], max(0, min(.07, end - time.monotonic())))
        if readable:
            try:
                data = os.read(fd, 8192)
            except OSError:
                break
            if not data:
                break
            result.extend(data)
    return bytes(result)


def display(raw):
    return ANSI.sub(b"", raw).decode("utf-8", "replace").replace("\r", "\n")


def run(name, header, controls, quit_keys):
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 35, 100, 0, 0))
    baseline = termios.tcgetattr(slave)

    def child_tty():
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

    proc = subprocess.Popen(
        [str(ROOT / "scripts/examples.sh"), "run", name],
        cwd=ROOT, stdin=slave, stdout=slave, stderr=slave, close_fds=True,
        preexec_fn=child_tty,
        env={**os.environ, "TERM": "xterm-256color"},
    )
    output = bytearray()
    try:
        deadline = time.monotonic() + 12
        while time.monotonic() < deadline and header not in output:
            output.extend(read_for(master, .15))
            if proc.poll() is not None:
                break
        if header not in output:
            raise AssertionError(f"{name} failed startup: {display(output)[-2200:]!r}")

        output.extend(read_for(master, .4))
        if name in ("neon-nano", "neon-less"):
            quiet = read_for(master, .4)
            if quiet:
                raise AssertionError(f"{name} wrote {len(quiet)} idle bytes")

        os.write(master, controls)
        output.extend(read_for(master, .3))
        os.write(master, quit_keys)
        deadline = time.monotonic() + 6
        while proc.poll() is None and time.monotonic() < deadline:
            output.extend(read_for(master, .12))
        if proc.poll() is None:
            raise AssertionError(
                f"{name} did not exit after quit controls; last screen bytes: "
                f"{display(output)[-1600:]!r}"
            )
        if proc.returncode != 0:
            raise AssertionError(
                f"{name} exited {proc.returncode}: {display(output)[-1500:]!r}"
            )
        if termios.tcgetattr(slave) != baseline:
            raise AssertionError(f"{name} did not restore terminal termios")
        print(f"PASS {name}: startup, keys, exit, terminal cleanup")
    finally:
        if proc.poll() is None:
            proc.send_signal(signal.SIGTERM)
            try:
                proc.wait(timeout=1.5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=1)
        os.close(master)
        os.close(slave)


if __name__ == "__main__":
    failures = []
    for scenario in CASES:
        try:
            run(*scenario)
        except (AssertionError, OSError) as exc:
            failures.append(str(exc))
            print(f"FAIL {scenario[0]}: {exc}", file=sys.stderr)
    if failures:
        raise SystemExit(1)
