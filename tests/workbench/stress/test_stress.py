#!/usr/bin/env python3
"""Bounded, reproducible W1-W4 black-box stress tests; W5 checks are opt-in.

Run: python3 -m unittest discover -s tests/workbench/stress -p 'test_*.py' -v
Tuning: WB08_SEED=20261009 WB08_ROUNDS=32 WB08_TIMEOUT=18
No source package, ASDF file or shared runtime is modified by this runner.
"""
from __future__ import annotations

import os
import random
import shlex
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
MODULES = {
    "editor": ROOT / "src/workbench/editor.lisp",
    "eval": ROOT / "src/workbench/eval.lisp",
    "completion": ROOT / "src/workbench/completion.lisp",
    "docs": ROOT / "src/workbench/docs.lisp",
    "inspector": ROOT / "src/workbench/inspector.lisp",
}
SEED = int(os.environ.get("WB08_SEED", "20261009"))
ROUNDS = int(os.environ.get("WB08_ROUNDS", "32"))
TIMEOUT = float(os.environ.get("WB08_TIMEOUT", "18"))
if not 1 <= ROUNDS <= 128 or not 3 <= TIMEOUT <= 30:
    raise ValueError("WB08_ROUNDS must be 1..128; WB08_TIMEOUT must be 3..30 seconds")


def lisp_string(value: str) -> str:
    """Quote Unicode for Common Lisp (not JavaScript-style \\u sequences)."""
    if any(ord(char) < 32 for char in value):
        raise ValueError("No control characters in generated forms")
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def run_probe(modules: tuple[str, ...], body: str, *, timeout: float = TIMEOUT):
    """Run actual W1-W4 modules in a fresh CLPM/SBCL process, never via shell."""
    args = [
        "clpm", "bundle", "exec", "--with-client", "sbcl", "--",
        "--noinform", "--non-interactive", "--no-sysinit", "--no-userinit",
        "--eval", "(require :asdf)",
    ]
    for module in modules:
        args.extend(("--load", str(MODULES[module])))
    args.extend(("--eval", '(progn ' + body + ' (format t "~&WB08-PASS~%"))'))
    return subprocess.run(args, cwd=ROOT, capture_output=True, text=True,
                          timeout=timeout, check=False)


def editor_probe(seed: int, rounds: int) -> str:
    rng = random.Random(seed)
    fragments = ("a", "λ", "界", "e\u0301", "👩\u200d💻", "🙂", "x")
    forms = ['(let ((s (elmtui.workbench.editor:make-editor-state :columns 18)) (oracle ""))']
    expected = ""
    for index in range(rounds):
        frag = rng.choice(fragments)
        expected += frag
        columns = rng.choice((8, 18, 80))
        forms.append(f'(elmtui.workbench.editor:editor-insert-text s {lisp_string(frag)})')
        forms.append(f"(setf oracle (concatenate 'string oracle {lisp_string(frag)}))")
        forms.append(f'(unless (string= (elmtui.workbench.editor:editor-text s) oracle) (error "WB08 insert step {index}"))')
        forms.append("(elmtui.workbench.editor:editor-undo s)")
        forms.append(f'(unless (string= (elmtui.workbench.editor:editor-text s) (subseq oracle 0 (- (length oracle) {len(frag)}))) (error "WB08 undo step {index}"))')
        forms.append("(elmtui.workbench.editor:editor-redo s)")
        forms.append(f'(unless (string= (elmtui.workbench.editor:editor-text s) oracle) (error "WB08 redo step {index}"))')
        forms.append(f"(elmtui.workbench.editor:editor-resize s {columns})")
        forms.append(f'(multiple-value-bind (x y) (elmtui.workbench.editor:editor-cursor-screen-position s) (unless (and (<= 0 x) (< x {columns}) (<= 0 y)) (error "WB08 cell geometry step {index}")))')
    forms.append(f'(unless (string= oracle {lisp_string(expected)}) (error "WB08 final independent oracle"))')
    forms.append(")")
    forms.append(r'''
(let ((s (elmtui.workbench.editor:make-editor-state :text "é👩‍💻")))
  (elmtui.workbench.editor:editor-backspace s)
  (unless (string= "é" (elmtui.workbench.editor:editor-text s))
    (error "WB08 joined grapheme backspace"))
  (elmtui.workbench.editor:editor-undo s)
  (unless (string= "é👩‍💻" (elmtui.workbench.editor:editor-text s))
    (error "WB08 joined grapheme undo"))
  (elmtui.workbench.editor:editor-move-cursor s :left)
  (elmtui.workbench.editor:editor-move-cursor s :left)
  (unless (= 0 (elmtui.workbench.editor:editor-state-cursor s))
    (error "WB08 grapheme navigation")))
''')
    return "\n".join(forms)


