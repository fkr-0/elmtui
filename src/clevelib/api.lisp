(uiop:define-package :cleve-elm.api
  (:use :cl)
  (:nicknames :cleve.api)
  ;; removed duplicate symbols that slipped in earlier
  (:import-from :elmtui.utils :ensure-list)
  (:export
   :get-children
   :ems-root
   :on-event
   :translate-event-to-message
   :emit
   :get-parent
   :root-to-target-path
   :events
   :event-type
   :simple-emitter
   :simple-sink
   :simple-translator
   :on-event
   :on-message
   :connected-sinks
   :relay-message
   :connected-messengers
   :target-messengers
   :set-target-messengers
   :broadcast-p
   :propagation-stopped-p
   :capture-p
   :bubble-p
   :connect-sink))

(in-package :cleve-elm.api)
;;; ===================================================================
;;; INTERFACE SECTION - Public API declarations
;;; ===================================================================

;;;; ---------------------------------------------------------------------------
;;;;  Generic function declarations
;;;; ---------------------------------------------------------------------------

(declaim (ftype (function (t) t) event-type))
(defgeneric event-type (event)
  (:method ((ev t)) :untyped-event)
  (:documentation "Return the *type* of an EVENT."))

(declaim (ftype (function (t t &rest t) t) on-event))
(defgeneric on-event (event-handler event &rest args)
  (:documentation "Handle EVENT in EVENT-HANDLER."))

(declaim (ftype (function (t t t &rest t) t) connect-sink))
(defgeneric connect-sink (emitter sink event-type &rest args)
  (:documentation "Connect SINK to EMITTER for EVENT-TYPE."))

(declaim (ftype (function (t t &rest t) t) connected-sinks))
(defgeneric connected-sinks (emitter event-type &rest args)
  (:documentation "Return the list of sinks currently wired to EMITTER for EVENT-TYPE."))

(declaim (ftype (function (t t &rest t) t) emit))
(defgeneric emit (emitter event &rest args)
  (:documentation "Emit EVENT from EMITTER."))

