;;;===============================================================
;;; File: tests/v2/test-modelstate.lisp
;;; FiveAM Unit Tests for elmtui.state.model, state, and msg
;;;===============================================================

(uiop:define-package :elmtui-test-modelstate
  (:use :cl :fiveam)
  (:import-from :elmtui.state.model
                #:defmodel #:make-model #:model-slot-value #:initialize-model-state
                #:get-slot #:model-slot-names #:model-slot-type #:model-slot-initform
                #:model-slot-validator #:model-slot-observe? #:model-schema-info)
  (:import-from :elmtui.state
                #:make-application-state #:state-ref #:set-state #:with-transaction)
  (:import-from :elmtui.state.msg
                #:defmsg #:message-variant-p #:*message-schemas*)
  (:export :run-elmtui-test-modelstate))

(in-package :elmtui-test-modelstate)

(def-suite elmtui-test-modelstate-suite
  :description "Unit tests for elmtui.state.model, state, and msg")
(in-suite elmtui-test-modelstate-suite)

;;; --- Model Definition and Access ---

(defmodel test-counter-model
    (:docstring "A test counter model")
    (counter-val :type integer :initform 0 :validate #'integerp :observe t)
    (label :type string :initform "Counter"))

(test defmodel-and-accessors
  (let ((app-state (make-application-state)))
    (let ((counter (make-test-counter-model :counter-val 5 :label "Test")))
      (is (equal (get-slot counter 'test-counter-model 'counter-val) 5))
      (is (equal (get-slot counter 'test-counter-model 'label) "Test"))
      (is (equal (model-slot-names 'test-counter-model) '(counter-val label)))
      (is (eq (model-slot-type 'test-counter-model 'counter-val) 'integer))
      (is (string= (model-slot-initform 'test-counter-model 'label) "Counter"))
      (is (functionp (model-slot-validator 'test-counter-model 'counter-val)))
      (is (not (model-slot-observe? 'test-counter-model 'label)))
      (is (model-slot-observe? 'test-counter-model 'counter-val))
      (is (search "test-counter-model"
                  (model-schema-info
                   'test-counter-model) :test #'string=)))
    ;; State initialization and accessors
    (let ((counter (make-test-counter-model :counter-val 7 :label "State")))
      (initialize-model-state app-state 'test-counter-model counter)
      (is (= (test-counter-model-counter-val app-state) 7))
      (is (string= (test-counter-model-label app-state) "State"))
      (is (= (model-slot-value app-state 'test-counter-model 'counter-val) 7)))))

;;; --- State API ---

(test application-state-basic
  (let ((app-state (make-application-state)))
    (set-state app-state :foo 42)
    (is (= (state-ref app-state :foo) 42))
    (with-transaction (app-state)
      (set-state app-state :foo 99))
    (is (= (state-ref app-state :foo) 99))))

;;; --- Message Macro and Validation ---

(defmsg TestMsg (:docstring "Test message type")
        Foo
        (Bar :val integer)
        (Baz :str string :num integer))

(test defmsg-constructors-and-variant-p
  (let ((foo (make-foo-test-msg))
        (bar (make-bar-test-msg :val 42))
        (baz (make-baz-test-msg :str "abc" :num 7)))
    (is (equal foo '(:foo)))
    (is (equal bar '(:bar :val 42)))
    (is (equal baz '(:baz :str "abc" :num 7)))
    (is (message-variant-p 'TestMsg foo))
    (is (message-variant-p 'TestMsg bar))
    (is (message-variant-p 'TestMsg baz))
    (is (not (message-variant-p 'TestMsg '(:quux))))
    (is (not (message-variant-p 'TestMsg '(:bar :val "not-an-int"))))))

(defun run-elmtui-test-modelstate ()
  (fiveam:run! 'elmtui-test-modelstate-suite))