EVAL_PROBE = r'''
(let ((a (elmtui.workbench.eval:make-repl-session))
      (b (elmtui.workbench.eval:make-repl-session)))
  (unwind-protect
    (progn
      (when (boundp 'cl-user::*wb08-reader-sentinel*)
        (makunbound 'cl-user::*wb08-reader-sentinel*))
      (elmtui.workbench.eval:request-evaluation a "(sleep 0.06)" 0)
      (elmtui.workbench.eval:request-evaluation
        a "#.(setf cl-user::*wb08-reader-sentinel* :executed)" 1)
      (unless (elmtui.workbench.eval:cancel-evaluation a 1)
        (error "WB08 queued cancellation failed"))
      (loop for i from 2 below (+ 2 :ROUNDS)
            do (elmtui.workbench.eval:request-evaluation
                 a (format nil "(+ ~d 1)" i) i))
      (loop for i from 0 below :ROUNDS
            do (elmtui.workbench.eval:request-evaluation
                 b (format nil "(+ ~d 100)" i) i))
      (labels ((collect-events (session expected)
                 (loop with all = nil
                       repeat 500
                       do (setf all (nconc all (elmtui.workbench.eval:poll-evaluation session)))
                          (when (= expected (count :finished all :key
                                          (lambda (item) (getf item :type))))
                            (return-from collect-events all))
                          (sleep 0.004)
                       finally (error "WB08 evaluator bounded timeout"))))
        (let* ((ea (collect-events a (+ :ROUNDS 2)))
               (eb (collect-events b :ROUNDS))
               (fa (remove-if-not (lambda (e) (eq (getf e :type) :finished)) ea))
               (fb (remove-if-not (lambda (e) (eq (getf e :type) :finished)) eb)))
          (unless (equal (mapcar (lambda (e) (getf e :request-id)) fa)
                         (loop for i below (+ :ROUNDS 2) collect i))
            (error "WB08 session A finish request order"))
          (unless (equal (mapcar (lambda (e) (getf e :request-id)) fb)
                         (loop for i below :ROUNDS collect i))
            (error "WB08 session B finish request order"))
          (unless (eq :aborted (getf (second fa) :status))
            (error "WB08 cancellation completion status"))
          (when (or (boundp 'cl-user::*wb08-reader-sentinel*)
                    (find-if (lambda (e) (and (eql 1 (getf e :request-id))
                                              (eq :value (getf e :type)))) ea))
            (error "WB08 cancelled queued read-time side effect"))
          (unless (every (lambda (e) (eq :ok (getf e :status)))
                         (remove (second fa) fa))
            (error "WB08 A finished with errors"))
          (unless (every (lambda (e) (eq :ok (getf e :status))) fb)
            (error "WB08 B finished with errors"))
          (loop for i from 2 below (+ 2 :ROUNDS)
                for ev = (find-if (lambda (e) (and (eq :value (getf e :type))
                                                   (eql i (getf e :request-id)))) ea)
                unless (and ev (string= (getf ev :text) (write-to-string (1+ i))))
                  do (error "WB08 incorrect A value id ~d" i))
          (loop for i below :ROUNDS
                for ev = (find-if (lambda (e) (and (eq :value (getf e :type))
                                                   (eql i (getf e :request-id)))) eb)
                unless (and ev (string= (getf ev :text) (write-to-string (+ i 100))))
                  do (error "WB08 incorrect B value id ~d" i)))))
    (elmtui.workbench.eval:close-repl-session a)
    (elmtui.workbench.eval:close-repl-session b)))
'''


