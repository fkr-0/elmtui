(uiop:define-package :elmtui.runtime.context
  (:use :cl)
  (:export #:runtime-context
           #:make-runtime-context
           #:runtime-context-app-spec
           #:runtime-context-backend
           #:runtime-context-model
           #:runtime-context-message-processor
           #:runtime-context-app-sender
           #:runtime-context-focus-manager
           #:runtime-context-subscriptions
           #:runtime-context-previous-frame-buffer
           #:runtime-context-last-context
           #:runtime-context-root-viewport-id-path
           #:runtime-context-input-context
           #:runtime-context-phase
           #:runtime-context-shutdown-requested-p
           #:runtime-context-active-p
           #:runtime-context-generation
           #:runtime-context-valid-generation-p
           #:invalidate-runtime-context))

(in-package :elmtui.runtime.context)

(defstruct (runtime-context
             (:constructor make-runtime-context
                 (&key app-spec backend model message-processor app-sender
                       focus-manager subscriptions previous-frame-buffer
                       last-context root-viewport-id-path input-context
                       (phase :booting) (shutdown-requested-p nil)
                       (active-p t) (generation (gensym "RUNTIME-")))))
  "Per-application runtime ownership boundary. Compatibility globals may mirror these slots, but new runtime work should be scoped to this object."
  app-spec
  backend
  model
  message-processor
  app-sender
  focus-manager
  (subscriptions (make-hash-table :test 'equal))
  previous-frame-buffer
  last-context
  root-viewport-id-path
  input-context
  (phase :booting)
  (shutdown-requested-p nil :type boolean)
  (active-p t :type boolean)
  generation)

(defun runtime-context-valid-generation-p (context generation)
  "Return true when GENERATION still identifies the active CONTEXT instance."
  (and context
       (runtime-context-active-p context)
       (eql generation (runtime-context-generation context))))

(defun invalidate-runtime-context (context)
  "Invalidate CONTEXT so late async work can detect that its owning runtime has ended."
  (when context
    (setf (runtime-context-active-p context) nil
          (runtime-context-shutdown-requested-p context) t
          (runtime-context-phase context) :stopped))
  context)
