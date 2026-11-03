#!/usr/bin/env python3
"""Release gate: a DEFTEA-APP application runs in a real terminal.

0.3.1 shipped DEFTEA-APP runners that drew nothing and failed on shutdown;
only their macroexpansion was tested. This runs a direct-model counter in a
private tmux server over shell history and requires:

  * the view renders below the cursor, and + increments it,
  * a transition returning :SHOULD-QUIT T exits with status 0, and so does
    Ctrl-C (the runtime's (:APP-QUIT-REQUESTED)),
  * stty, the cursor and the history are restored.

Run: python3 tests/e2e/deftea-app-pty.py
"""
import importlib.util
from pathlib import Path
import re
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "deftea_app_harness", ROOT / "scripts/test-terminal-apps.py")
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)

MARKER = re.compile(r"HISTORY-MARKER-(\d{2})")

PROGRAM = """
(uiop:define-package :tea-gate
  (:use :cl)
  (:import-from :elmtui.app.tea-core #:deftea-app)
  (:import-from :elmtui.app #:key-pressed-p))
(in-package :tea-gate)

(defun init () (values '(:count 0) nil))

(defun transition (message model)
  (cond ((key-pressed-p message :char #\\+)
         (values (list :count (1+ (getf model :count))) nil))
        ((key-pressed-p message :char #\\q)
         (values (list :count (getf model :count) :should-quit t) nil))
        (t (values model nil))))

(defun view (model)
  `(:root-viewport :id :tea-root
    :children ((:text :id :value
                :content ,(format nil "Tea count: ~D" (getf model :count))))))

(deftea-app tea-gate
  :init #'init :transition #'transition :view #'view
  :root-viewport-id :tea-root :height 1)
"""


class Options:
    terminal = "tmux"
    timeout = 120
    output = None


class DefteaAppPTY(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="elmtui-deftea-")
        Options.output = Path(cls.tmp.name)
        harness.OPTIONS = Options()
        cls.source = Options.output / "tea-gate.lisp"
        cls.source.write_text(PROGRAM)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def launch(self, name):
        prelude = 'for n in $(seq -w 1 20); do printf "HISTORY-MARKER-%s\\n" "$n"; done'
        app = harness.TerminalApp(
            name, None, prelude=prelude, use_launcher=False,
            command=["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
                     "--noinform", "--non-interactive",
                     "--eval", "(require :asdf)",
                     "--eval", '(asdf:load-system "elmtui")',
                     "--load", str(self.source),
                     "--eval", "(tea-gate::run-tea-gate)"])
        app.start()
        self.addCleanup(app.close)
        app.expect("Tea count: 0")
        return app

    def assert_clean_exit(self, app):
        # The wrapper records exit status before tmux consumes its final output.
        app.wait(lambda text: "ELMTUI_E2E_SHELL_RESTORED" in text,
                 "deftea app exited", allow_exit=True)
        self.assertEqual((app.directory / "exit-code").read_text().strip(), "0",
                         (app.directory / "stderr.txt").read_text()[-2000:])
        self.assertEqual((app.directory / "before.stty").read_text(),
                         (app.directory / "after.stty").read_text())
        self.assertEqual(app.tmux("display-message", "-p", "-t", "app:0.0",
                                  "#{cursor_flag}").stdout.strip(), "1")
        history = app.tmux("capture-pane", "-p", "-S", "-", "-t", "app:0.0").stdout
        self.assertEqual([int(n) for n in MARKER.findall(history)], list(range(1, 21)))

    def test_model_quit_after_key_updates(self):
        app = self.launch("deftea-keys")
        app.key("+", literal=True)
        time.sleep(.3)
        app.key("+", literal=True)
        app.expect("Tea count: 2")
        app.key("q", literal=True)
        self.assert_clean_exit(app)

    def test_ctrl_c_quits(self):
        app = self.launch("deftea-ctrl-c")
        app.key("C-c")
        self.assert_clean_exit(app)


if __name__ == "__main__":
    unittest.main(verbosity=2)
