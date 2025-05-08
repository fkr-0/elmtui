;;;===============================================================
;;; File: tests/elmtui-state-tests.lisp
;;; FiveAM Unit Tests for Step 3: State Management & Elm Integration

(defpackage :elmtui-state-tests
  (:use :cl :fiveam
        :elmtui.state.model
   :elmtui.state.msg
        :elmtui.state.update))

(in-package :elmtui-state-tests)

(def-suite step3-state)
(in-suite step3-state)

;;; 1. defmodel macro: struct creation and slot defaults
;; (defmodel test-model
;;     (foo 2 )
;;     (bar :initform "baz"))

(defmodel counter (:docstring "A simple counter model"
                   :observe-changes-default-callback my-model-observer)
          (count :type integer :initform 0 :validate plusp :observe t) ; Observe count
          (label :type string :initform "Clicks")) ; Don't observe label
(test defmodel-struct-creation
  (let ((m (make-test-model)))
    (is (= (test-model-foo m) 1))
    (is (string= (test-model-bar m) "baz"))))

;;; 2. defmsg macro: constant creation and variant registration
(defmsg test-msg
    :foo nil
    :bar
    :bazz )

(test defmsg-constant-creation
  (is (boundp 'TEST-MSG))
  (is (equal TEST-MSG '(foo bar baz))))

;;; 3. defupdate macro: function creation and update contract
(defupdate test-update (model msg)
  (list (setf (test-model-foo model) 42) nil))

(test defupdate-function-creation
  (let ((m (make-test-model)))
    (let ((result (test-update m :foo)))
      (is (= (first result) 42)))))

;;; Run all tests
;;; #-asdf
;;; (run! 'step3-state) ; Now handled by elmtui-all-tests:run-all-elmtui-tests
