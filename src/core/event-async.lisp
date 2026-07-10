;;;===============================================================
;;; File: src/core/event-async.lisp
;;; Compatibility async event helpers.
;;;===============================================================
(uiop:define-package :elmtui.core.event-async
  (:use :cl)
  (:import-from :elmtui.core.event-channels
                #:register-event-handler
                #:unregister-event-handler)
  (:import-from :elmtui.core.event-types
                #:ui-event-type
                #:ui-event-target)
  (:export #:event-promise))

(in-package :elmtui.core.event-async)

(defstruct event-promise-state
  event
  resolved-p
  rejected-p
  reason)

(defun %event-type-of (event)
  (or (ignore-errors (ui-event-type event))
      (and (consp event) (getf event :type))))

(defun %event-target-of (event)
  (or (ignore-errors (ui-event-target event))
      (and (consp event) (getf event :target))))

(defun event-promise (event-type &key target timeout channel)
  "Register a one-shot event handler on CHANNEL and return a small promise state.

This compatibility helper intentionally keeps the old API contract needed by
legacy regression tests: matching an event resolves once and unregisters the
handler from the channel. TIMEOUT is accepted for API compatibility; no timer is
started here because the current runtime no longer depends on this helper for
production async dispatch."
  (declare (ignore timeout))
  (unless channel
    (error "EVENT-PROMISE requires :CHANNEL in the compatibility implementation."))
  (let ((state (make-event-promise-state))
        (handler nil))
    (setf handler
          (lambda (event)
            (when (and (eql (%event-type-of event) event-type)
                       (or (null target)
                           (eql (%event-target-of event) target)))
              (setf (event-promise-state-event state) event
                    (event-promise-state-resolved-p state) t)
              (unregister-event-handler channel handler)
              state)))
    (register-event-handler channel handler)
    state))
