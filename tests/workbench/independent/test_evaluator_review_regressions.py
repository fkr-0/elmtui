"""Independent W2 review regressions: required RED until sequential READ/EVAL works.

Run: python3 -m unittest discover -s tests/workbench/independent \
     -p test_evaluator_review_regressions.py -v

These are real SBCL/CLPM tests of standard sequential REPL semantics. They
intentionally fail against the reviewed implementation, so do not skip/xfail.
"""
import unittest
from contract_driver import MARKER, required_tools, run_lisp


class EvaluatorSequentialReaderContracts(unittest.TestCase):
    def check(self, source):
        if (missing := required_tools()):
            self.skipTest(f"missing executable: {missing}")
        try:
            result = run_lisp(("eval",), source, timeout=14)
        except FileNotFoundError as e:
            self.skipTest(f"missing evaluated package: {e}")
        report = result.stdout + "\n" + result.stderr
        self.assertEqual(result.returncode, 0, report[-5000:])
        self.assertIn(MARKER, result.stdout, report[-5000:])

    def test_same_submission_in_package_affects_subsequent_read(self):
        self.check(r'''
          (let ((session (elmtui.workbench.eval:make-repl-session)) (events nil))
            (unwind-protect
              (progn
                (elmtui.workbench.eval:request-evaluation session
                   "(defpackage :wb-review-batch-correct (:use :cl)) (in-package :wb-review-batch-correct) (defparameter *wb-read-package-variable* 123)"
                   :batch)
                (loop repeat 150 do
                  (setf events (nconc events (elmtui.workbench.eval:poll-evaluation session)))
                  when (find :finished events :key (lambda (e) (getf e :type)))
                    return nil
                  do (sleep .01))
                (unless (find :finished events :key (lambda (e) (getf e :type)))
                  (error "Batch never completed"))
                (let ((target (find-package :wb-review-batch-correct)))
                  (unless (and
                            (eq target (elmtui.workbench.eval:repl-session-package session))
                            (multiple-value-bind (symbol status)
                                (find-symbol "*WB-READ-PACKAGE-VARIABLE*" target)
                              (and status (boundp symbol) (= 123 (symbol-value symbol)))))
                    (error "Read occurred before IN-PACKAGE; later symbol interned in wrong package"))))
              (elmtui.workbench.eval:close-repl-session session)))
        ''')

    def test_same_submission_reader_macro_affects_following_form(self):
        self.check(r'''
          (let ((session (elmtui.workbench.eval:make-repl-session)) (events nil))
            (unwind-protect
              (progn
                (elmtui.workbench.eval:request-evaluation session
                  "(set-macro-character #\\! (lambda (stream char) (declare (ignore stream char)) 99)) !"
                  :batch)
                (loop repeat 150 do
                  (setf events (nconc events (elmtui.workbench.eval:poll-evaluation session)))
                  when (find :finished events :key (lambda (e) (getf e :type)))
                    return nil
                  do (sleep .01))
                (unless (find-if (lambda (e)
                          (and (eq :batch (getf e :request-id))
                               (eq :value (getf e :type))
                               (equal "99" (getf e :text)))) events)
                  (error "Reader macro installed by first form was not applied to next form; events: ~S" events)))
              (elmtui.workbench.eval:close-repl-session session)))
        ''')


if __name__ == "__main__":
    unittest.main()
