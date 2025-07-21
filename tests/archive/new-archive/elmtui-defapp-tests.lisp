;;; -*- Lisp -*-
;;; FiveAM sanity-checks for the DEFAPPLICATION macro
;;; Run them with  (elmtui.test.defapplication:run-defapplication-tests)

;;; ---------------------------------------------------------------------------
;;; ❶ Package setup
;;; ---------------------------------------------------------------------------
(uiop:define-package #:elmtui.test.defapplication
  (:use #:cl
        #:fiveam                       ; <https://github.com/sionescu/fiveam>
        #:elmtui.app                   ; public API that exports DEFAPPLICATION
        #:defapplication-impl)         ; helpers we may need for kw coercion
  (:import-from #:fiveam
   :def-suite :in-suite :test :is :is-error :run!))

(in-package #:elmtui.test.defapplication)

;;; ---------------------------------------------------------------------------
;;; ❷ Test-suite definition
;;; ---------------------------------------------------------------------------
(def-suite defapplication-suite
  :description "Smoke-tests for basic DEFAPPLICATION expansions")

(in-suite defapplication-suite)

;;; ---------------------------------------------------------------------------
;;; ❸ Utility – a trivial root DSL used in several tests
;;; ---------------------------------------------------------------------------
(defparameter *dummy-root-dsl*
  '(elmtui.ui.widgets.label:label :id :root-label :text "Hello"))

;;; ---------------------------------------------------------------------------
;;; ❹ EXPANSION should create the three canonical functions
;;; ---------------------------------------------------------------------------
(test sample-app-expansion
  ;; Evaluate a minimal valid app definition
  (eval '(defapplication sample-app
          :root-component-dsl *dummy-root-dsl*
          :root-viewport-id   :sample-root-vp))
  ;; Check the expected artefacts are now fbound
  (is (fboundp 'initialize-app-state-sample-app))
  (is (fboundp 'process-message-sample-app))
  (is (fboundp 'run-sample-app)))

;;; ---------------------------------------------------------------------------
;;; ❺ Missing required keyword – should signal ERROR at macro-expansion time
;;; ---------------------------------------------------------------------------
(test missing-root-viewport-id
  (is-error
   (macroexpand '(defapplication bad-app
                  :root-component-dsl *dummy-root-dsl*))))

(test missing-root-component-dsl
  (is-error
   (macroexpand '(defapplication bad-app-2
                  :root-viewport-id :vp))))

;;; ---------------------------------------------------------------------------
;;; ❻ Unknown keywords are tolerated (warning only) – expansion still works
;;; ---------------------------------------------------------------------------
(test unknown-keyword-warning
  (eval '(defapplication warn-app
          :root-component-dsl *dummy-root-dsl*
          :root-viewport-id   :warn-vp
          :some-strange-key   42))
  (is (fboundp 'run-warn-app)))

;;; ---------------------------------------------------------------------------
;;; ❼ Convenience runner – call this from your REPL
;;; ---------------------------------------------------------------------------
(defun run-defapplication-tests ()
  "Execute DEFAPPLICATION smoke tests and return the FiveAM report."
  (run! 'defapplication-suite))
== end/defapplication-tests.lisp ==
