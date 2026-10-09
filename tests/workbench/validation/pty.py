"""Isolated real tmux PTY with decoded display snapshots and raw output evidence.

No application code is mocked here. A *separate* terminal_fixture.py is used
only to validate this driver; its results must never qualify workbench cases.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile
import time


class PTYError(AssertionError):
    pass


class PrivatePTY:
    def __init__(self, command, artifact_dir, cols=80, rows=24, cwd=None, timeout=12):
        if not command or not isinstance(command, (tuple, list)):
            raise ValueError("command must be nonempty argv")
        if cols <= 0 or rows <= 0 or timeout <= 0:
            raise ValueError("invalid terminal dimensions or timeout")
        self.command = list(command)
        self.artifact_dir = Path(artifact_dir).resolve()
        self.artifact_dir.mkdir(parents=True, exist_ok=True)
        self.cwd = Path(cwd or os.getcwd()).resolve()
        self.cols, self.rows, self.timeout = cols, rows, timeout
        self.socket_root = Path(tempfile.mkdtemp(prefix="wb-qa-sock-"))
        self.socket = self.socket_root / "s"
        self.trace = []
        self.started = False
        self.closed = False

    @staticmethod
    def available():
        return all(shutil.which(exe) for exe in ("tmux", "stty"))

    def tmux(self, *args, check=True, timeout=8):
        p = subprocess.run(["tmux", "-S", str(self.socket), *args],
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           text=True, errors="replace", timeout=timeout)
        if check and p.returncode:
            raise PTYError("tmux command failed: " + repr(args) +
                           " code=" + str(p.returncode) + " " + p.stderr[-600:])
        return p

    def start(self):
        if not self.available():
            raise PTYError("tmux and stty required for real terminal fixture")
        script = self.artifact_dir / "launch.sh"
        script.write_text(
            "#!/bin/sh\n"
            "cd " + shlex.quote(str(self.cwd)) + " || exit 125\n"
            "stty -g > " + shlex.quote(str(self.artifact_dir / "before.stty")) + "\n"
            + shlex.join(self.command) + " 2> " +
            shlex.quote(str(self.artifact_dir / "stderr.log")) + "\n"
            "code=$?\n"
            "stty -g > " + shlex.quote(str(self.artifact_dir / "after.stty")) + "\n"
            "printf '%s\\n' \"$code\" > " + shlex.quote(str(self.artifact_dir / "exit-code")) + "\n"
            "printf '\\nWB_QA_PROCESS_EXIT:%s\\n' \"$code\"\n"
            "sleep 15\n", encoding="utf-8"
        )
        script.chmod(0o700)
        self.tmux("-f", "/dev/null", "new-session", "-d", "-s", "wb-qa",
                  "-x", str(self.cols), "-y", str(self.rows),
                  "sh " + shlex.quote(str(script)))
        self.started = True
        self.tmux("set-option", "-g", "status", "off")
        self.tmux("pipe-pane", "-t", "wb-qa:0.0",
                  "cat >> " + shlex.quote(str(self.artifact_dir / "terminal.raw")))
        self.record("launch", command=self.command, geometry=[self.cols, self.rows],
                    raw_capture_warning="pipe-pane starts after session creation; early startup bytes may be missed")
        return self

    def record(self, event, **payload):
        self.trace.append({"at_monotonic": time.monotonic(), "event": event, **payload})

    def info(self):
        fmt = "#{cursor_x}|#{cursor_y}|#{cursor_flag}|#{window_width}|#{window_height}"
        p = self.tmux("display-message", "-p", "-t", "wb-qa:0.0", fmt)
        values = p.stdout.strip().split("|")
        if len(values) != 5:
            raise PTYError("cannot obtain tmux terminal cursor/geometry")
        return {"cursor_x": int(values[0]), "cursor_y": int(values[1]),
                "cursor_visible": values[2] == "1", "cols": int(values[3]),
                "rows": int(values[4])}

    def snapshot(self, label):
        # tmux is the ANSI emulator; capture-pane is its actual interpreted cells.
        screen = self.tmux("capture-pane", "-p", "-J", "-t", "wb-qa:0.0").stdout
        metadata = self.info()
        index = len([item for item in self.trace if item["event"] == "snapshot"])
        name = "frame-%03d" % index
        (self.artifact_dir / (name + ".txt")).write_text(screen, encoding="utf-8")
        self.record("snapshot", label=label, file=name + ".txt", **metadata)
        return screen, metadata

    def wait(self, predicate, label, timeout=None):
        deadline = time.monotonic() + (timeout or self.timeout)
        while time.monotonic() < deadline:
            screen, state = self.snapshot(label)
            if predicate(screen, state):
                return screen, state
            if (self.artifact_dir / "exit-code").exists():
                raise PTYError("process exited while waiting for " + label)
            time.sleep(0.06)
        raise PTYError("timed out waiting for " + label)

    def expect(self, value, timeout=None):
        return self.wait(lambda screen, _: value in screen, "visible:" + value,
                         timeout=timeout)

    def key(self, key):
        self.record("key", value=key)
        self.tmux("send-keys", "-t", "wb-qa:0.0", key)

    def text(self, value):
        self.record("text", value=value)
        self.tmux("send-keys", "-t", "wb-qa:0.0", "-l", value)

    def resize(self, cols, rows):
        self.tmux("resize-window", "-t", "wb-qa:0", "-x", str(cols), "-y", str(rows))
        self.record("resize", cols=cols, rows=rows)
        actual = self.info()
        if (actual["cols"], actual["rows"]) != (cols, rows):
            raise PTYError("resize failed: " + repr(actual))
        self.cols, self.rows = cols, rows
        return self.snapshot("resized")

    def idle_bytes(self, duration=0.35):
        path = self.artifact_dir / "terminal.raw"
        initial = path.stat().st_size if path.exists() else 0
        time.sleep(duration)
        final = path.stat().st_size if path.exists() else 0
        self.record("idle", duration=duration, initial=initial, final=final,
                    delta=final - initial)
        return final - initial

    def finish(self, key="C-d", timeout=9):
        if key:
            self.key(key)
        exit_file = self.artifact_dir / "exit-code"
        deadline = time.monotonic() + timeout
        while not exit_file.exists() and time.monotonic() < deadline:
            time.sleep(.05)
        if not exit_file.exists():
            raise PTYError("app did not exit after " + repr(key))
        code = int(exit_file.read_text().strip())
        before = (self.artifact_dir / "before.stty").read_text().strip()
        after = (self.artifact_dir / "after.stty").read_text().strip()
        screen, state = self.snapshot("after-exit")
        self.record("finish", code=code, termios_restored=(before == after),
                    cursor_visible=state["cursor_visible"],
                    shell_sentinel=("WB_QA_PROCESS_EXIT:" in screen))
        return {"exit_code": code, "termios_restored": before == after,
                "cursor_visible": state["cursor_visible"],
                "shell_sentinel": "WB_QA_PROCESS_EXIT:" in screen}

    def close(self):
        if self.closed:
            return
        self.closed = True
        try:
            if self.started:
                self.snapshot("final")
        except (OSError, subprocess.SubprocessError, PTYError):
            pass
        try:
            if self.started:
                self.tmux("kill-server", check=False)
        except (OSError, subprocess.SubprocessError):
            pass
        (self.artifact_dir / "timeline.json").write_text(
            json.dumps(self.trace, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8")
        self.started = False
        shutil.rmtree(self.socket_root, ignore_errors=True)

    def __enter__(self):
        return self.start()

    def __exit__(self, *args):
        self.close()
