(uiop:define-package :elmtui.tests.runtime-effects
  (:use :cl :fiveam)
  (:import-from :elmtui.runtime.effects
                #:normalize-subscriptions
                #:reconcile-model-subscriptions
                #:clear-subscription-registry)
  (:import-from :elmtui.contracts
                #:make-subscription))

(in-package :elmtui.tests.runtime-effects)

(def-suite runtime-effects-tests
  :in elmtui.tests:elmtui-test
  :description "Runtime effect manager subscription reconciliation tests")

(in-suite runtime-effects-tests)

(test normalize-subscriptions-rejects-invalid-payload
  (is (null (normalize-subscriptions "invalid"))))

(test reconcile-subscriptions-installs-idempotently-and-cancels
  (let ((table (make-hash-table :test 'equal))
        (installed 0)
        (cancelled 0)
        (last-cmd nil)
        (sub '(:timer (:interval 0.02 :message (:tick)))))
    (flet ((subs-on (_model)
             (declare (ignore _model))
             (list sub))
           (subs-off (_model)
             (declare (ignore _model))
             nil)
           (interpreter (cmd)
             (incf installed)
             (setf last-cmd cmd)
             t)
           (canceller (cmd)
             (when (equal cmd last-cmd)
               (incf cancelled))
             t))
      (reconcile-model-subscriptions #'subs-on nil table
                                     :command-interpreter #'interpreter
                                     :command-canceller #'canceller)
      (is (= 1 installed))
      (is (= 1 (hash-table-count table)))

      ;; same desired subscriptions should not reinstall
      (reconcile-model-subscriptions #'subs-on nil table
                                     :command-interpreter #'interpreter
                                     :command-canceller #'canceller)
      (is (= 1 installed))
      (is (= 1 (hash-table-count table)))

      ;; removing desired subscriptions cancels active one
      (reconcile-model-subscriptions #'subs-off nil table
                                     :command-interpreter #'interpreter
                                     :command-canceller #'canceller)
      (is (= 1 cancelled))
      (is (= 0 (hash-table-count table)))

      ;; clear helper is safe when empty
      (is-true (clear-subscription-registry table :command-canceller #'canceller)))))

(test reconcile-subscriptions-supports-contract-subscription-struct
  (let ((table (make-hash-table :test 'equal))
        (installed 0)
        (sub (make-subscription
              :type :timer
              :config '(:interval 0.05 :message (:heartbeat)))))
    (flet ((subs-on (_model)
             (declare (ignore _model))
             (list sub))
           (interpreter (_cmd)
             (declare (ignore _cmd))
             (incf installed)
             t))
      (reconcile-model-subscriptions #'subs-on nil table
                                     :command-interpreter #'interpreter)
      (is (= 1 installed))
      (is (= 1 (hash-table-count table))))))

(test reconcile-subscriptions-propagates-unexpected-subscription-errors
  (let ((table (make-hash-table :test 'equal)))
    (signals error
      (reconcile-model-subscriptions
       (lambda (_model)
         (declare (ignore _model))
         (error "subscription boom"))
       nil table))
    (is (= 0 (hash-table-count table)))))
