;;; File: tests/state-semantics-tests.lisp
;;; Executable refinement checks for transactional and strict Elm state modes.

(uiop:define-package :elmtui.tests.state-semantics
  (:use :cl :fiveam)
  (:import-from :elmtui.state.update
                #:sapply
                #:send-command)
  (:import-from :elmtui.state.api
                #:make-update-result
                #:state-ref
                #:state-set)
  (:import-from :cl-state.core
                #:state-mutation-forbidden)
  (:import-from :elmtui.app.api
                #:app-config-state-semantics)
  (:export #:state-semantics-tests))

(in-package :elmtui.tests.state-semantics)

(def-suite state-semantics-tests
  :in elmtui.tests:elmtui-test
  :description "Observational equivalence and strict replacement semantics for application state.")

(in-suite state-semantics-tests)

(defvar *attempt-view-mutation* nil)
(defvar *attempt-subscription-mutation* nil)
(defvar *aliased-state-for-update* nil)

(defun semantics-test-view (state)
  (when *attempt-view-mutation*
    (state-set state :view-mutated t))
  '(:root-viewport :id :semantics-root :children ()))

(defun semantics-test-subscriptions (model)
  (when *attempt-subscription-mutation*
    (state-set model :subscription-mutated t))
  nil)

(defun semantics-test-update (message ctx)
  (case message
    (:increment
     (sapply ctx :count #'1+ 0)
     (send-command ctx '(:dispatch (:count-changed)))
     (make-update-result :handled t))
    (:decrement
     (sapply ctx :count #'1- 0)
     (send-command ctx '(:dispatch (:count-changed)))
     (make-update-result :handled t))
    (:illegal-direct-mutation
     (when *aliased-state-for-update*
       (state-set *aliased-state-for-update* :count 999))
     (make-update-result :handled t))
    (otherwise
     (make-update-result :handled t))))

(elmtui.app:defapplication semantics-fast-app
  :initial-state-plist '(:count 0 :nested (:value 7))
  :root-component-dsl '(:root-viewport :id :semantics-fast-root :children ())
  :root-viewport-id :semantics-fast-root
  :update-fn semantics-test-update
  :view-fn semantics-test-view
  :subscriptions-fn semantics-test-subscriptions
  :state-semantics :transactional)

(elmtui.app:defapplication semantics-strict-app
  :initial-state-plist '(:count 0 :nested (:value 7))
  :root-component-dsl '(:root-viewport :id :semantics-strict-root :children ())
  :root-viewport-id :semantics-strict-root
  :update-fn semantics-test-update
  :view-fn semantics-test-view
  :subscriptions-fn semantics-test-subscriptions
  :state-semantics :strict-elm)

(test application-config-records-state-semantics
  (let ((fast (gethash 'semantics-fast-app elmtui.core.globals:*applications*))
        (strict (gethash 'semantics-strict-app elmtui.core.globals:*applications*)))
    (is (eq :transactional (app-config-state-semantics fast)))
    (is (eq :strict-elm (app-config-state-semantics strict)))))

(test strict-elm-processor-replaces-model-and-preserves-prior-snapshot
  (multiple-value-bind (state-0 _commands)
      (initialize-app-state-semantics-strict-app)
    (declare (ignore _commands))
    (let ((nested-0 (state-ref state-0 :nested)))
      (multiple-value-bind (state-1 commands)
          (process-message-semantics-strict-app :increment state-0)
        (is-false (eq state-0 state-1))
        (is (= 0 (state-ref state-0 :count)))
        (is (= 1 (state-ref state-1 :count)))
        (is (= 7 (state-ref state-0 '(:nested :value))))
        (is (= 7 (state-ref state-1 '(:nested :value))))
        (is (eq nested-0 (state-ref state-1 :nested)))
        (is (equal '((:dispatch (:count-changed))) commands))))))

(test transactional-processor-retains-fast-state-identity
  (multiple-value-bind (state-0 _commands)
      (initialize-app-state-semantics-fast-app)
    (declare (ignore _commands))
    (multiple-value-bind (state-1 commands)
        (process-message-semantics-fast-app :increment state-0)
      (is (eq state-0 state-1))
      (is (= 1 (state-ref state-0 :count)))
      (is (equal '((:dispatch (:count-changed))) commands)))))

(test strict-and-transactional-modes-have-same-visible-transition-trace
  "For framework-visible state and commands, both commit engines refine the same TEA transition."
  (multiple-value-bind (fast-state _fast-init-commands)
      (initialize-app-state-semantics-fast-app)
    (declare (ignore _fast-init-commands))
    (multiple-value-bind (strict-state _strict-init-commands)
        (initialize-app-state-semantics-strict-app)
      (declare (ignore _strict-init-commands))
      (dolist (message '(:increment :increment :decrement :unknown :increment))
        (multiple-value-bind (next-fast fast-commands)
            (process-message-semantics-fast-app message fast-state)
          (multiple-value-bind (next-strict strict-commands)
              (process-message-semantics-strict-app message strict-state)
            (is (= (state-ref next-fast :count)
                   (state-ref next-strict :count)))
            (is (equal fast-commands strict-commands))
            (setf fast-state next-fast
                  strict-state next-strict)))))))

(test strict-elm-rejects-direct-state-mutation-from-update
  (multiple-value-bind (state _commands)
      (initialize-app-state-semantics-strict-app)
    (declare (ignore _commands))
    (let ((*aliased-state-for-update* state))
      (signals state-mutation-forbidden
        (process-message-semantics-strict-app :illegal-direct-mutation state)))
    (is (= 0 (state-ref state :count)))))

(test strict-elm-rejects-state-mutation-from-view
  (multiple-value-bind (state _commands)
      (initialize-app-state-semantics-strict-app)
    (declare (ignore _commands))
    (let ((*attempt-view-mutation* t))
      (signals state-mutation-forbidden
        (wrapped-view-semantics-strict-app state)))
    (is-false (state-ref state :view-mutated nil))))

(test transactional-mode-retains-explicit-escape-hatch-for-direct-api-mutation
  (multiple-value-bind (state _commands)
      (initialize-app-state-semantics-fast-app)
    (declare (ignore _commands))
    (let ((*aliased-state-for-update* state))
      (process-message-semantics-fast-app :illegal-direct-mutation state))
    (is (= 999 (state-ref state :count)))))

(test strict-driver-subscription-phase-rejects-model-mutation
  (multiple-value-bind (state _commands)
      (initialize-app-state-semantics-strict-app)
    (declare (ignore _commands))
    (let ((*attempt-subscription-mutation* t))
      (signals state-mutation-forbidden
        (elmtui.platform.driver::%refresh-app-subscriptions
         (list :subscriptions-fn #'semantics-test-subscriptions
               :state-semantics :strict-elm)
         state)))
    (is-false (state-ref state :subscription-mutated nil))))

(test strict-command-processor-policy-rejects-model-mutation
  (multiple-value-bind (state _commands)
      (initialize-app-state-semantics-strict-app)
    (declare (ignore _commands))
    (signals state-mutation-forbidden
      (elmtui.runtime.effects:run-commands-with-policy
       '((:effect))
       :command-processor-fn
       (lambda (_cmd _queue model _cfg)
         (declare (ignore _cmd _queue _cfg))
         (state-set model :effect-mutated t))
       :model state
       :state-mutation-policy :forbid))
    (is-false (state-ref state :effect-mutated nil))))

(test defapplication-rejects-unknown-state-semantics
  (signals error
    (macroexpand-1
     '(elmtui.app:defapplication invalid-state-semantics-app
        :root-component-dsl '(:root-viewport :id :invalid-root :children ())
        :root-viewport-id :invalid-root
        :update-fn semantics-test-update
        :view-fn semantics-test-view
        :subscriptions-fn semantics-test-subscriptions
        :state-semantics :mystery))))
