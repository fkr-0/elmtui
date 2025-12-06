;;;===============================================================\\
;;; File: src/platform/api.lisp\\
;;; Platform Abstraction API\\
;;;\\
;;; This file defines the generic functions that any platform backend\\
;;; must implement to integrate with elmtui. These functions model\\
;;; the abstract behavior required for rendering, input, and display\\
;;; management, independent of any specific terminal library.\\
;;;===============================================================\\

(uiop:define-package :elmtui.platform.api
  (:use :cl)
  (:import-from #:elmtui.utils #:plistp)
  (:export
    :lockable
    :lock-of
    :with-lock
    :acquire-lock
    :release-lock
    ;; Backend Lifecycle
    :initialize-backend
    :shutdown-backend
    :backend-name
    :backend-version

    ;; Display & Screen Management
    :get-screen-dimensions
    :clear-screen
    :with-terminal-output
    :flush-output
    :set-cursor-visibility
    :set-cursor-position
    :get-cursor-position
    :hide-cursor
    :show-cursor
    :handle-backend-resize ; New

    ;; Drawing Primitives
    :draw-text-at
    :draw-char-at
    :fill-rectangle
    :draw-box-outline
    :draw-styled-box ; New generic for detailed border drawing
    :set-cell-style
    :clear-area
    ;; Terminal scrolling/clearing helpers (new)
    :scroll-lines
    :clear-below-cursor

    ;; Rendering
    ;; Color and Style Management
    :make-color
    :make-style
    :apply-style
    :default-foreground-color
    :default-background-color
    :supports-truecolor-p
    :max-colors

    ;; Terminal Instance Accessors (Generic)
    :term-w
    :term-h
    :term-stream
    :term-style
    ;; (setf term-w) and (setf term-h) are made available by exporting :term-w and :term-h
    ;; and defining the (setf ...) generic functions. No need for explicit (setf ...) in :export.

    ;; Input Handling
    :poll-input-event
    :peek-input-event
    :enable-mouse-support
    :disable-mouse-support
    :set-input-mode ; e.g., :raw, :cooked

    ;; Additional Backend Input Helpers
    :backend-input-device
    :backend-input-source

    ;; Capability Querying
    :query-feature
    :supports-unicode-p
    :supports-mouse-p

    ;; Raw Access (Escape Hatch)
    :get-native-handle
    :scroll
    :set-cursor-position))

(in-package :elmtui.platform.api)
;;; ===================================================================
;;; INTERFACE SECTION - Public API declarations
;;; ===================================================================

;;TODO can we add (symbol &key (:publish-fn (or null function))) to initialize-backend?
;;(declaim (ftype (function (t &key (:publish-fn (or null function)) t) t) initialize-backend))
(defgeneric initialize-backend (backend-type &key &allow-other-keys)
  (:documentation "Initialize the backend for the specified platform. If PUBLISH-FN is provided, it will be used to publish events."))

(defgeneric clear-screen (backend-type &optional rect)
  (:documentation "Initialize the backend for the specified platform. If PUBLISH-FN is provided, it will be used to publish events."))

;; Defensive check for initialize-backend
(defmethod initialize-backend :before ((backend-type t) &key &allow-other-keys)
  (unless (keywordp backend-type)
    (log4cl:log-error "initialize-backend: backend-type is not a keyword! Type: ~A, Value: ~S" (type-of backend-type) backend-type)
    (error "initialize-backend: backend-type must be a keyword, got: ~S (type: ~A)" backend-type (type-of backend-type))))

;; (declaim (ftype (function (t) null) shutdown-backend))
;; (declaim (ftype (function (t) string) backend-name backend-version))
;; (declaim (ftype (function (t) (values integer integer)) get-screen-dimensions))





;; (declaim (ftype (function (t integer integer) null) handle-backend-resize))





;; (declaim (ftype (function (t t integer integer &key (:style t)) null) set-cell-style))
;; (declaim (ftype (function (t t integer integer integer integer &key (:style t)) null) clear-area))
;; (declaim (ftype (function (t t) t) render-and-present))
;; (declaim (ftype (function (t &key (:red (or null real)) (:green (or null real)) (:blue (or null real)) (:name symbol)) t) make-color))
;; (declaim (ftype (function (t &key (:foreground-color t) (:background-color t) (:attributes list)) t) make-style))
;; (declaim (ftype (function (t t t) null) apply-style))
;; (declaim (ftype (function (t) t) default-foreground-color default-background-color))
;; (declaim (ftype (function (t) boolean) supports-truecolor-p))
;; (declaim (ftype (function (t) (or null integer)) max-colors))
;; (declaim (ftype (function (t) integer) term-w term-h))
;; (declaim (ftype (function (integer t) integer) (setf term-w) (setf term-h)))
;; (declaim (ftype (function (t) stream) term-stream))
;; (declaim (ftype (function (t) t) term-style))
;; (declaim (ftype (function (t &key (:timeout (or null real))) t) poll-input-event peek-input-event))
;; (declaim (ftype (function (t &key (:motion-events-p boolean)) boolean) enable-mouse-support))
;; (declaim (ftype (function (t) null) disable-mouse-support))
;; (declaim (ftype (function (t symbol) boolean) set-input-mode))
;; (declaim (ftype (function (t keyword) boolean) query-feature))

;; (declaim (ftype (function (t) t) get-native-handle))

(defclass lockable ()
  ((lock :initarg :lock
     :initform (bt:make-recursive-lock)
     :accessor lock-of ; Changed from accessor to reader to prevent direct (setf lock-of)
     :type bt:recursive-lock)
    (lock-owner :initarg :lock-owner
      :initform nil
      :accessor lock-owner
      :type t) ; Can be any thread object or T for generic owner
    (lock-owner-count :initarg :lock-owner-count
      :initform 0
      :accessor lock-owner-count
      :type unsigned-byte)))

;;; ===================================================================
;;; IMPLEMENTATION SECTION
;;; ===================================================================
(defmethod initialize-instance :after ((l lockable) &key)
  (check-type (lock-of l) bt:recursive-lock)
  (check-type (lock-owner-count l) unsigned-byte))

(defmethod acquire-lock ((l lockable))
  "Acquire the terminal lock. If the lock is already held by the current thread,
increment the lock count. Otherwise, acquire the lock and set the lock owner to
the current thread."
  (declare (optimize (speed 3) (safety 0) (debug 0)))
  (let ((current-thread (bt:current-thread)))
    (with-slots (lock lock-owner lock-owner-count)
      l
      (bt:acquire-lock lock t) ; Ensure the lock is acquired before checking owner
      (if (eq lock-owner current-thread)
        (incf (the fixnum lock-owner-count))
        (progn
          (setf lock-owner current-thread)
          (setf lock-owner-count 1)))))
  l) ; Return the lockable object

(defmethod release-lock ((l lockable))
  "Release the terminal lock. If the lock count is greater than 1, decrement the
lock count. Otherwise, release the lock and set the lock owner to nil."
  (declare (optimize (speed 3) (safety 0) (debug 0)))
  (let ((current-thread (bt:current-thread)))
    (with-slots (lock lock-owner lock-owner-count)
      l
      (when (eq lock-owner current-thread)
        (if (> (the fixnum lock-owner-count) 1)
          (decf (the fixnum lock-owner-count))
          (progn
            (setf lock-owner nil)
            (setf lock-owner-count 0)
            (bt:release-lock lock)))))))

(defmacro with-lock ((l) &body body)
  "Execute BODY with the lock of LOCKABLE L acquired.
This macro ensures that the lock is acquired before executing BODY,
and released afterwards, even if an error occurs during execution.
It uses `acquire-lock` and `release-lock` methods to manage the lock.
This is useful for ensuring thread safety when accessing shared resources."
  `(progn
     (acquire-lock ,l)
     (unwind-protect
       (progn ,@body)
       (release-lock ,l))))

(defgeneric scroll (backend n)
  (:documentation "Scroll the terminal display by N lines. Positive N scrolls down, negative N scrolls up."))

(defgeneric clear-below-cursor (backend)
  (:documentation "Clear all content from the cursor position to the end of the screen."))

(defgeneric set-cursor-position (backend x y)
  (:documentation "Set the cursor position to (X, Y) on the terminal."))

(defgeneric backend-input-device (backend)
  (:documentation "Return the underlying cl-inputs device used for reading input, or NIL if the backend does not expose one."))

(defmethod backend-input-device ((backend t))
  nil)

(defgeneric backend-input-source (backend)
  (:documentation "Return the cl-inputs input source that the backend created, if any."))

(defmethod backend-input-source ((backend t))
  nil)
