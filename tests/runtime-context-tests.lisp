(uiop:define-package :elmtui.tests.runtime-context
  (:use :cl :fiveam)
  (:import-from :elmtui.runtime.context
                #:make-runtime-context
                #:runtime-context-active-p
                #:runtime-context-generation
                #:runtime-context-phase
                #:runtime-context-shutdown-requested-p
                #:runtime-context-valid-generation-p
                #:invalidate-runtime-context))

(in-package :elmtui.tests.runtime-context)

(def-suite runtime-context-tests
  :in elmtui.tests:elmtui-test
  :description "Runtime ownership and generation isolation tests.")

(in-suite runtime-context-tests)

(test runtime-context-generation-is-instance-scoped
  (let* ((first (make-runtime-context))
         (second (make-runtime-context))
         (first-generation (runtime-context-generation first)))
    (is-true (runtime-context-valid-generation-p first first-generation))
    (is-false (runtime-context-valid-generation-p second first-generation))))

(test invalidated-runtime-context-rejects-late-generation
  (let* ((context (make-runtime-context))
         (generation (runtime-context-generation context)))
    (invalidate-runtime-context context)
    (is-false (runtime-context-active-p context))
    (is-true (runtime-context-shutdown-requested-p context))
    (is (eq :stopped (runtime-context-phase context)))
    (is-false (runtime-context-valid-generation-p context generation))))
