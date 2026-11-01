;;;; keys.lisp: secondary package for low-level key-event struct accessors.
;;;;
;;;; Prefer ELMTUI:KEY-EVENT-PARTS for most use cases.  These accessors
;;;; are re-exported from the ELMTUI facade for backward compatibility
;;;; but will move exclusively to this package in 0.7.0.

(uiop:define-package :elmtui.keys
  (:use :cl)
  (:documentation "Low-level key-event struct accessors.
Prefer ELMTUI:KEY-EVENT-PARTS for most use cases.
These accessors are re-exported from the ELMTUI facade for backward
compatibility but will move exclusively to this package in 0.7.0.")
  (:import-from :elmtui.core.event-types
                #:key-event #:key-event-p #:key-event-key
                #:key-event-char #:key-event-modifiers
                #:make-key-event)
  (:export
   #:key-event #:key-event-p #:key-event-key
   #:key-event-char #:key-event-modifiers
   #:make-key-event))