COMPLETION_PROBE = r'''
(let ((state (elmtui.workbench.completion:make-documentation-dwell-state))
      (sentinel 'cl-user::*wb08-completion-sentinel*))
  (when (boundp sentinel) (makunbound sentinel))
  (loop for generation from 1 to :ROUNDS
        for source = "(mapc"
        for old = (elmtui.workbench.completion:complete-at
                    nil source (length source) generation :limit 16)
        do (unless (elmtui.workbench.completion:completion-current-p old generation)
             (error "WB08 completion current generation"))
           (when (elmtui.workbench.completion:completion-current-p
                   old (1+ generation))
             (error "WB08 stale completion accepted"))
           (unless (find "MAPCAR"
                         (elmtui.workbench.completion:completion-result-candidates old)
                         :key #'elmtui.workbench.completion:completion-candidate-display
                         :test #'string=)
             (error "WB08 expected MAPCAR candidate"))
           (let ((now (* generation 1000))
                 (delta (ceiling (* 450 internal-time-units-per-second) 1000)))
             (elmtui.workbench.completion:schedule-documentation-dwell
               state "candidate-a" generation :now now :delay-ms 450)
             (when (elmtui.workbench.completion:documentation-dwell-due-p
                     state generation "candidate-a" :now (+ now delta -1))
               (error "WB08 docs too early"))
             (when (elmtui.workbench.completion:documentation-dwell-due-p
                     state (1- generation) "candidate-a" :now (+ now delta))
               (error "WB08 docs stale generation"))
             (when (elmtui.workbench.completion:documentation-dwell-due-p
                     state generation "candidate-b" :now (+ now delta))
               (error "WB08 docs stale selection"))
             (unless (equal (elmtui.workbench.completion:consume-documentation-dwell
                              state generation "candidate-a" :now (+ now delta))
                            (list :wb-doc-dwell :generation generation
                                  :candidate-id "candidate-a"))
               (error "WB08 450ms docs consumption"))
             (when (elmtui.workbench.completion:consume-documentation-dwell
                     state generation "candidate-a" :now (+ now delta))
               (error "WB08 duplicated docs event")))
        do (let* ((source "(#.(setf cl-user::*wb08-completion-sentinel* t) mapc")
                  (candidate (elmtui.workbench.completion:complete-at
                               nil source (length source) (1+ generation) :limit 8)))
             (unless (elmtui.workbench.completion:completion-current-p
                       candidate (1+ generation))
               (error "WB08 dispatch-form completion generation"))))
  (when (boundp sentinel) (error "WB08 passive read-eval occurred"))
  (elmtui.workbench.completion:schedule-documentation-dwell
    state "old" 77 :now 0 :delay-ms 450)
  (elmtui.workbench.completion:cancel-documentation-dwell state)
  (when (elmtui.workbench.completion:documentation-dwell-due-p
          state 77 "old" :now 999999999)
    (error "WB08 cancelled docs timer fired")))
'''


