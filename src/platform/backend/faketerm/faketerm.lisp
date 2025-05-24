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
  (:import-from :alexandria #:array-index) ; For 2D array indexing if needed
  (:export #:faketerm-instance
           #:initialize-backend ; Re-exporting for discoverability
           #:shutdown-backend
           #:backend-name
           #:backend-version
           #:get-char-at-faketerm ; Specific name to avoid conflict if generic exists
           #:get-cell-style-faketerm)) ; Specific name

(in-package :elmtui.backend.faketerm)

(defstruct faketerm-cell
 (char #\Space :type character)
 (style nil :type list)) ; Store style plist directly

(defstruct faketerm-instance
 (filepath nil :type (or null string pathname))
 (stream nil :type (or null stream))
 (width 80 :type integer)
 (height 24 :type integer)
 (screen-buffer nil :type (or null array)) ; 2D array of faketerm-cell
 (cursor-visible-p t :type boolean)
 (cursor-row 0 :type integer)
 (cursor-col 0 :type integer)
 (current-style nil :type list) ; To store style from apply-style
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
    (let* ((screen-buf (make-array (list height width)
                                   :element-type 'faketerm-cell
                                   :initial-element (make-faketerm-cell)))
           (instance (make-faketerm-instance :filepath filepath
                                             :stream stream
                                             :width width
                                             :height height
                                             :screen-buffer screen-buf
                                             :input-queue (copy-list initial-input)
                                             :current-style (list :fg (default-foreground-color nil)
                                                                  :bg (default-background-color nil)
                                                                  :attrs nil))))
      ;; Initialize screen buffer with default cells
      (loop for r below height do
        (loop for c below width do
          (setf (aref screen-buf r c) (make-faketerm-cell :style (faketerm-instance-current-style instance)))))
          
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
  (let ((stream (faketerm-instance-stream instance))
        (buffer (faketerm-instance-screen-buffer instance))
        (default-style (list :fg (default-foreground-color instance) :bg (default-background-color instance) :attrs nil)))
    (format stream "; CLEAR_SCREEN~%")
    (loop for r below (faketerm-instance-height instance) do
      (loop for c below (faketerm-instance-width instance) do
        (setf (aref buffer r c) (make-faketerm-cell :char #\Space :style default-style))))
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
  (let ((stream (faketerm-instance-stream instance))
        (buffer (faketerm-instance-screen-buffer instance))
        (effective-style (or style (faketerm-instance-current-style instance)))
        (max-col (1- (faketerm-instance-width instance)))
        (max-row (1- (faketerm-instance-height instance))))
    (format stream "; DRAW_TEXT_AT Row: ~D Col: ~D Text: ~S Style: ~S~%" row col text effective-style)
    (loop for i from 0 below (length text)
          for c = (+ col i)
          when (and (>= row 0) (<= row max-row) (>= c 0) (<= c max-col))
          do (setf (aref buffer row c) (make-faketerm-cell :char (char text i) :style effective-style)))
    (finish-output stream))
  t)

(defmethod draw-char-at ((instance faketerm-instance) row col char &key style)
  (let ((stream (faketerm-instance-stream instance))
        (buffer (faketerm-instance-screen-buffer instance))
        (effective-style (or style (faketerm-instance-current-style instance)))
        (max-col (1- (faketerm-instance-width instance)))
        (max-row (1- (faketerm-instance-height instance))))
    (format stream "; DRAW_CHAR_AT Row: ~D Col: ~D Char: ~S Style: ~S~%" row col char effective-style)
    (when (and (>= row 0) (<= row max-row) (>= col 0) (<= col max-col))
      (setf (aref buffer row col) (make-faketerm-cell :char char :style effective-style)))
    (finish-output stream))
  t)

(defmethod fill-rectangle ((instance faketerm-instance) row col height width &key char style)
  (let ((stream (faketerm-instance-stream instance))
        (buffer (faketerm-instance-screen-buffer instance))
        (fill-char (or char #\Space))
        (effective-style (or style (faketerm-instance-current-style instance)))
        (max-row (1- (faketerm-instance-height instance)))
        (max-col (1- (faketerm-instance-width instance))))
    (format stream "; FILL_RECTANGLE Row: ~D Col: ~D Height: ~D Width: ~D Char: ~S Style: ~S~%"
            row col height width fill-char effective-style)
    (loop for r from row below (min (+ row height) (1+ max-row))
          do (loop for c from col below (min (+ col width) (1+ max-col))
                   when (and (>= r 0) (>= c 0))
                   do (setf (aref buffer r c) (make-faketerm-cell :char fill-char :style effective-style))))
    (finish-output stream))
  t)

(defmethod draw-box-outline ((instance faketerm-instance) row col height width &key style corners sides)
  (let ((stream (faketerm-instance-stream instance))
        (effective-style (or style (faketerm-instance-current-style instance))))
    (format stream "; DRAW_BOX_OUTLINE Row: ~D Col: ~D Height: ~D Width: ~D Style: ~S Corners: ~S Sides: ~S~%"
            row col height width effective-style corners sides)
    ;; This is a simplified version for logging; actual drawing would call draw-char-at
    (let ((cs (or corners '(#\+ #\+ #\+ #\+)))
          (sds (or sides '(#\- #\|))))
      (draw-char-at instance row col (first cs) :style effective-style)
      (draw-char-at instance row (+ col width -1) (second cs) :style effective-style)
      (draw-char-at instance (+ row height -1) col (third cs) :style effective-style)
      (draw-char-at instance (+ row height -1) (+ col width -1) (fourth cs) :style effective-style)
      (loop for c from (1+ col) below (+ col width -1)
            do (draw-char-at instance row c (first sds) :style effective-style)
               (draw-char-at instance (+ row height -1) c (first sds) :style effective-style))
      (loop for r from (1+ row) below (+ row height -1)
            do (draw-char-at instance r col (second sds) :style effective-style)
               (draw-char-at instance r (+ col width -1) (second sds) :style effective-style)))
    (finish-output stream))
  t)

(defmethod draw-styled-box ((instance faketerm-instance) row col height width &key border-style border-color box-char-set style)
  (declare (ignore box-char-set)) ; Not using custom char sets for faketerm yet
  (let* ((stream (faketerm-instance-stream instance))
         (effective-style (if border-color
                              (list :fg border-color :attrs (getf style :attrs)) ; Prioritize explicit border-color
                              (or style (faketerm-instance-current-style instance))))
         (chars (case border-style
                  (:single '(#\┌ #\┐ #\└ #\┘ #\─ #\│))
                  (:double '(#\╔ #\╗ #\╚ #\╝ #\═ #\║))
                  (otherwise '(#\+ #\+ #\+ #\+ #\- #\|))))) ; Default
    (format stream "; DRAW_STYLED_BOX Row: ~D Col: ~D H: ~D W: ~D BorderStyle: ~S BorderColor: ~S Style: ~S~%"
            row col height width border-style border-color effective-style)
    (apply-style instance effective-style) ; Set current style for subsequent draw-char-at calls
    (draw-box-outline instance row col height width :style effective-style :corners (subseq chars 0 4) :sides (subseq chars 4 6))
    (apply-style instance (faketerm-instance-current-style instance)) ; Restore previous style
    (finish-output stream))
  t)

(defmethod set-cell-style ((instance faketerm-instance) row col &key style)
  (let ((stream (faketerm-instance-stream instance)))
    (format stream "; SET_CELL_STYLE Row: ~D Col: ~D Style: ~S~%" row col (or style (faketerm-instance-current-style instance)))
    (finish-output stream))
  t)

(defmethod clear-area ((instance faketerm-instance) row col height width &key style)
  (let ((stream (faketerm-instance-stream instance))
        (buffer (faketerm-instance-screen-buffer instance))
        (effective-style (or style (list :fg (default-foreground-color instance) :bg (default-background-color instance) :attrs nil)))
        (max-row (1- (faketerm-instance-height instance)))
        (max-col (1- (faketerm-instance-width instance))))
    (format stream "; CLEAR_AREA Row: ~D Col: ~D Height: ~D Width: ~D Style: ~S~%"
            row col height width effective-style)
    (loop for r from row below (min (+ row height) (1+ max-row))
          do (loop for c from col below (min (+ col width) (1+ max-col))
                   when (and (>= r 0) (>= c 0))
                   do (setf (aref buffer r c) (make-faketerm-cell :char #\Space :style effective-style))))
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
;;; Screen Buffer Query API (for testing)
;;;---------------------------------------------------------------

(defun get-char-at-faketerm (instance row col)
  "Returns the character at the given row and col from the screen buffer."
  (when (and (>= row 0) (< row (faketerm-instance-height instance))
             (>= col 0) (< col (faketerm-instance-width instance)))
    (faketerm-cell-char (aref (faketerm-instance-screen-buffer instance) row col))))

(defun get-cell-style-faketerm (instance row col)
  "Returns the style plist at the given row and col from the screen buffer."
  (when (and (>= row 0) (< row (faketerm-instance-height instance))
             (>= col 0) (< col (faketerm-instance-width instance)))
    (faketerm-cell-style (aref (faketerm-instance-screen-buffer instance) row col))))
;;;---------------------------------------------------------------
;;; Raw Access (Escape Hatch)
;;;---------------------------------------------------------------

(defmethod get-native-handle ((instance faketerm-instance))
  nil) ; No native handle for faketerm
