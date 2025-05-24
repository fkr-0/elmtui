;;;===============================================================
;;; File: src/core/event-compat.lisp
;;; Event Compatibility Layer
;;;
;;; This file provides compatibility functions to translate between
;;; different event structure formats in the system. It's meant to
;;; be a transitional solution to standardize on a single event format.
;;;===============================================================

(uiop:define-package :elmtui.core.event-compat
  (:use :cl)
  (:import-from :elmtui.core.event-types
                #:key-event #:mouse-event #:focus-event
                #:make-key-event #:make-mouse-event #:make-focus-event)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn)
  (:export #:normalize-event
           #:convert-list-to-event
           #:convert-event-to-list))

(in-package :elmtui.core.event-compat)

;;;-----------------------------------------------------------------------------
;;; Event Normalization Functions
;;;-----------------------------------------------------------------------------

(defun normalize-event (event)
  "Normalizes an event to the canonical elmtui.core.events format.
   Accepts events from various sources and formats and standardizes them."
  (cond
    ;; Already a canonical event struct from elmtui.core.event-types
    ((or (elmtui.core.event-types:key-event-p event)
         (elmtui.core.event-types:mouse-event-p event)
         (elmtui.core.event-types:focus-event-p event)
         ;; Add other canonical event types here if needed
         )
     event)

    ;; List-based events (e.g., '(:key-event :key #\a ...))
    ((and (listp event) (keywordp (first event)))
     (convert-list-to-event event))

    ;; Plist format for key events (legacy/simplified format)
    ((and (listp event) ; Plist is a list
          (getf event :type)
          (member (getf event :type) '(:key-down :key-up :key-press)))
     (elmtui.core.event-types:make-key-event
      :type (getf event :type)
      :key (getf event :key)
      :code (getf event :code) ; Include code if available
      :modifiers (getf event :modifiers)
      :timestamp (or (getf event :timestamp) (get-internal-real-time))
      :consumed-p (getf event :consumed-p))) ; Include consumed-p

    ;; Add other legacy format conversions here if necessary

    ;; If all else fails, return unchanged or signal an error/warning
    (t
     (log-warn "Unrecognized event format for normalization: ~S" event)
     event)))

;;;-----------------------------------------------------------------------------
;;; List Format Conversion
;;;-----------------------------------------------------------------------------
;;; These functions convert between the canonical event structs and a
;;; legacy list-based representation.

(defun convert-list-to-event (list-event)
  "Converts a list-format event to the appropriate struct format."
  (let ((event-type (first list-event)))
    (case event-type
      (:key-event
       (let* ((key (getf (rest list-event) :key))
              (modifiers (getf (rest list-event) :modifiers '())))
         (elmtui.core.event-types:make-key-event
          :type :key-down ; Default for list format
          :key key
          :modifiers modifiers)))

      (:mouse-event
       (let* ((button (getf (rest list-event) :button))
              (x (getf (rest list-event) :x 0))
              (y (getf (rest list-event) :y 0))
              (modifiers (getf (rest list-event) :modifiers '())))
         (elmtui.core.event-types:make-mouse-event
          :type :mouse-down ; Default for list format
          :x x
          :y y
          :button button
          :modifiers modifiers)))

      (:focus-event
       (let* ((focus-type (getf (rest list-event) :type :focus-in))
              (target (getf (rest list-event) :target)))
         (elmtui.core.event-types:make-focus-event
          :type focus-type
          :target target)))

      (otherwise
       (log-warn "Unknown list event type: ~S" event-type)
       nil))))

(defun convert-event-to-list (event)
  "Converts a struct event back to list format for backward compatibility."
  (cond
    ((typep event 'elmtui.core.event-types:key-event)
     `(:key-event :key ,(elmtui.core.event-types:key-event-key event)
                  :modifiers ,(elmtui.core.event-types:key-event-modifiers event)))

    ((typep event 'elmtui.core.event-types:mouse-event)
     `(:mouse-event :button ,(elmtui.core.event-types:mouse-event-button event)
                    :x ,(elmtui.core.event-types:mouse-event-x event)
                    :y ,(elmtui.core.event-types:mouse-event-y event)
                    :modifiers ,(elmtui.core.event-types:mouse-event-modifiers event)))

    ((typep event 'elmtui.core.event-types:focus-event)
     `(:focus-event :type ,(elmtui.core.event-types:focus-event-type event)
                    :target ,(elmtui.core.event-types:focus-event-target event)))

    (t event))) ; Return as is if not recognized