INSPECTOR_PROBE = r'''
(let* ((session (elmtui.workbench.inspector:make-inspector-session
                  :max-items 40 :max-depth 4 :max-length 16 :max-preview 25))
       (cycle (make-array 40 :initial-element 13))
       (handle nil))
  (setf (aref cycle 0) cycle)
  (setf handle (elmtui.workbench.inspector:register-object session cycle))
  (loop for request from 0 below :ROUNDS
        for page = (mod request 5)
        for answer = (elmtui.workbench.inspector:inspect-object
                       session handle request :page page :page-size 4)
        for tree = (getf answer :object)
        do (unless (and (eq :ok (getf answer :status))
                        (eql request (getf answer :request-id))
                        (<= (length (getf tree :children)) 4)
                        (<= (length (getf tree :preview)) 25))
             (error "WB08 bounded inspection request ~d" request))
           (when (zerop page)
             (unless (getf (getf (first (getf tree :children)) :value) :cycle)
               (error "WB08 cyclic vector not tagged"))))
  (loop for generation from 1 to :ROUNDS
        for page = (mod generation 6)
        for snapshot = (elmtui.workbench.inspector:snapshot-image
                         session generation :section :packages :page page
                         :page-size 7)
        do (unless (and (eq :ok (getf snapshot :status))
                        (eql generation (getf snapshot :generation))
                        (<= (getf snapshot :total) 40)
                        (<= (length (getf snapshot :entries)) 7))
             (error "WB08 bounded paginated snapshot ~d" generation)))
  (let* ((first (elmtui.workbench.inspector:snapshot-image
                  session 444 :section :packages))
         (name (symbol-name (gensym "WB08-REFRESH-"))))
    (unwind-protect
      (progn
        (make-package name)
        (unless (= (getf first :total)
                   (getf (elmtui.workbench.inspector:snapshot-image
                           session 444 :section :packages) :total))
          (error "WB08 same-generation snapshot cache changed"))
        (unless (eq :ok (getf (elmtui.workbench.inspector:snapshot-image
                               session 445 :section :packages :refresh t) :status))
          (error "WB08 refreshed inspector failed")))
      (when (find-package name) (delete-package name)))))
'''


