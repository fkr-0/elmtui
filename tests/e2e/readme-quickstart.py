#!/usr/bin/env python3
"""Release gate: the README Quickstart application works as documented.

Extracts the Lisp block named `quickstart-counter` from README.org, runs it
the way the README says (load `elmtui`, load the file, call RUN-COUNTER) in a
private tmux server over 20 lines of shell history, and requires:

  * the counter renders and follows + + + - to "Count: 2",
  * no framework log lines reach the screen,
  * q quits with exit status 0, identical stty and a visible cursor,
  * the shell history is intact and nothing switched to the alternate screen.

Run: python3 tests/e2e/readme-quickstart.py
"""
import importlib.util
from pathlib import Path
import re
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "readme_quickstart_harness", ROOT / "scripts/test-terminal-apps.py")
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)

MARKER = re.compile(r"HISTORY-MARKER-(\d{2})")


def quickstart_source():
    readme = (ROOT / "README.org").read_text()
    match = re.search(r"#\+name: quickstart-counter\n#\+begin_src lisp\n(.*?)\n#\+end_src",
                      readme, re.S)
    if not match:
        raise AssertionError("README.org has no #+name: quickstart-counter Lisp block")
    return match.group(1) + "\n"


class Options:
    terminal = "tmux"
    timeout = 120
    output = None


class ReadmeQuickstart(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="elmtui-readme-quickstart-")
        Options.output = Path(cls.tmp.name)
        harness.OPTIONS = Options()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_website_quickstart_shows_the_same_code(self):
        site = (ROOT / "website/quickstart.md").read_text()
        self.assertIn("```lisp\n" + quickstart_source() + "```", site,
                      "website/quickstart.md must show the README quickstart code")

    def test_quickstart_counter_runs_as_documented(self):
        source = Options.output / "counter.lisp"
        source.write_text(quickstart_source())
        prelude = 'for n in $(seq -w 1 20); do printf "HISTORY-MARKER-%s\\n" "$n"; done'
        app = harness.TerminalApp(
            "readme-counter", None, prelude=prelude, use_launcher=False,
            command=["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
                     "--noinform", "--non-interactive",
                     "--eval", "(require :asdf)",
                     "--eval", '(asdf:load-system "elmtui")',
                     "--load", str(source), "--eval", "(counter:run-counter)"])
        app.start()
        self.addCleanup(app.close)
        app.expect("Count: 0")
        for key in "+++-":
            app.key(key, literal=True)
            time.sleep(.3)
        app.expect("Count: 2")
        screen = app.screen()
        for noise in ("<INFO>", "<WARN>", "<ERROR>", "DRIVER:"):
            self.assertNotIn(noise, screen, "framework log output reached the screen")
        app.key("q", literal=True)
        app.wait(lambda text: "ELMTUI_E2E_SHELL_RESTORED" in text, "quickstart app exited", allow_exit=True)
        self.assertEqual((app.directory / "exit-code").read_text().strip(), "0",
                         (app.directory / "stderr.txt").read_text()[-2000:])
        self.assertEqual((app.directory / "before.stty").read_text(),
                         (app.directory / "after.stty").read_text())
        self.assertEqual(app.tmux("display-message", "-p", "-t", "app:0.0",
                                  "#{cursor_flag}").stdout.strip(), "1")
        history = app.tmux("capture-pane", "-p", "-S", "-", "-t", "app:0.0").stdout
        self.assertEqual([int(n) for n in MARKER.findall(history)], list(range(1, 21)))
        raw = (app.directory / "terminal.raw").read_bytes()
        for sequence in (b"\x1b[?1049h", b"\x1b[?1047h", b"\x1b[?47h", b"\x1b[2J", b"\x1b[3J"):
            self.assertNotIn(sequence, raw)


if __name__ == "__main__":
    unittest.main(verbosity=2)
