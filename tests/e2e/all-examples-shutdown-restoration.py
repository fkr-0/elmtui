#!/usr/bin/env python3
"""Shutdown restoration sweep for every maintained example (release gate).

Each catalogued example is launched through the real launcher
(scripts/examples.sh run NAME) inside a private tmux server, on top of 70
numbered history markers. After the app has painted it is quit with its
documented key, and the shell must regain:

  * exit status 0 and byte-identical stty (terminal mode),
  * a visible cursor (tmux cursor_flag),
  * every history marker exactly once, in order (normal-screen scrollback),
  * no alternate-screen or full-screen/scrollback erase sequences.

Examples that need hardware or services the sandbox cannot provide are listed
in EXCLUDED with the reason; every other launcher entry must pass.

Run: python3 tests/e2e/all-examples-shutdown-restoration.py
"""
import importlib.util
from pathlib import Path
import re
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "all_examples_harness", ROOT / "scripts/test-terminal-apps.py")
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)

MARKER = re.compile(r"HISTORY-MARKER-(\d{2})")
FORBIDDEN = (b"\x1b[?1049h", b"\x1b[?1049l", b"\x1b[?1047h", b"\x1b[?1047l",
             b"\x1b[?47h", b"\x1b[?47l", b"\x1b[2J", b"\x1b[3J")

# Key sequences that quit each example; anything unlisted quits with "q".
QUIT_KEYS = {
    "mini-text-editor": ["C-q"],
    "neon-nano": ["C-x"],
    "repl": ["C-d"],
}

EXCLUDED = {
    "repl": "interactive Lisp REPL; covered by Workbench PTY qualification",
    "fzy-picker": "needs the optional cl-fzy system, not part of the locked bundle",
}


class Options:
    terminal = "tmux"
    timeout = 40
    output = None


def launcher_examples():
    result = subprocess.run([str(ROOT / "scripts/examples.sh"), "list"],
                            capture_output=True, text=True, timeout=300,
                            check=True)
    return [line.strip() for line in result.stdout.splitlines()
            if re.fullmatch(r"[a-z0-9-]+", line.strip())]


def markers(text):
    return [int(n) for n in MARKER.findall(text)]


class AllExamplesShutdownRestoration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="elmtui-all-examples-")
        Options.output = Path(cls.tmp.name)
        harness.OPTIONS = Options()
        cls.examples = launcher_examples()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def history(self, app):
        return app.tmux("capture-pane", "-p", "-S", "-", "-t", "app:0.0").stdout

    def exercise(self, name):
        gate = Options.output / f"{name}.start"
        prelude = ('for n in $(seq -w 1 70); do printf "HISTORY-MARKER-%s\\n" "$n"; done\n'
                   f'until test -e "{gate}"; do sleep .05; done')
        app = harness.TerminalApp(
            f"sweep-{name}", None, prelude=prelude, use_launcher=False,
            command=[str(ROOT / "scripts/examples.sh"), "run", name])
        app.start()
        self.addCleanup(app.close)
        app.expect("HISTORY-MARKER-70")
        baseline = self.history(app)
        self.assertEqual(markers(baseline), list(range(1, 71)), "broken oracle")
        idle_screen = app.screen()
        gate.touch()
        app.wait(lambda screen: screen != idle_screen, f"{name} painted")
        time.sleep(1.0)  # let startup frames settle before quitting
        keys = QUIT_KEYS.get(name, ["q"])
        deadline = time.monotonic() + 15
        for key in keys + ["Escape", "C-c"]:
            app.key(key, literal=(len(key) == 1))
            until = time.monotonic() + 4
            while time.monotonic() < until and not (app.directory / "exit-code").exists():
                time.sleep(.1)
            if (app.directory / "exit-code").exists() or time.monotonic() > deadline:
                break
        app.wait(lambda screen: "ELMTUI_E2E_SHELL_RESTORED" in screen,
                 f"{name} returned to the shell")
        self.assertEqual((app.directory / "exit-code").read_text().strip(), "0",
                         f"{name} exit status")
        self.assertEqual((app.directory / "before.stty").read_text(),
                         (app.directory / "after.stty").read_text(),
                         f"{name} terminal mode restored")
        self.assertEqual(app.tmux("display-message", "-p", "-t", "app:0.0",
                                  "#{cursor_flag}").stdout.strip(), "1",
                         f"{name} cursor visible after exit")
        restored = markers(self.history(app))
        self.assertEqual(restored, list(range(1, 71)),
                         f"{name} normal-screen scrollback must survive exactly")
        raw = (app.directory / "terminal.raw").read_bytes()
        for seq in FORBIDDEN:
            self.assertNotIn(seq, raw, f"{name} emitted forbidden {seq!r}")

    def test_every_maintained_example_restores_the_terminal(self):
        self.assertGreaterEqual(len(self.examples), 20, self.examples)
        for name in self.examples:
            if name in EXCLUDED:
                continue
            with self.subTest(example=name):
                self.exercise(name)


if __name__ == "__main__":
    unittest.main(verbosity=2)