class BoundedStress(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        absent = [tool for tool in ("clpm", "sbcl") if not shutil.which(tool)]
        if absent:
            raise unittest.SkipTest("Missing CLPM/SBCL: " + ", ".join(absent))

    def assert_probe(self, names, body):
        missing = [name for name in names if not MODULES[name].is_file()]
        if missing:
            self.skipTest("Source module NOT RUN: " + ", ".join(missing))
        try:
            result = run_probe(names, body)
        except subprocess.TimeoutExpired as exc:
            self.fail(f"Bounded timeout {TIMEOUT}s seed={SEED} rounds={ROUNDS}: {exc}")
        self.assertEqual(result.returncode, 0,
                         f"seed={SEED} rounds={ROUNDS}\n{result.stdout[-3000:]}\n{result.stderr[-6000:]}")
        self.assertIn("WB08-PASS", result.stdout, result.stdout[-3000:])

    def test_w1_seeded_graphemes_undo_redo_resize(self):
        self.assert_probe(("editor",), editor_probe(SEED, ROUNDS))

    def test_w2_concurrent_sessions_request_ids_and_readtime_cancel(self):
        self.assert_probe(("eval",), EVAL_PROBE.replace(":ROUNDS", str(ROUNDS)))

    def test_w3_stale_generation_and_exact_450ms_dwell(self):
        self.assert_probe(("completion", "docs"), COMPLETION_PROBE.replace(":ROUNDS", str(ROUNDS)))

    def test_w4_bounded_cyclic_inspector_pages(self):
        self.assert_probe(("inspector",), INSPECTOR_PROBE.replace(":ROUNDS", str(ROUNDS)))


# These are real-application gates, not fake fixture substitutes. W5 currently
# has no launcher; a populated variable must point to a real workbench process.
_REAL_CMD = os.environ.get("ELMTUI_WORKBENCH_TEST_CMD", "").strip()


@unittest.skipUnless(_REAL_CMD, "NOT RUN: no W5 real workbench launcher / command")
class WorkbenchApplicationStress(unittest.TestCase):
    def test_repeat_start_exit_burst_keys_and_resize(self):
        sys.path.insert(0, str(ROOT / "tests/workbench/independent"))
        from pty_driver import PrivateTmuxPTY
        if not PrivateTmuxPTY.available():
            self.skipTest("NOT RUN: private tmux/stty unavailable")
        for iteration in range(2):
            with self.subTest(restart=iteration):
                with PrivateTmuxPTY(shlex.split(_REAL_CMD), cols=80, rows=24,
                                    timeout=10) as term:
                    term.wait_for(os.environ.get("ELMTUI_WORKBENCH_READY_PATTERN",
                                                 r"CL-USER|Lisp Workbench"), timeout=12)
                    for cols, rows in ((120, 40), (160, 50), (80, 24)):
                        term.resize(cols, rows)
                        self.assertEqual((cols, rows), term.geometry())
                    term.send_text("xyzxyz")
                    for _ in range(6):
                        term.send_key("BSpace")
                    term.send_text("(+ 11 13)")
                    term.send_key("Enter")
                    term.wait_for(r"\b24\b", timeout=8)
                    term.send_key("C-d")
                    exit_code, restored = term.wait_for_exit(timeout=8)
                    self.assertEqual(exit_code, 0)
                    self.assertTrue(restored)

    def test_real_raw_pty_idle_writes_and_cpu(self):
        from pty_probe import RealPTY
        with RealPTY(shlex.split(_REAL_CMD), ROOT) as term:
            term.wait_for(os.environ.get("ELMTUI_WORKBENCH_READY_PATTERN",
                                         r"CL-USER|Lisp Workbench"), 12)
            # Allow start-up paint and delayed docs to settle before sampling.
            term.drain(0.75)
            pid = term.sbcl_pid()
            if pid is None:
                self.skipTest("NOT RUN: cannot identify real SBCL process for CPU measurement")
            self.assertTrue(term.editor_echo_disabled(),
                            "PTY echo must be disabled; otherwise dirty-frame writes are ambiguous")
            before = term.cpu_ticks(pid)
            idle_bytes = term.drain(0.55)
            after = term.cpu_ticks(pid)
            self.assertEqual(idle_bytes, b"", "Idle W5 issued raw terminal writes")
            self.assertEqual(before, after, "Idle W5 consumed SBCL CPU ticks")
            term.send(b"x")
            self.assertTrue(term.drain(0.5), "Edited frame produced no terminal writes")
            self.assertEqual(term.drain(0.55), b"",
                             "Unchanged frame continued writing terminal bytes")
            term.send(b"\x7f")
            term.drain(0.2)
            term.send(b"\x04")
            # RealPTY has no synthetic sentinel; require actual process exit.
            deadline = __import__("time").monotonic() + 8
            while term.process.poll() is None and __import__("time").monotonic() < deadline:
                term.drain(0.05)
            self.assertEqual(term.process.poll(), 0, "Ctrl+D did not quit W5")
            self.assertTrue(term.terminal_restored(), "W5 failed to restore termios")

    def test_real_ctrl_c_cancel_responsiveness(self):
        from pty_probe import RealPTY
        with RealPTY(shlex.split(_REAL_CMD), ROOT) as term:
            term.wait_for(os.environ.get("ELMTUI_WORKBENCH_READY_PATTERN",
                                         r"CL-USER|Lisp Workbench"), 12)
            term.drain(0.2)
            term.send(b"(sleep 0.5)\r")
            term.drain(0.10)
            term.output.clear()  # Ignore static help text before Ctrl+C.
            term.send(b"\x03")
            term.wait_for(os.environ.get("ELMTUI_WORKBENCH_CANCEL_PATTERN",
                                         r"cancel|abort|interrupt"), 1.0)
            # A running trusted Lisp form cannot be arbitrarily preempted:
            # only verify immediate UI feedback; do not require forced exit.
            term.send(b"\x04")


if __name__ == "__main__":
    unittest.main(verbosity=2)
