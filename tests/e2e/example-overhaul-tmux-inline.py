#!/usr/bin/env python3
"""Real PTY checks: no alternate screen, ElmTUI shutdown, preserved history."""
import importlib.util
from pathlib import Path
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("terminal_harness", ROOT / "scripts/test-terminal-apps.py")
h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)


class Options:
    terminal = "tmux"
    timeout = 12
    output = None


class NormalBufferInspector(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="elmtui-inline-")
        Options.output = Path(cls.tmp.name)
        h.OPTIONS = Options()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_80x24_120x40_both_runners(self):
        commands = {
            "hover": "(elmtui-examples.tmux-hover-demo:run-tmux-hover-demo)",
            "cursor": "(elmtui-examples.cursor-inspector:run-cursor-inspector)",
        }
        for cols, rows in ((80, 24), (120, 40)):
            for name, command in commands.items():
                with self.subTest(cols=cols, rows=rows, name=name):
                    ready = Options.output / f"{name}-{cols}-{rows}.ready"
                    start = Options.output / f"{name}-{cols}-{rows}.start"
                    prelude = (
                        f'until test -e "{start}"; do sleep .05; done\n'
                        'for n in $(seq -w 1 70); do printf "HISTORY-MARKER-%s\\n" "$n"; done\n'
                        'printf "UNDERLAY-ALPHA\\nUNDERLAY-BETA\\n"\n'
                        f'until test -e "{ready}"; do sleep .05; done'
                    )
                    app = h.TerminalApp(name, command, prelude=prelude, use_launcher=False)
                    try:
                        app.start()
                        app.tmux("resize-window", "-t", "app:0", "-x", str(cols), "-y", str(rows))
                        start.touch()
                        app.expect("UNDERLAY-BETA")
                        original = app.tmux("capture-pane", "-p", "-S", "-", "-t", "app:0.0").stdout
                        self.assertEqual(original.count("HISTORY-MARKER-"), 70)
                        ready.touch()
                        app.wait(lambda _: b"\x1b[6n" in
                                 (app.directory / "terminal.raw").read_bytes(), "terminal query")
                        time.sleep(.7)
                        idle = (app.directory / "terminal.raw").read_bytes()
                        time.sleep(.6)
                        self.assertEqual(idle, (app.directory / "terminal.raw").read_bytes())
                        app.key("q", literal=True)
                        app.wait(lambda screen: "ELMTUI_E2E_SHELL_RESTORED" in screen,
                                 "shell after inspector exit")
                        trace = (app.directory / "terminal.raw").read_bytes()
                        for alt in (b"\x1b[?1049h", b"\x1b[?1049l",
                                    b"\x1b[?1047h", b"\x1b[?1047l",
                                    b"\x1b[?47h", b"\x1b[?47l"):
                            self.assertNotIn(alt, trace)
                        self.assertEqual((app.directory / "exit-code").read_text().strip(), "0")
                        self.assertEqual((app.directory / "before.stty").read_text(),
                                         (app.directory / "after.stty").read_text())
                        history = app.tmux("capture-pane", "-p", "-S", "-", "-t", "app:0.0").stdout
                        self.assertEqual(history.count("HISTORY-MARKER-"), 70)
                        self.assertEqual(history.count("UNDERLAY-ALPHA"), 1)
                        self.assertEqual(history.count("UNDERLAY-BETA"), 1)
                    finally:
                        app.close()


if __name__ == "__main__":
    unittest.main(verbosity=2)
