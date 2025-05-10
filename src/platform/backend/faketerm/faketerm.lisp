;;;===============================================================
;;; File: src/platform/backend/faketerm/faketerm.lisp
;;; Fake Terminal Backend
;;;
;;; This backend simulates a terminal by writing drawing operations
;;; and state changes to a log file. It's useful for testing
;;; rendering logic without a real terminal interface.
;;;===============================================================

(uiop:define-package :elmtui.backend.faketerm
  (:use :cl :elmtui.platform.api)
  (:export #:faketerm-instance
           #:initialize-backend ; Re-exporting for discoverability
           #:shutdown-backend
           #:backend-name
           #:backend-version))

(in-package :elmtui.backend.faketerm)

(defstruct faketerm-instance
  (filepath nil :type (or null string pathname))
  (stream nil :type (or null stream))
  (width 80 :type integer)
  (height 24 :type integer)
  (cursor-visible-p t :type boolean)
  (cursor-row 0 :type integer)
  (cursor-col 0 :type integer)
  (current-style nil) ; To store style from apply-style
  (input-queue (make-list 0) :type list)) ; For simulating input

;;;---------------------------------------------------------------
;;; Backend Lifecycle
;;;---------------------------------------------------------------

(defmethod initialize-backend ((backend-type (eql :faketerm)) &key filepath (width 80) (height 24) (initial-input nil) &allow-other-keys)
  (unless filepath
    (error "Filepath is required for faketerm backend."))
  (let ((stream
          (open filepath :direction :output
                         :if-exists :supersede
                         :if-does-not-exist :create)))
    ;; (unless stream
    ;;   (error "Could not open file for faketerm backend: ~A" filepath))
    (let* ((instance (make-faketerm-instance :filepath filepath
                                             :stream stream
                                             :width width
                                             :height height
                                             :input-queue (copy-list initial-input))))
      (format (faketerm-instance-stream instance)
              "; Faketerm Initialized: ~A (Width: ~D, Height: ~D)~%"
              (faketerm-instance-filepath instance)
              (faketerm-instance-width instance)
              (faketerm-instance-height instance))
      (finish-output (faketerm-instance-stream instance))
      instance)))

(defmethod shutdown-backend ((instance faketerm-instance))
  (when (faketerm-instance-stream instance)
    (format (faketerm-instance-stream instance) "; Faketerm Shutdown~%")
    (finish-output (faketerm-instance-stream instance))
    (close (faketerm-instance-stream instance))
    (setf (faketerm-instance-stream instance) nil))
  t)

(defmethod backend-name ((instance faketerm-instance))
  "FakeTerm")

(defmethod backend-version ((instance faketerm-instance))
  "0.1.0")

;;;---------------------------------------------------------------
;;; Display & Screen Management
;;;---------------------------------------------------------------

(defmethod get-screen-dimensions ((instance faketerm-instance))
  (values (faketerm-instance-width instance) (faketerm-instance-height instance)))

(defmethod clear-screen ((instance faketerm-instance))
  (let ((stream (faketerm-instance-stream instance)))
    (format stream "; CLEAR_SCREEN~%")
    (finish-output stream))
  t)

(defmethod flush-output ((instance faketerm-instance))
  (when (faketerm-instance-stream instance)
    (finish-output (faketerm-instance-stream instance)))
  t)

(defmethod set-cursor-visibility ((instance faketerm-instance) visible-p)
  (setf (faketerm-instance-cursor-visible-p instance) visible-p)
  (format (faketerm-instance-stream instance) "; SET_CURSOR_VISIBILITY ~A~%" visible-p)
  (finish-output (faketerm-instance-stream instance))
  t)

(defmethod set-cursor-position ((instance faketerm-instance) row col)
  (setf (faketerm-instance-cursor-row instance) row)
  (setf (faketerm-instance-cursor-col instance) col)
  (format (faketerm-instance-stream instance) "; SET_CURSOR_POSITION Row: ~D Col: ~D~%" row col)
  (finish-output (faketerm-instance-stream instance))
  t)

(defmethod get-cursor-position ((instance faketerm-instance))
  (values (faketerm-instance-cursor-row instance) (faketerm-instance-cursor-col instance)))

(defmethod hide-cursor ((instance faketerm-instance))
  (set-cursor-visibility instance nil))

(defmethod show-cursor ((instance faketerm-instance))
  (set-cursor-visibility instance t))

;;;---------------------------------------------------------------
;;; Drawing Primitives
;;;---------------------------------------------------------------

(defmethod draw-text-at ((instance faketerm-instance) row col text &key style)
  (let ((stream (faketerm-instance-stream instance)))
    (format stream "; DRAW_TEXT_AT Row: ~D Col: ~D Text: ~S Style: ~S~%" row col text (or style (faketerm-instance-current-style instance)))
    (finish-output stream))
  t)

(defmethod draw-char-at ((instance faketerm-instance) row col char &key style)
  (let ((stream (faketerm-instance-stream instance)))
    (format stream "; DRAW_CHAR_AT Row: ~D Col: ~D Char: ~S Style: ~S~%" row col char (or style (faketerm-instance-current-style instance)))
    (finish-output stream))
  t)

(defmethod fill-rectangle ((instance faketerm-instance) row col height width &key char style)
  (let ((stream (faketerm-instance-stream instance)))
    (format stream "; FILL_RECTANGLE Row: ~D Col: ~D Height: ~D Width: ~D Char: ~S Style: ~S~%"
            row col height width char (or style (faketerm-instance-current-style instance)))
    (finish-output stream))
  t)

(defmethod draw-box-outline ((instance faketerm-instance) row col height width &key style corners sides)
  (let ((stream (faketerm-instance-stream instance)))
    (format stream "; DRAW_BOX_OUTLINE Row: ~D Col: ~D Height: ~D Width: ~D Style: ~S Corners: ~S Sides: ~S~%"
            row col height width (or style (faketerm-instance-current-style instance)) corners sides)
    (finish-output stream))
  t)

(defmethod set-cell-style ((instance faketerm-instance) row col &key style)
  (let ((stream (faketerm-instance-stream instance)))
    (format stream "; SET_CELL_STYLE Row: ~D Col: ~D Style: ~S~%" row col (or style (faketerm-instance-current-style instance)))
    (finish-output stream))
  t)

(defmethod clear-area ((instance faketerm-instance) row col height width &key style)
  (let ((stream (faketerm-instance-stream instance)))
    (format stream "; CLEAR_AREA Row: ~D Col: ~D Height: ~D Width: ~D Style: ~S~%"
            row col height width (or style (faketerm-instance-current-style instance)))
    (finish-output stream))
  t)

;;;---------------------------------------------------------------
;;; Color and Style Management
;;;---------------------------------------------------------------

(defmethod make-color ((instance faketerm-instance) r-or-name &optional g b)
  (if g ; Assuming if g is present, it's RGB
      (list :rgb r-or-name g b)
      r-or-name)) ; Otherwise, it's a named color like :RED

(defmethod make-style ((instance faketerm-instance) &key foreground-color background-color attributes)
  (list :fg foreground-color :bg background-color :attrs attributes))

(defmethod apply-style ((instance faketerm-instance) style)
  (setf (faketerm-instance-current-style instance) style)
  (format (faketerm-instance-stream instance) "; APPLY_STYLE Style: ~S~%" style)
  (finish-output (faketerm-instance-stream instance))
  t)

(defmethod default-foreground-color ((instance faketerm-instance))
  :white)

(defmethod default-background-color ((instance faketerm-instance))
  :black)

(defmethod supports-truecolor-p ((instance faketerm-instance))
  t) ; Can log RGB values

(defmethod max-colors ((instance faketerm-instance))
  (expt 2 24))

;;;---------------------------------------------------------------
;;; Input Handling
;;;---------------------------------------------------------------

(defmethod poll-input-event ((instance faketerm-instance) &key timeout)
  (declare (ignore timeout)) ; Timeout not really applicable for simple queue
  (if (faketerm-instance-input-queue instance)
      (let ((event (pop (faketerm-instance-input-queue instance))))
        (format (faketerm-instance-stream instance) "; POLL_INPUT_EVENT Event: ~S~%" event)
        (finish-output (faketerm-instance-stream instance))
        event)
      nil))

(defmethod peek-input-event ((instance faketerm-instance))
  (if (faketerm-instance-input-queue instance)
      (let ((event (first (faketerm-instance-input-queue instance))))
        (format (faketerm-instance-stream instance) "; PEEK_INPUT_EVENT Event: ~S~%" event)
        (finish-output (faketerm-instance-stream instance))
        event)
      nil))

(defmethod enable-mouse-support ((instance faketerm-instance) &key motion-events-p)
  (format (faketerm-instance-stream instance) "; ENABLE_MOUSE_SUPPORT Motion: ~A~%" motion-events-p)
  (finish-output (faketerm-instance-stream instance))
  t) ; Can log mouse events

(defmethod disable-mouse-support ((instance faketerm-instance))
  (format (faketerm-instance-stream instance) "; DISABLE_MOUSE_SUPPORT~%")
  (finish-output (faketerm-instance-stream instance))
  t)

(defmethod set-input-mode ((instance faketerm-instance) mode)
  (format (faketerm-instance-stream instance) "; SET_INPUT_MODE Mode: ~S~%" mode)
  (finish-output (faketerm-instance-stream instance))
  t)

;;;---------------------------------------------------------------
;;; Capability Querying
;;;---------------------------------------------------------------

(defmethod query-feature ((instance faketerm-instance) feature-keyword)
  (let ((stream (faketerm-instance-stream instance)))
    (format stream "; QUERY_FEATURE Feature: ~S~%" feature-keyword)
    (finish-output stream)
    (case feature-keyword
      (:unicode t)
      (:truecolor t)
      (:mouse t) ; Assume we can log mouse events
      (otherwise nil))))

(defmethod supports-unicode-p ((instance faketerm-instance))
  (query-feature instance :unicode))

(defmethod supports-mouse-p ((instance faketerm-instance))
  (query-feature instance :mouse))

;;;---------------------------------------------------------------
;;; Raw Access (Escape Hatch)
;;;---------------------------------------------------------------

(defmethod get-native-handle ((instance faketerm-instance))
  nil) ; No native handle for faketerm
