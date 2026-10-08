;;;===============================================================
;;; File: src/platform/backend/terminal/diff-renderer.lisp
;;; Diffing Renderer Logic
;;;
;;; This file contains the logic to compute differences between
;;; two virtual terminal buffers and apply those
;;; differences to a terminal.
;;;===============================================================

(uiop:define-package :elmtui.platform.backend.terminal.diff-renderer
  (:use :cl :log4cl)

  (:import-from #:elmtui.platform.api #:term-w #:term-h #:term-style #:term-stream
    #:clear-screen #:flush-output) ; flush-output used by apply-diff-to-backend
  (:import-from #:elmtui.view.geo :=?)
  (:import-from :elmtui.platform.backend.terminal
    #:terminal-instance #:terminal-instance-stream
    #:terminal-instance-current-style
    #:terminal-instance-cl-device
    #:send-sequence
    #:apply-style-diff
    #:write-output)

  (:import-from :elmtui.platform.backend.common.ansi-styling
    #:terminal-style)
  (:import-from :cl-inputs.util #:string-to-utf-8-bytes)
  (:import-from :cl-inputs.device.api #:device-write-bytes)
  (:import-from :elmtui.platform.backend.common.virtual-buffer #:with-virtual-buffer-lock
    #:buffer-cell-at
    #:buffer-cell-style #:buffer-cell-char
    #:default-buffer-cell #:copy-virtual-buffer
    #:buffer-cell-equal-p
    #:virtual-terminal-buffer
    #:clear-buffer
    #:make-virtual-terminal-buffer
    #:virtual-terminal-buffer
    #:make-virtual-terminal-buffer
    #:with-virtual-buffer-lock
    #:virtual-buffer
    #:make-virtual-buffer
    #:buffer-width
    #:buffer-width #:buffer-height #:buffer-cell-at
    #:buffer-cell-style #:buffer-cell-char
    #:default-buffer-cell #:copy-virtual-buffer)
  (:export #:compute-buffer-diff
    #:apply-diff-to-backend
    #:buffers-not-compatible-error
    #:rendering-stats ;; Export the new stats structure and accessor
    #:get-rendering-stats ;; Export the function to get stats
    #:*compute-buffer-diff-first-call* ; <--- EXPORT ADDED HERE
    #:reset-rendering-stats)) ;; Export the function to reset stats

(in-package :elmtui.platform.backend.terminal.diff-renderer)

;;;-----------------------------------------------------------------------------
;;; Rendering Statistics
;;;-----------------------------------------------------------------------------

(defstruct rendering-stats
  "Structure to hold statistics about the rendering process."
  ;; Diff computation stats
  (cells-compared 0 :type fixnum)
  (cells-changed 0 :type fixnum)
  (diff-batches-created 0 :type fixnum)
  (full-redraws 0 :type fixnum) ; Count full redraws triggered by *compute-buffer-diff-first-call*
  ;; Diff application stats
  (ops-processed 0 :type fixnum)
  (style-changes-applied 0 :type fixnum)
  (cursor-moves-applied 0 :type fixnum)
  (chars-written 0 :type fixnum)
  (forced-style-resets 0 :type fixnum))

(defvar *current-rendering-stats* (make-rendering-stats)
  "Holds the statistics for the current rendering cycle or session.")

(defun get-rendering-stats ()
  "Returns a copy of the current rendering statistics."
  (copy-rendering-stats *current-rendering-stats*))

(defun reset-rendering-stats ()
  "Resets the global rendering statistics."
  (setf *current-rendering-stats* (make-rendering-stats))
  (log-info "Rendering statistics reset."))

(defparameter *compute-buffer-diff-first-call* t
  "Non-nil to force a full redraw on first compute-buffer-diff call.")

(defun %blank-background-cell-p (cell)
  "Return true for untouched background cells that should not be emitted.
This keeps the initial render from blanking the terminal with plain spaces,
while still allowing intentional styled spaces to be written."
  (let ((char (buffer-cell-char cell))
        (style (buffer-cell-style cell)))
    (and (null style)
         (or (char= char #\Null)
             (char= char #\Space)))))

(define-condition buffers-not-compatible-error (elmtui.core.errors:elmtui-error)
  ((front-buffer :initarg :front-buffer :reader buffers-not-compatible-error-front)
    (back-buffer :initarg :back-buffer :reader buffers-not-compatible-error-back)
    (reason :initarg :reason :reader buffers-not-compatible-error-reason))
  (:report (lambda (condition stream)
             (log4cl:log-warn (format nil "Buffers are not compatible for diffing. Front: ~A, Back: ~A. Reason: ~A"
                                (buffers-not-compatible-error-front condition)
                                (buffers-not-compatible-error-back condition)
                                (buffers-not-compatible-error-reason condition))
               stream))))
;; (defun apply-terminal-diff (terminal-instance diff-ops)
;;   "Applies the computed Doperations to the terminal.
;; Assumes it's called within WITH-TERMINAL-LOCK."
;;   (check-type terminal-instance terminal-instance)
;;   (check-type diff-ops list)

;;   (let ((logical-cursor-row -1) ; Initialize to ensure first move happens
;;         (logical-cursor-col -1)
;;         ;; Use the terminal's actual current style as the initial logical style
;;         (logical-current-style (elmtui.platform.api:term-style terminal-instance))
;;         (stream (terminal-instance-stream terminal-instance))
;;         (last-row -1)) ; Track the last row we wrote to

;;     (log:debug "APPLY-TERMINAL-DIFF: Starting. Initial logical style: ~S. Num ops: ~A"
;;                logical-current-style (length diff-ops))

;;     (dolist (op diff-ops)
;;       ;; (log:debug "APPLY-TERMINAL-DIFF: Processing op: ~S" op)
;;       (ecase (getf op :type)
;;         (:write-chars
;;          (let ((op-row (getf op :row))
;;                (op-start-col (getf op :start-col))
;;                (op-chars (getf op :chars))
;;                (op-style (getf op :style)))

;;            ;; Reset style when moving to a new row to prevent bleeding
;;            (when (and (> last-row -1) (/= op-row last-row))
;;              (log:debug "APPLY-TERMINAL-DIFF: Moving to new row ~A from ~A, resetting style" op-row last-row)
;;              (apply-style-diff terminal-instance nil) ; Reset to default style
;;              (setf logical-current-style nil))

;;            ;; 1. Set style if different
;;            (unless (equal op-style logical-current-style)
;;              (log:debug "APPLY-TERMINAL-DIFF: Style change. Old: ~S, New: ~S" logical-current-style op-style)
;;              (apply-style-diff terminal-instance op-style) ; apply-style-diff updates terminal-instance-current-style
;;              (setf logical-current-style op-style))

;;            ;; 2. Move cursor if different
;;            (unless (and (= op-row logical-cursor-row)
;;                         (= op-start-col logical-cursor-col))
;;              (log:debug "APPLY-TERMINAL-DIFF: Cursor move. Old: (~A,~A), New: (~A,~A)"
;;                         logical-cursor-row logical-cursor-col op-row op-start-col)
;;              (send-sequence terminal-instance :cursor-set-position (1+ op-row) (1+ op-start-col))
;;              (setf logical-cursor-row op-row
;;                    logical-cursor-col op-start-col))

;;            ;; 3. Write characters
;;            (log:debug "APPLY-TERMINAL-DIFF: Writing chars at (~A,~A)" op-row op-start-col)
;;            (write-string op-chars stream)
;;            (setf logical-cursor-col (+ logical-cursor-col (length op-chars)))

;;            ;; Update last-row
;;            (setf last-row op-row)))))

;;     ;; Final style reset to leave terminal in a clean state
;;     (apply-style-diff terminal-instance nil)

;;     (log:debug "APPLY-TERMINAL-DIFF: All ops processed. Flushing output.")
;;     (finish-output stream)
;;     t))
(defun compute-buffer-diff (front-buffer back-buffer)
  "Compute write operations that transform FRONT-BUFFER into BACK-BUFFER.

Contiguous changed cells with the same style are emitted as one write batch.
Batch strings use an adjustable character vector so extending a long run is
amortized linear rather than repeatedly copying the accumulated prefix."
  (check-type front-buffer virtual-terminal-buffer)
  (check-type back-buffer virtual-terminal-buffer)
  (reset-rendering-stats)

  (unless (and (= (buffer-width front-buffer) (buffer-width back-buffer))
               (= (buffer-height front-buffer) (buffer-height back-buffer)))
    (error 'buffers-not-compatible-error
           :front-buffer front-buffer
           :back-buffer back-buffer
           :reason "Buffer dimensions do not match."))

  (labels ((make-batch (row col char style)
             (let ((chars (make-array 16
                                      :element-type 'character
                                      :adjustable t
                                      :fill-pointer 0)))
               (vector-push-extend char chars)
               (list :type :write-chars
                     :row row
                     :start-col col
                     :chars chars
                     :style style)))
           (append-batch-char (batch char)
             (vector-push-extend char (getf batch :chars)))
           (finish-batch (batch diff-ops)
             (when batch
               (incf (rendering-stats-diff-batches-created
                      *current-rendering-stats*))
               (push batch diff-ops))
             diff-ops))
    (when *compute-buffer-diff-first-call*
      (setf *compute-buffer-diff-first-call* nil)
      (log-debug "BUFFER DIFF: Initial full redraw.")
      (incf (rendering-stats-full-redraws *current-rendering-stats*))
      (let ((diff-ops nil)
            (height (buffer-height back-buffer))
            (width (buffer-width back-buffer)))
        (loop for row below height do
          (let ((current-batch nil))
            (loop for col below width do
              (let* ((back-cell (buffer-cell-at back-buffer row col))
                     (char (let
        ((value (buffer-cell-char back-cell)))
        (if (char= value #\Null) #\Space value)))
                     (style (buffer-cell-style back-cell))
                     (blank-p (%blank-background-cell-p back-cell)))
                (incf (rendering-stats-cells-compared
                       *current-rendering-stats*))
                (unless blank-p
                  (incf (rendering-stats-cells-changed
                         *current-rendering-stats*)))
                (cond
                  ((and current-batch
                        (not blank-p)
                        (=? style (getf current-batch :style)))
                   (append-batch-char current-batch char))
                  (t
                   (setf diff-ops (finish-batch current-batch diff-ops)
                         current-batch (unless blank-p
                                         (make-batch row col char style)))))))
            (setf diff-ops (finish-batch current-batch diff-ops))))
        (return-from compute-buffer-diff (nreverse diff-ops))))

    (let ((diff-ops nil)
          (height (buffer-height front-buffer))
          (width (buffer-width front-buffer)))
      (log-debug "BUFFER DIFF: Starting diff computation for buffers of size ~Ax~A"
                 width height)
      (loop for row below height do
        (let ((current-batch nil))
          (loop for col below width do
            (incf (rendering-stats-cells-compared *current-rendering-stats*))
            (let ((front-cell (buffer-cell-at front-buffer row col))
                  (back-cell (buffer-cell-at back-buffer row col)))
              (if (buffer-cell-equal-p front-cell back-cell)
                  (setf diff-ops (finish-batch current-batch diff-ops)
                        current-batch nil)
                  (let ((char (let
        ((value (buffer-cell-char back-cell)))
        (if (char= value #\Null) #\Space value)))
                        (style (buffer-cell-style back-cell)))
                    (incf (rendering-stats-cells-changed
                           *current-rendering-stats*))
                    (cond
                      ((char= char #\Null)
                       (setf diff-ops (finish-batch current-batch diff-ops)
                             current-batch nil))
                      ((and current-batch
                            (=? style (getf current-batch :style))
                            (= col (+ (getf current-batch :start-col)
                                      (length (getf current-batch :chars)))))
                       (append-batch-char current-batch char))
                      (t
                       (setf diff-ops (finish-batch current-batch diff-ops)
                             current-batch (make-batch row col char style))))))))
          (setf diff-ops (finish-batch current-batch diff-ops))))
      (log-debug "BUFFER DIFF: Final diff-ops count: ~A" (length diff-ops))
      (log-debug "RENDERING STATS (diff): Compared=~A, Changed=~A, Batches=~A, FullRedraws=~A"
                 (rendering-stats-cells-compared *current-rendering-stats*)
                 (rendering-stats-cells-changed *current-rendering-stats*)
                 (rendering-stats-diff-batches-created *current-rendering-stats*)
                 (rendering-stats-full-redraws *current-rendering-stats*))
      (nreverse diff-ops))))

(defun log-buffer-contents (buffer message)
  "Log a sample of buffer contents for debugging."
  (let ((height (min 10 (buffer-height buffer)))  ; Log at most 10 rows
         (width (min 5 (buffer-width buffer))))    ; Log at most 5 columns per row

    (log-info "~A: Buffer size: ~Ax~A (showing ~Ax~A sample)"
      message (buffer-width buffer) (buffer-height buffer) width height)

    ;; (loop for r from 0 below height do
    ;;   (log-info "~A: Row ~A styles:" message r)
    ;;   (let ((row-styles (loop for c from 0 below width
    ;;                           collect (buffer-cell-style (buffer-cell-at buffer r c)))))
    ;;     (log-info "~A:   ~S" message row-styles)))
    ))

(defun debug-buffer-diff (front-buffer back-buffer)
  "Print detailed buffer comparison for debugging."
  (log-info "DEBUG-BUFFER-DIFF: Beginning comparison of front and back buffers")

  (log-buffer-contents front-buffer "FRONT")
  (log-buffer-contents back-buffer "BACK")

  ;; Compare first few rows more thoroughly (currently no-op beyond size logging)
  )

;; Add helper function to modify the apply-terminal-diff function for better debugging
(defun safe-equalp (a b)
  "Safe version of equalp that logs details and handles edge cases."
  (handler-case
    (let ((result (equalp a b)))
      (when (and (not result)
              (or (and (listp a) (listp b))
                (and (vectorp a) (vectorp b))))
        ;; (log-info "SAFE-EQUALP: Comparison failed between: ~S and ~S" a b)
        )
      result)
    (error (e)
      (log-error "SAFE-EQUALP: Error comparing ~S and ~S: ~A" a b e)
      nil)))
;; == elmtui/renderer/apply-diff.lisp ==
(defun %write-string (device stream string)
  (cond
    (device
      (let ((bytes (string-to-utf-8-bytes string)))
        (device-write-bytes device bytes 0 (length bytes))))
    (stream
      (write-string string stream))))

(defun apply-diff-to-backend (diff-ops backend-instance
                               terminal-offset-row terminal-offset-col)
  "Apply a list of diff operations (DIFF-OPS) to BACKEND-INSTANCE.
DIFF-OPS rows/cols are relative to the canvas origin.
TERMINAL-OFFSET-ROW/COL shift the canvas so its (0,0) lands on the terminal."
  (check-type backend-instance terminal-instance)
  (check-type diff-ops list)
  (check-type terminal-offset-row (integer 0 *))
  (check-type terminal-offset-col (integer 0 *))

  (let* ((device (terminal-instance-cl-device backend-instance))
          (stream (terminal-instance-stream backend-instance))
          (cursor-row -1)
          (cursor-col -1)
          (current-style (elmtui.platform.api:term-style backend-instance))
          (last-row -1))

    (dolist (op diff-ops)
      (incf (rendering-stats-ops-processed *current-rendering-stats*))
      (ecase (getf op :type) ;; case: write-chars
        (:write-chars
          (let* ((canvas-row (getf op :row))
                  (canvas-col (getf op :start-col))
                  (chars (getf op :chars))
                  (style (getf op :style))
                  (term-row (+ canvas-row terminal-offset-row))
                  (term-col (+ canvas-col terminal-offset-col)))

            (when (and (>= last-row 0) (/= term-row last-row))
              (apply-style-diff backend-instance nil)
              (incf (rendering-stats-forced-style-resets *current-rendering-stats*))
              (setf current-style nil))

            (unless (equal style current-style)
              (apply-style-diff backend-instance style)
              (incf (rendering-stats-style-changes-applied *current-rendering-stats*))
              (setf current-style style))

            (unless (and (= term-row cursor-row) (= term-col cursor-col))
              (send-sequence backend-instance :cursor-set-position (1+ term-row) (1+ term-col))
              (incf (rendering-stats-cursor-moves-applied *current-rendering-stats*))
              (setf cursor-row term-row
                cursor-col term-col))

            (%write-string device stream chars)
            (incf (rendering-stats-chars-written *current-rendering-stats*) (length chars))
            (incf cursor-col (length chars))
            (setf last-row term-row)))))

    ;; Leave terminal tidy and flush output
    (apply-style-diff backend-instance nil)
    (incf (rendering-stats-forced-style-resets *current-rendering-stats*))
    (when device (cl-inputs.terminal.api:flush-output device))
    (when stream (finish-output stream))
    t))
;; == end/apply-diff.lisp ==
