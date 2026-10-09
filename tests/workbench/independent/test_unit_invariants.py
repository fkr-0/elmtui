"""Independent source-level contracts for workbench W1-W4.

These tests consume public package APIs in fresh SBCL processes. They are not
duplicates of the owner-authored FiveAM tests. No implementation files are
modified; failures remain red rather than being auto-skipped.
"""
from __future__ import annotations

import unittest

from contract_driver import MARKER, required_tools, run_lisp


class IndependentModuleContracts(unittest.TestCase):
    def run_contract(self, names, form):
        missing = required_tools()
        if missing:
            self.skipTest(f"{missing} executable unavailable")
        try:
            result = run_lisp(tuple(names), form)
        except FileNotFoundError as error:
            self.skipTest(f"source package not created yet: {error}")
        except TimeoutError as error:
            self.fail(f"SBCL hung: {error}")
        except Exception as error:
            self.fail(f"SBCL execution failure: {error}")
        output = result.stdout + "\n" + result.stderr
        self.assertEqual(result.returncode, 0, output[-6500:])
        self.assertIn(MARKER, result.stdout, output[-6500:])

    def test_editor_multiline_submits_only_when_complete(self):
        self.run_contract(["editor"], r'''
          (let ((s (elmtui.workbench.editor:make-editor-state
                     :text "(defun wb-demo (x)")))
            (when (elmtui.workbench.editor:editor-balanced-p s)
              (error "Incomplete DEFUN misidentified as complete"))
            (elmtui.workbench.editor:editor-handle-key s :enter)
            (unless (search (string #\Newline)
                            (elmtui.workbench.editor:editor-text s))
              (error "Incomplete form did not insert multiline continuation"))
            (when (eq :submit (elmtui.workbench.editor:editor-state-last-action s))
              (error "Incomplete form unexpectedly submitted")))
        ''')

    def test_editor_unicode_wide_and_combining_screen_cells(self):
        self.run_contract(["editor"], r'''
          (let* ((input (concatenate 'string "a" (string (code-char #x0301))
                                      (string (code-char #x4E2D))))
                 (s (elmtui.workbench.editor:make-editor-state :text input)))
            (multiple-value-bind (col row)
                (elmtui.workbench.editor:editor-cursor-screen-position
                  s :origin-x 2 :origin-y 5)
              (unless (and (= col 5) (= row 5))
                (error "Wrong screen-cell position: ~S/~S" col row)))
            (elmtui.workbench.editor:editor-backspace s)
            (unless (= (length (elmtui.workbench.editor:editor-text s)) 2)
              (error "Failed to delete single wide-codepoint grapheme"))
            (elmtui.workbench.editor:editor-backspace s)
            (unless (string= (elmtui.workbench.editor:editor-text s) "")
              (error "Combining mark separated from grapheme base")))
        ''')

    def test_editor_history_restores_draft_and_undo_redo(self):
        self.run_contract(["editor"], r'''
          (let ((s (elmtui.workbench.editor:make-editor-state
                     :text "draft" :history '("(+ 2 3)" "(+ 1 2)"))))
            (elmtui.workbench.editor:editor-handle-key s :history-previous)
            (unless (string= "(+ 2 3)" (elmtui.workbench.editor:editor-text s))
              (error "Previous-history entry missing"))
            (elmtui.workbench.editor:editor-handle-key s :history-next)
            (unless (string= "draft" (elmtui.workbench.editor:editor-text s))
              (error "Unsent draft lost"))
            (elmtui.workbench.editor:editor-insert-text s "!")
            (elmtui.workbench.editor:editor-undo s)
            (unless (string= "draft" (elmtui.workbench.editor:editor-text s))
              (error "Undo failed"))
            (elmtui.workbench.editor:editor-redo s)
            (unless (string= "draft!" (elmtui.workbench.editor:editor-text s))
              (error "Redo failed")))
        ''')

    def test_editor_passive_reader_rejects_read_eval(self):
        self.run_contract(["editor"], r'''
          (progn
            (defvar *wb-read-eval-sentinel* nil)
            (setf *wb-read-eval-sentinel* nil)
            (let ((s (elmtui.workbench.editor:make-editor-state
                       :text "#.(progn (setf *wb-read-eval-sentinel* t) 3)")))
              (when (elmtui.workbench.editor:editor-balanced-p s)
                (error "Passive reader accepted #. form"))
              (when *wb-read-eval-sentinel*
                (error "Passive reader executed #. form"))))
        ''')

    def test_completion_package_qualified_span_and_identity(self):
        self.run_contract(["completion", "docs"], r'''
          (let* ((r (elmtui.workbench.completion:complete-at
                      (find-package :cl-user) "(cl:mapc" 8 :generation))
                 (hits (elmtui.workbench.completion:completion-result-candidates r)))
            (unless (and (= 4 (elmtui.workbench.completion:completion-result-start r))
                         (= 8 (elmtui.workbench.completion:completion-result-end r)))
              (error "Completion replacement span is incorrect"))
            (unless (find "MAPCAR" hits :test #'string=
                           :key #'elmtui.workbench.completion:completion-candidate-display)
              (error "Missing CL:MAPCAR completion"))
            (unless (elmtui.workbench.completion:completion-current-p r :generation)
              (error "Valid completion rejected"))
            (when (elmtui.workbench.completion:completion-current-p r :old)
              (error "Stale completion still current")))
        ''')

    def test_completion_dwell_requires_same_candidate_and_generation(self):
        self.run_contract(["completion", "docs"], r'''
          (let ((d (elmtui.workbench.completion:make-documentation-dwell-state)))
            (elmtui.workbench.completion:schedule-documentation-dwell
              d "MAPCAR" :g1 :now 1000 :delay-ms 450)
            (when (elmtui.workbench.completion:documentation-dwell-due-p
                   d :g1 "MAPCAR" :now 1000)
              (error "Documentation appeared before dwell deadline"))
            (when (elmtui.workbench.completion:documentation-dwell-due-p
                   d :g2 "MAPCAR" :now (+ 1000 internal-time-units-per-second))
              (error "Documentation response for stale generation accepted"))
            (unless (elmtui.workbench.completion:documentation-dwell-due-p
                     d :g1 "MAPCAR" :now (+ 1000 internal-time-units-per-second))
              (error "Documentation dwell never became due"))
            (elmtui.workbench.completion:cancel-documentation-dwell d)
            (when (elmtui.workbench.completion:documentation-dwell-due-p
                   d :g1 "MAPCAR" :now (+ 1000 internal-time-units-per-second))
              (error "Cancelled documentation appeared")))
        ''')

    def test_completion_does_not_read_eval_or_offer_comment_candidates(self):
        self.run_contract(["completion", "docs"], r'''
          (progn
            (defvar *wb-completion-sentinel* nil)
            (setf *wb-completion-sentinel* nil)
            (let* ((source "#.(progn (setf *wb-completion-sentinel* t) 9) (mapc")
                   (result (elmtui.workbench.completion:complete-at
                            nil source (length source) :safe)))
              (declare (ignore result))
              (when *wb-completion-sentinel*
                (error "Autocomplete triggered reader evaluation")))
            (let* ((source "(+ 1 ; mapc")
                   (result (elmtui.workbench.completion:complete-at
                            nil source (length source) :comment)))
              (when (elmtui.workbench.completion:completion-result-candidates result)
                (error "Completion inside a line comment is not empty"))))
        ''')

    def test_eval_persistence_multiple_values_and_no_terminal_print(self):
        self.run_contract(["eval"], r'''
          (let ((s (elmtui.workbench.eval:make-repl-session)) (events nil))
            (unwind-protect
                (progn
                  (elmtui.workbench.eval:request-evaluation
                    s "(defparameter *wb-independent-value* 21)" :define)
                  (loop repeat 200 do
                    (setf events (nconc events
                          (elmtui.workbench.eval:poll-evaluation s)))
                    when (find-if (lambda (e)
                            (and (eql :define (getf e :request-id))
                                 (eql :finished (getf e :type)))) events)
                      return nil
                    do (sleep 0.01))
                  (unless (find-if (lambda (e)
                              (and (eql :define (getf e :request-id))
                                   (eql :finished (getf e :type)))) events)
                    (error "Evaluation 1 never finished"))
                  (setf events nil)
                  (elmtui.workbench.eval:request-evaluation
                    s "(values (+ *wb-independent-value* 1) 42)" :use)
                  (loop repeat 200 do
                    (setf events (nconc events
                          (elmtui.workbench.eval:poll-evaluation s)))
                    when (find-if (lambda (e)
                            (and (eql :use (getf e :request-id))
                                 (eql :finished (getf e :type)))) events)
                      return nil
                    do (sleep 0.01))
                  (let ((got (mapcar (lambda (e) (getf e :text))
                         (remove-if-not (lambda (e)
                           (and (eql :use (getf e :request-id))
                                (eql :value (getf e :type)))) events))))
                    (unless (equal got '("22" "42"))
                      (error "Persistent image or multiple values failed: ~S" got))))
              (elmtui.workbench.eval:close-repl-session s)))
        ''')

    def test_eval_condition_does_not_poison_following_request(self):
        self.run_contract(["eval"], r'''
          (let ((s (elmtui.workbench.eval:make-repl-session))
                (events nil))
            (unwind-protect
                (progn
                  (elmtui.workbench.eval:request-evaluation s "(error \"wb-expected\")" :bad)
                  (elmtui.workbench.eval:request-evaluation s "(+ 10 7)" :good)
                  (loop repeat 220 do
                    (setf events (nconc events
                          (elmtui.workbench.eval:poll-evaluation s)))
                    when (= 2 (count :finished events
                               :key (lambda (e) (getf e :type))))
                      return nil
                    do (sleep 0.01))
                  (unless (and (find-if (lambda (e)
                                 (and (eql :bad (getf e :request-id))
                                      (eql :condition (getf e :type)))) events)
                               (find-if (lambda (e)
                                 (and (eql :good (getf e :request-id))
                                      (eql :value (getf e :type))
                                      (string= "17" (getf e :text)))) events))
                    (error "REPL worker failed to recover after condition: ~S" events)))
              (elmtui.workbench.eval:close-repl-session s)))
        ''')

    def test_inspector_handles_cycles_and_missing_handles(self):
        self.run_contract(["inspector"], r'''
          (let* ((s (elmtui.workbench.inspector:make-inspector-session
                      :max-depth 4 :max-preview 12))
                 (cycle (cons 1 nil)))
            (setf (cdr cycle) cycle)
            (let* ((handle (elmtui.workbench.inspector:register-object s cycle))
                   (result (elmtui.workbench.inspector:inspect-object s handle :cycle))
                   (missing (elmtui.workbench.inspector:inspect-object
                             s (+ handle 123) :missing)))
              (unless (and (eq :ok (getf result :status))
                           (eql :cycle (getf result :request-id))
                           (search ":CYCLE T" (prin1-to-string result)))
                (error "Cycle was not detected or request identity lost: ~S" result))
              (unless (eq :not-found (getf missing :status))
                (error "Unknown object handle did not fail safely"))))
        ''')


if __name__ == "__main__":
    unittest.main()
