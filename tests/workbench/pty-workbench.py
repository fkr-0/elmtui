#!/usr/bin/env python3
"""Black-box PTY qualification for the optional ElmTUI Lisp workbench.

Runs the public CLPM/SBCL launcher, not isolated Lisp stubs. Writes bounded,
escaped diagnostic traces under /tmp by default, without altering other tests.
The protocol-specific assertions are intentionally hard gates (never xfail).
"""
import argparse
import fcntl
import os
import pathlib
import pty
import re
import select
import signal
import struct
import subprocess
import tempfile
import termios
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]
CMD = ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
       "--noinform", "--non-interactive", "--load", "examples/workbench.lisp"]
ANSI = re.compile(rb"\x1b\[[0-?]*[ -/]*[@-~]|\x1b\][^\x07]*(?:\x07|\x1b\\)|\x1b[()][A-Za-z0-9]")


def bounds(fd, columns, rows):
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, columns, 0, 0))


def tty_slave():
    master, slave = pty.openpty()
    return master, slave


def launch(size):
    columns, rows = size
    master, slave = tty_slave()
    bounds(slave, columns, rows)
    original = termios.tcgetattr(slave)

    def init_child():
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

    process = subprocess.Popen(
        CMD, cwd=ROOT, stdin=slave, stdout=slave, stderr=slave,
        close_fds=True, preexec_fn=init_child, env={**os.environ, "TERM": "xterm-256color"})
    return process, master, slave, original


def capture(master, seconds, until=None, maximum=400000):
    deadline = time.monotonic() + seconds
    payload = bytearray()
    while time.monotonic() < deadline and len(payload) < maximum:
        readable, _, _ = select.select([master], [], [], min(.09, max(0, deadline - time.monotonic())))
        if readable:
            try:
                chunk = os.read(master, 65536)
            except OSError:
                break
            if not chunk:
                break
            payload.extend(chunk)
        if until is not None and until in payload:
            break
    return bytes(payload)


def ascii_trace(raw):
    no_ansi = ANSI.sub(b"", raw)
    return no_ansi.decode("utf-8", "replace").replace("\r", "\n")


def must(condition, label, output):
    if not condition:
        excerpt = ascii_trace(output)[-1800:]
        raise AssertionError(f"{label} not observed; tail={excerpt!r}")


def exercise(size, folder):
    process, master, slave, original = launch(size)
    output = bytearray()
    try:
        # The first header can precede the complete frame and the input loop.
        # Wait for the status line instead of sending keystrokes during setup.
        output.extend(capture(master, 8, b"Ready  |"))
        must(b"Lisp Workbench" in output, "startup frame", output)
        must(b"Transcript (0)" in output, "transcript title", output)
        must(b"> |" in output, "editor prompt", output)
        must(b"Ready  |" in output, "startup status", output)
        if size[0] >= 120:
            must(b"IMAGE / PACKAGES" in output, "wide inspector", output)
        must(b"\x1b[?1049h" in output, "alternate-screen enter", output)
        output.extend(capture(master, .25))
        os.write(master, b"(+ 1 2)\r")
        # Frame diffs are fragmented; the submitted source is not guaranteed
        # to appear as one contiguous run of output bytes. Assert the value
        # was painted at terminal column 3 and the transcript got its prompt.
        evaluated = capture(master, 3, b"\x1b[4;3H3")
        output.extend(evaluated)
        must(b"COMMON-LISP-USER>" in evaluated and
             re.search(rb"\x1b\[\d+;3H3", evaluated), "REPL evaluation", output)
        os.write(master, b"(car")
        output.extend(capture(master, .18))
        os.write(master, b"\x00")
        output.extend(capture(master, 1, b"COMPLETION"))
        must(b"COMPLETION" in output, "completion popup", output)
        output.extend(capture(master, .8))
        os.write(master, b"\x1b")
        output.extend(capture(master, .3))
        # Clear the incomplete edit before the documented empty-buffer exit.
        os.write(master, b"\x7f" * 4)
        output.extend(capture(master, .3))
        os.write(master, b"\x04")
        output.extend(capture(master, 3, b"\x1b[?1049l"))
        must(b"\x1b[?1049l" in output, "alternate-screen restore", output)
        must(process.wait(timeout=2) == 0, "clean Ctrl+D exit", output)
        folder.mkdir(parents=True, exist_ok=True)
        trace = folder / f"{size[0]}x{size[1]}.trace"
        trace.write_text(ascii_trace(output), encoding="utf-8")
        # Assert expected protocol and explicit process cleanup below.
        return trace, output
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=2)
        try:
            changed = termios.tcgetattr(slave)
            # Compare ICANON/ECHO/ISIG; driver must leave raw mode before process exit.
            required = termios.ICANON | termios.ECHO | termios.ISIG
            assert (original[3] & required) == (changed[3] & required), (
                "termios local flags were not restored")
        finally:
            os.close(master)
            os.close(slave)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--traces", type=pathlib.Path,
                        default=pathlib.Path(tempfile.mkdtemp(prefix="elmtui-wb-pty-")))
    args = parser.parse_args()
    failures = []
    for size in [(80, 24), (120, 40), (160, 50)]:
        try:
            trace, output = exercise(size, args.traces)
            print(f"PASS {size[0]}x{size[1]} trace={trace} bytes={len(output)}")
        except Exception as error:
            print(f"FAIL {size[0]}x{size[1]} {error}")
            failures.append(str(error))
    if failures:
        raise SystemExit(1)
    print("PTY SMOKE PASS (3 sizes)")


if __name__ == "__main__":
    main()
