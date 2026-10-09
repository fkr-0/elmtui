"""Synthetic terminal-only fixture, explicitly NOT an ElmTUI application."""
import os
import sys
import termios
import tty

fd = sys.stdin.fileno()
before = termios.tcgetattr(fd)
try:
    tty.setraw(fd)
    sys.stdout.write("\x1b[?1049h\x1b[?25l\x1b[HWB_QA_FIXTURE_READY\r\n")
    sys.stdout.flush()
    while True:
        b = os.read(fd, 1)
        if not b or b == b"q":
            break
        if b in (b"\x03", b"\x04"):
            break
        sys.stdout.write("\r\nFIXTURE_KEY:" + b.hex().upper() + "\r\n")
        sys.stdout.flush()
finally:
    termios.tcsetattr(fd, termios.TCSANOW, before)
    sys.stdout.write("\x1b[?1049l\x1b[?25hWB_QA_FIXTURE_STOPPED\r\n")
    sys.stdout.flush()