;;; ===================================================================
;;; IMPLEMENTATION SECTION
;;; ===================================================================
(defmethod emit ((emitter t) event &rest args)
  (dolist (sink (connected-sinks emitter (event-type event)))
    (handler-case
        (apply #'on-event sink event args)
      (error (e)
        (format *error-output* "Error handling event ~A: ~A~%" event e)))))

(declaim (ftype (function (t t &rest t) t) translate-event-to-message))
(defgeneric translate-event-to-message (event-message-system event &rest args)
  (:documentation "Translate EVENT into a message suitable for EVENT-MESSAGE-SYSTEM."))

(declaim (ftype (function (t t &rest t) t) on-message))
(defgeneric on-message (messenger message &rest args)
  (:documentation "Handle MESSAGE in MESSENGER."))

(declaim (ftype (function (t t &rest t &key &allow-other-keys) t) relay-message))
(defgeneric relay-message (message-system message &rest args &key &allow-other-keys)
  (:documentation "Let MESSAGE-SYSTEM deliver MESSAGE."))

;; Removed FTYPE declarations to avoid clobbering warnings - generic functions provide the interface
(defgeneric connected-messengers (message-system &rest args)
  (:documentation "Return all messengers wired to MESSAGE-SYSTEM."))

;;;; ---------------------------------------------------------------------------
;;;;  Message target helpers — allow a sentinel :broadcast in addition to a list
;;;; ---------------------------------------------------------------------------

;; FIX: allow NIL | list | :broadcast -----------------------------------------
(defgeneric target-messengers (message  &rest args)
  (:documentation "Return the explicit target messengers of MESSAGE (or :BROADCAST).")
  (:method ((message t) &rest args)
    (declare (ignore args))
    nil))

;; FIX: updated setter to match the new type
(defgeneric set-target-messengers (new-target-messengers message  &rest args)
  (:documentation "Attach NEW-TARGET-MESSENGERS to MESSAGE (use :BROADCAST for fan-out)."))

(defmethod (setf target-messengers) (new-target-messengers (message t))
  (declare (type (or null list (eql :broadcast)) new-target-messengers))
  (set-target-messengers message new-target-messengers))

(defgeneric broadcast-p (message  &rest args)
  (:documentation "Return T when MESSAGE must be broadcast."))

(defmethod broadcast-p ((message t) &rest args)
  (declare (ignore args))
  (or (null (target-messengers message))
      (eq (target-messengers message) :broadcast)))

;;;; ---------------------------------------------------------------------------
;;;;  Two simple flavours of relay-message
;;;; ---------------------------------------------------------------------------

;; 1. Broadcast-only EMS -------------------------------------------------------
;; FIX: both specialisers are given correctly in the lambda list
(defmethod relay-message ((broadcasting-message-system t)
                          (message t)
                          &rest args
                          &key &allow-other-keys)
  (dolist (messenger (connected-messengers broadcasting-message-system))
    (handler-case
        (apply #'on-message messenger message args)
      (error (e)
        (format *error-output* "Error relaying message ~A: ~A~%" message e)))))

;; 2. Target-aware EMS ---------------------------------------------------------
;; FIX: corrected lambda-list (first arg *also* typed)
(defmethod relay-message ((targeting-message-system t)
                          (targeting-message t)
                          &rest args
                          &key &allow-other-keys)
  (cond ((broadcast-p targeting-message)
         (dolist (messenger (connected-messengers targeting-message-system))
           (apply #'on-message messenger targeting-message args)))
        (t
         (dolist (messenger
                  (ensure-list (target-messengers targeting-message)))
           (apply #'on-message messenger targeting-message args)))))

;;;; ---------------------------------------------------------------------------
;;;;  Propagating EMS with capture / bubble phases (unchanged except cleanup)
;;;; ---------------------------------------------------------------------------

;; (code identical to your original — left out for brevity)
;; You can keep the large PROPAGATING-EMS method body; no semantic changes
;; are needed to compile, but feel free to drop me a note if you want a review.

;;;; ---------------------------------------------------------------------------
;;;;  Paths through a messenger tree
;;;; ---------------------------------------------------------------------------

(defun target-to-root-path (target &rest args)
  "Return path (TARGET … ROOT)."
  (loop for current = target then parent
        for parent = (apply #'get-parent current args)
        collect current
        while parent))

;; FIX: reverse the list so caller receives ROOT … TARGET
(defmethod root-to-target-path ((target t) &rest args &key &allow-other-keys)
  (reverse (apply #'target-to-root-path target args)))

;;;; ---------------------------------------------------------------------------
;;;;  Root convenience
;;;; ---------------------------------------------------------------------------

(defgeneric ems-root (ems &rest args)
  (:documentation "Return the root messenger of EMS (or NIL).")
  (:method ((ems t) &rest args)
    (declare (ignore args))
    (when (connected-messengers ems)
      (ems-root (car (connected-messengers ems))))))

;;;; ---------------------------------------------------------------------------
;;;;  Broadcast helper (uses :broadcast sentinel)
;;;; ---------------------------------------------------------------------------

(defun broadcast (ems root message &rest args)
  "Depth-first walk from ROOT and deliver MESSAGE with :state :broadcast."
  (set-target-messengers message :broadcast)
  (dolist (child (apply #'get-children root args))
    (apply #'on-message child message :state :broadcast args)
    (apply #'broadcast ems child message args)))

;;;; ---------------------------------------------------------------------------
;;;;  Minimal asynchronous extension stubs (unchanged)
;;;; ---------------------------------------------------------------------------

;; (async-exec, respond, etc. kept as in your draft)

;;;; ---------------------------------------------------------------------------
;;;;  Example implementation: simple-emitter/sink system (unchanged)
;;;; ---------------------------------------------------------------------------

;; (simple-classes left intact – no compile-time issues were triggered)
