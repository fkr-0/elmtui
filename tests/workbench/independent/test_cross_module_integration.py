"""Cross-package integration contracts in fresh CLPM/SBCL images.

Editor -> evaluator; evaluator -> completion; completion -> object inspector;
evaluator condition -> diagnostics. This runs without the future W5 TUI.
"""
from __future__ import annotations

import unittest

from contract_driver import MARKER, required_tools, run_lisp


class IndependentIntegrationContracts(unittest.TestCase):
    SOURCES = ("editor", "eval", "completion", "docs", "inspector")

    def run_contract(self, source):
        missing = required_tools()
        if missing:
            self.skipTest(f"missing required executable: {missing}")
        try:
            result = run_lisp(self.SOURCES, source, timeout=20)
        except FileNotFoundError as exc:
            self.skipTest(f"module not yet created: {exc}")
        output = result.stdout + "\n" + result.stderr
        self.assertEqual(result.returncode, 0, output[-6500:])
        self.assertIn(MARKER, result.stdout, output[-6500:])

    def test_editor_submission_roundtrips_to_async_eval(self):
        self.run_contract(r'''
          (let ((editor (elmtui.workbench.editor:make-editor-state :text "(+ 9 4)"))
                (s (elmtui.workbench.eval:make-repl-session))
                (events nil))
            (unwind-protect
                (progn
                  (unless (elmtui.workbench.editor:editor-balanced-p editor)
                    (error "Editor failed to recognize executable form"))
                  (elmtui.workbench.editor:editor-handle-key editor :enter)
                  (unless (eq :submit
                         (elmtui.workbench.editor:editor-state-last-action editor))
                    (error "Editor did not request submit"))
                  (elmtui.workbench.eval:request-evaluation
                    s (elmtui.workbench.editor:editor-text editor) :editor-eval)
                  (loop repeat 160 do
                    (setf events (nconc events
                            (elmtui.workbench.eval:poll-evaluation s)))
                    when (find-if (lambda (event)
                           (eql :finished (getf event :type))) events)
                      return nil
                    do (sleep 0.01))
                  (unless (find-if (lambda (event)
                              (and (eq :value (getf event :type))
                                   (equal :editor-eval (getf event :request-id))
                                   (string= "13" (getf event :text)))) events)
                    (error "Editor source not evaluated to 13: ~S" events)))
              (elmtui.workbench.eval:close-repl-session s)))
        ''')

    def test_evaluated_new_symbol_is_available_to_completion(self):
        self.run_contract(r'''
          (let ((s (elmtui.workbench.eval:make-repl-session)) (events nil))
            (unwind-protect
                (progn
                  (elmtui.workbench.eval:request-evaluation
                    s "(defparameter *wb-independent-cross-symbol* 734)" :new)
                  (loop repeat 160 do
                    (setf events (nconc events
                            (elmtui.workbench.eval:poll-evaluation s)))
                    when (find-if (lambda (event)
                           (eq :finished (getf event :type))) events)
                      return nil
                    do (sleep 0.01))
                  (unless (find-if (lambda (e)
                              (eq :finished (getf e :type))) events)
                    (error "Definition never finished"))
                  (let* ((prefix "*wb-independent-cross")
                         (response (elmtui.workbench.completion:complete-at
                                    s prefix (length prefix) :after-eval))
                         (choices
                           (elmtui.workbench.completion:completion-result-candidates
                            response)))
                    (unless (find "*WB-INDEPENDENT-CROSS-SYMBOL*" choices
                                :test #'string=
                                :key #'elmtui.workbench.completion:completion-candidate-display)
                      (error "New definition not visible to completion"))))
              (elmtui.workbench.eval:close-repl-session s)))
        ''')

    def test_completion_candidate_can_be_inspected_without_eval(self):
        self.run_contract(r'''
          (let* ((response (elmtui.workbench.completion:complete-at
                             (find-package "CL-USER") "(cl:mapc" 8 :pick))
                 (candidate (find "MAPCAR"
                                   (elmtui.workbench.completion:completion-result-candidates
                                    response)
                                   :key
                                   #'elmtui.workbench.completion:completion-candidate-display
                                   :test #'string=))
                 (inspector (elmtui.workbench.inspector:make-inspector-session)))
            (unless candidate (error "Cannot select MAPCAR candidate"))
            (let* ((handle (elmtui.workbench.inspector:register-object
                             inspector
                             (elmtui.workbench.completion:completion-candidate-symbol
                              candidate)))
                   (item (elmtui.workbench.inspector:inspect-object
                           inspector handle :candidate)))
              (unless (and (eq :ok (getf item :status))
                           (eql :candidate (getf item :request-id))
                           (search "MAPCAR" (prin1-to-string item)))
                (error "Candidate inspector missing symbol: ~S" item))))
        ''')

    def test_eval_condition_becomes_bounded_inspector_diagnostic(self):
        self.run_contract(r'''
          (let ((s (elmtui.workbench.eval:make-repl-session))
                (inspector (elmtui.workbench.inspector:make-inspector-session
                             :max-preview 24))
                (events nil))
            (unwind-protect
                (progn
                  (elmtui.workbench.eval:request-evaluation
                    s "(error \"expected diagnostic\")" :diag)
                  (loop repeat 160 do
                    (setf events (nconc events
                            (elmtui.workbench.eval:poll-evaluation s)))
                    when (find-if (lambda (event)
                           (eq :finished (getf event :type))) events)
                      return nil
                    do (sleep 0.01))
                  (let ((condition (find :condition events
                                         :key (lambda (event)
                                                (getf event :type)))))
                    (unless condition
                      (error "Evaluator failed to emit condition"))
                    (let ((diagnostic
                            (elmtui.workbench.inspector:record-diagnostic
                              inspector :error (getf condition :text)
                              :request-id (getf condition :request-id))))
                      (unless (and (eq :diagnostic (getf diagnostic :kind))
                                   (eq :diag (getf diagnostic :request-id))
                                   (<= (length (getf diagnostic :summary)) 24))
                        (error "Diagnostic not bounded or correlated: ~S"
                               diagnostic)))))
              (elmtui.workbench.eval:close-repl-session s)))
        ''')


if __name__ == "__main__":
    unittest.main()
