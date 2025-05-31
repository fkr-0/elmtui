;;;===============================================================
;;; File: src/platform/backend/terminal/diff-renderer.lisp
;;; Diffing Renderer Logic
;;;
;;; This file contains the logic to compute differences between
;;; two virtual terminal buffers and (eventually) apply those
;;; differences to a terminal.
;;;===============================================================

(uiop:define-package :elmtui.platform.backend.terminal.diff-renderer
  (:use :cl :log4cl)

  (:import-from #:elmtui.platform.api #:term-w #:term-h #:term-style #:term-stream)
  (:import-from #:elmtui.platform.canvas
                #:canvas
                #:make-terminal-canvas
                #:initialize-terminal-canvas
                #:get-canvas-viewport
                #:apply-canvas-to-buffer
                #:restore-terminal-state
                #:canvas-buffer) ; For render-and-present
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:virtual-terminal-buffer #:make-virtual-terminal-buffer
                #:with-virtual-buffer-lock #:clear-buffer
                #:virtual-terminal-buffer #:buffer-width #:buffer-height
                #:buffer-cell-at #:buffer-cell-equal-p
                #:buffer-cell-char #:buffer-cell-style) ; For accessing cell components
  (:import-from :elmtui.backend.common.ansi-styling
                #:ansi-seqs #:copy-term-style
                #:exec-sequence #:update-style! #:make-terminal-style)
  (:import-from :elmtui.platform.backend.terminal
                #:terminal-instance-front-buffer
                #:terminal-instance-back-buffer
                #:terminal-instance #:send-sequence #:apply-style-diff
                #:terminal-instance-stream #:with-terminal-lock
                #:terminal-instance-lock
                #:style-to-terminal-style)
  (:export #:compute-buffer-diff
           #:apply-terminal-diff ; Will be implemented later
           #:buffers-not-compatible-error))

(in-package :elmtui.platform.backend.terminal.diff-renderer)

(define-condition buffers-not-compatible-error (error)
  ((front-buffer :initarg :front-buffer :reader buffers-not-compatible-error-front)
   (back-buffer :initarg :back-buffer :reader buffers-not-compatible-error-back)
   (reason :initarg :reason :reader buffers-not-compatible-error-reason))
  (:report (lambda (condition stream)
             (format stream "Buffers are not compatible for diffing. Front: ~A, Back: ~A. Reason: ~A"
                     (buffers-not-compatible-error-front condition)
                     (buffers-not-compatible-error-back condition)
                     (buffers-not-compatible-error-reason condition)))))
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
  "Computes a list of operations to transform FRONT-BUFFER into BACK-BUFFER.
Assumes buffers have the same dimensions.
Optimizes by batching contiguous character updates with the same style."
  (check-type front-buffer virtual-terminal-buffer)
  (check-type back-buffer virtual-terminal-buffer)

  (unless (and (= (buffer-width front-buffer) (buffer-width back-buffer))
               (= (buffer-height front-buffer) (buffer-height back-buffer)))
    (error 'buffers-not-compatible-error
           :front-buffer front-buffer
           :back-buffer back-buffer
           :reason "Buffer dimensions do not match."))

  ;; Debug comparison of front and back buffers
  (debug-buffer-diff front-buffer back-buffer)

  (let ((diff-ops '())
        (height (buffer-height front-buffer))
        (width (buffer-width front-buffer))
        (equal-count 0)
        (diff-count 0))

    (log-info "BUFFER DIFF: Starting diff computation for buffers of size ~Ax~A" width height)

    (loop for r from 0 below height do
      (let ((current-batch nil)) ; To hold (:type :write-chars :row r :start-col c :chars string :style s)
        (log-info "BUFFER DIFF: Processing row ~A" r)
        (loop for c from 0 below width do
          (let ((cell-front (buffer-cell-at front-buffer r c))
                (cell-back (buffer-cell-at back-buffer r c)))

            ;; Log details about first few cells in each row
            (when (< c 3)
              (log-info "BUFFER DIFF: [Row ~A, Col ~A] Front style: ~S, Back style: ~S"
                        r c (buffer-cell-style cell-front) (buffer-cell-style cell-back)))

            (if (buffer-cell-equal-p cell-front cell-back)
                (progn
                  ;; Cells are the same, finalize any open batch
                  (incf equal-count)
                  (when (and (= c 0) (= r 0))
                    (log-info "BUFFER DIFF: First cell comparison is EQUAL"))
                  (when current-batch
                    (push current-batch diff-ops)
                    (setf current-batch nil)))
                ;; Cells are different
                (let ((char-back (buffer-cell-char cell-back))
                      (style-back (buffer-cell-style cell-back)))
                  (incf diff-count)
                  (when (and (= c 0) (= r 0))
                    (log-info "BUFFER DIFF: First cell comparison is DIFFERENT"))
                  (if current-batch
                      ;; Check if this different cell can extend the current batch
                      (if (equalp (getf current-batch :style) style-back)
                          ;; Same style, extend chars
                          (progn
                            (setf (getf current-batch :chars)
                                  (concatenate 'string (getf current-batch :chars) (string char-back))))
                          ;; Different style, finalize current batch and start a new one
                          (progn
                            (push current-batch diff-ops)
                            (log-info "BUFFER DIFF: Pushing batch: ~A Style back: ~A" current-batch style-back)
                            (setf current-batch
                                  (list :type :write-chars
                                        :row r
                                        :start-col c
                                        :chars (string char-back)
                                        :style style-back))))
                      ;; No current batch, start a new one
                      (progn
                        (log-info "BUFFER DIFF: Starting new batch at [~A,~A] with style ~S" r c style-back)
                        (setf current-batch
                              (list :type :write-chars
                                    :row r
                                    :start-col c
                                    :chars (string char-back)
                                    :style style-back))))))))
        ;; After iterating all columns in a row, finalize any open batch
        (when current-batch
          (push current-batch diff-ops)
          (setf current-batch nil))))

    (log-info "BUFFER DIFF: Cells compared - Equal: ~A, Different: ~A" equal-count diff-count)
    (log-info "BUFFER DIFF: Final diff-ops count: ~A" (length diff-ops))
    (log-info "BUFFER DIFF: Final diff-ops: ~A" diff-ops)
    (nreverse diff-ops)))

(defun log-buffer-contents (buffer message)
  "Log a sample of buffer contents for debugging."
  (let ((height (min 10 (buffer-height buffer)))  ; Log at most 10 rows
        (width (min 5 (buffer-width buffer))))    ; Log at most 5 columns per row

    (log-info "~A: Buffer size: ~Ax~A (showing ~Ax~A sample)"
              message (buffer-width buffer) (buffer-height buffer) width height)

    (loop for r from 0 below height do
      (log-info "~A: Row ~A styles:" message r)
      (let ((row-styles (loop for c from 0 below width
                              collect (buffer-cell-style (buffer-cell-at buffer r c)))))
        (log-info "~A:   ~S" message row-styles)))))

(defun debug-buffer-diff (front-buffer back-buffer)
  "Print detailed buffer comparison for debugging."
  (log-info "DEBUG-BUFFER-DIFF: Beginning comparison of front and back buffers")

  (log-buffer-contents front-buffer "FRONT")
  (log-buffer-contents back-buffer "BACK")

  ;; Compare first few rows more thoroughly
  (loop for r from 0 below (min 8 (buffer-height front-buffer)) do
    (let ((first-front-style (buffer-cell-style (buffer-cell-at front-buffer r 0)))
          (first-back-style (buffer-cell-style (buffer-cell-at back-buffer r 0))))

      (log-info "ROW ~A COMPARISON: Front style: ~S, Back style: ~S, Equal: ~A"
                r first-front-style first-back-style
                (equalp first-front-style first-back-style))

      ;; If they're claimed to be equal but look different, investigate further
      (when (and (equalp first-front-style first-back-style)
                 (not (equal first-front-style first-back-style)))
        (log-info "ANOMALY: styles claim to be equalp but not equal")
        (log-info "Front style type: ~A, Back style type: ~A"
                  (type-of first-front-style) (type-of first-back-style))

        ;; Check each key-value pair
        (loop for (k v) on first-front-style by #'cddr do
          (let ((back-v (getf first-back-style k 'not-found)))
            (log-info "Key ~S: Front=~S, Back=~S, Equal=~A, Type equal=~A"
                      k v back-v (equal v back-v)
                      (eq (type-of v) (type-of back-v)))))))))

;; Add helper function to modify the apply-terminal-diff function for better debugging
(defun safe-equalp (a b)
  "Safe version of equalp that logs details and handles edge cases."
  (handler-case
      (let ((result (equalp a b)))
        (when (and (not result)
                   (or (and (listp a) (listp b))
                       (and (vectorp a) (vectorp b))))
          (log-info "SAFE-EQUALP: Comparison failed between: ~S and ~S" a b))
        result)
    (error (e)
      (log-error "SAFE-EQUALP: Error comparing ~S and ~S: ~A" a b e)
      nil)))

(defun apply-terminal-diff (terminal-instance diff-ops)
  "Applies the computed diff operations to the terminal using ANSI styling."
  (check-type terminal-instance terminal-instance)
  (check-type diff-ops list)

  (let ((logical-cursor-row -1)
        (logical-cursor-col -1)
        (stream (terminal-instance-stream terminal-instance))
        (last-row -1))

    (log:debug "APPLY-TERMINAL-DIFF: Starting. Num ops: ~A" (length diff-ops))

    ;; Sort diff ops by row and column for predictable processing
    (setf diff-ops
          (stable-sort diff-ops #'(lambda (a b)
                                    (or (< (getf a :row) (getf b :row))
                                        (and (= (getf a :row) (getf b :row))
                                             (< (getf (or a '(:start-col 0)) :start-col)
                                                (getf (or b '(:start-col 0)) :start-col)))))))

    ;; Initial full reset using the ansi-styling functions
    (elmtui.platform.backend.terminal:write-style-reset-to-stream stream)

    (dolist (op diff-ops)
      (ecase (getf op :type)
        (:write-chars
         (let ((op-row (getf op :row))
               (op-start-col (getf op :start-col))
               (op-chars (getf op :chars))
               (op-style (getf op :style)))

           ;; Always reset style when moving to a new row or new position
           (when (or (not (= last-row op-row))
                     (not (and (= op-row logical-cursor-row)
                               (= op-start-col logical-cursor-col))))
             (elmtui.platform.backend.terminal:write-style-reset-to-stream stream)
             (setf last-row op-row))

           ;; Move cursor - always use direct cursor positioning
           (unless (and (= op-row logical-cursor-row)
                        (= op-start-col logical-cursor-col))
             (log:debug "APPLY-TERMINAL-DIFF: Cursor move. Row: ~A, Col: ~A" op-row op-start-col)
             ;; Direct cursor positioning - doesn't go through ANSI styling
             (format stream "~A[~A;~AH" (code-char 27) (1+ op-row) (1+ op-start-col))
             (setf logical-cursor-row op-row
                   logical-cursor-col op-start-col))

           ;; Apply the style directly - no need to track delta or update a current style
           (when op-style
             (log:debug "APPLY-TERMINAL-DIFF: Applying style for position (~A,~A): ~S"
                        op-row op-start-col op-style)
             (elmtui.platform.backend.terminal:write-style-to-stream stream op-style))

           ;; Write the characters for this op
           (log:debug "APPLY-TERMINAL-DIFF: Writing chars at (~A,~A): ~S" op-row op-start-col op-chars)
           (write-string op-chars stream)
           (setf logical-cursor-col (+ logical-cursor-col (length op-chars)))))))

    ;; Final style reset
    (elmtui.platform.backend.terminal:write-style-reset-to-stream stream)

    (log:debug "APPLY-TERMINAL-DIFF: All ops processed. Flushing output.")
    (finish-output stream))
  t)

(defmethod render-and-present ((instance terminal-instance) laid-tree &optional canvas-instance)
  (let* ((front-buffer (terminal-instance-front-buffer instance))
         (back-buffer (terminal-instance-back-buffer instance))
         (original-back-buffer-for-canvas back-buffer)) ; Save original back-buffer if canvas is used

    (unless (and front-buffer back-buffer)
      (log:error "TERMINAL: Buffers not initialized. Skipping render.")
      (return-from render-and-present nil))

    ;; 1. Prepare back-buffer (clear it, potentially use canvas buffer)
    (if canvas-instance
        (let ((canvas-buf (canvas-buffer canvas-instance)))
          (with-virtual-buffer-lock (canvas-buf) (clear-buffer canvas-buf))
          (setf back-buffer canvas-buf)) ; Temporarily use canvas buffer as the back buffer for render-frame
        (with-virtual-buffer-lock (back-buffer) (clear-buffer back-buffer))) ; Clear normal back-buffer

    ;; 2. Render the laid-out tree to the (potentially temporary) back-buffer
    ;; render-frame uses generic drawing primitives which draw to the backend's back-buffer.
    (elmtui.platform.output:render-frame laid-tree instance back-buffer) ; Pass explicit back-buffer

    ;; 3. If canvas was used, apply its content to the original back-buffer
    (when canvas-instance
      (setf back-buffer original-back-buffer-for-canvas) ; Restore original back-buffer
      ;; Now 'canvas-buf' has the canvas content, 'back-buffer' is the main screen back-buffer.
      (apply-canvas-to-buffer canvas-instance back-buffer))

    ;; 4. Compute diff between front and (final) back buffer, and apply to terminal
    (if (and front-buffer back-buffer
             (= (buffer-width front-buffer) (buffer-width back-buffer))
             (= (buffer-height front-buffer) (buffer-height back-buffer)))
        (let ((diff-ops (compute-buffer-diff front-buffer back-buffer)))
          (when diff-ops
            (with-terminal-lock (instance)
              (apply-terminal-diff instance diff-ops) ; apply-terminal-diff writes to instance's stream
              (finish-output (term-stream instance)))) ; Ensure changes are flushed
          ;; 5. Swap front and back buffers
          (rotatef (terminal-instance-front-buffer instance)
                   (terminal-instance-back-buffer instance)) ; The old front becomes new back
          t)
        (progn
          (log:error "TERMINAL: Buffer mismatch or invalid buffers. Skipping diff/swap. Front: ~S, Back: ~S"
                     front-buffer back-buffer)
          nil))))
