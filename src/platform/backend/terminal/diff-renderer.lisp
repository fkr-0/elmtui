;;;===============================================================
;;; File: src/platform/backend/terminal/diff-renderer.lisp
;;; Terminal write adapter and compatibility/diagnostics facade.
;;; The pure cell-diff algorithm is now in elmtui.render.diff.
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
  (:import-from :elmtui.render.diff #:buffers-not-compatible-error)
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
    #:*compute-buffer-diff-first-call* ; Deprecated; ignored for compatibility
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
  (full-redraws 0 :type fixnum) ; Count explicitly requested initial-frame diffs
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

(defvar *compute-buffer-diff-first-call* nil
  "Deprecated compatibility variable; ignored by the stateless diff algorithm.
Pass :INITIAL-FRAME-P explicitly to COMPUTE-BUFFER-DIFF instead.")




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
(defun compute-buffer-diff (front-buffer back-buffer &key (initial-frame-p (null front-buffer)))
  "Legacy terminal-facing diff API, delegated to the pure renderer.
INITIAL-FRAME-P is explicit, not process-wide mutable state.
This wrapper updates terminal diagnostics only; the core is side-effect free."
  (multiple-value-bind (operations metrics)
      (elmtui.render.diff:compute-buffer-diff
       front-buffer back-buffer :initial-frame-p initial-frame-p)
    (reset-rendering-stats)
    (setf (rendering-stats-cells-compared *current-rendering-stats*)
          (elmtui.render.diff:diff-metrics-cells-compared metrics)
          (rendering-stats-cells-changed *current-rendering-stats*)
          (elmtui.render.diff:diff-metrics-cells-changed metrics)
          (rendering-stats-diff-batches-created *current-rendering-stats*)
          (elmtui.render.diff:diff-metrics-batches metrics)
          (rendering-stats-full-redraws *current-rendering-stats*)
          (elmtui.render.diff:diff-metrics-full-redraws metrics))
    operations))

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
