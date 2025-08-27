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
                #:apply-style-diff
                #:send-sequence)

  (:import-from :elmtui.platform.backend.common.ansi-styling
                #:ansi-seqs #:copy-term-style
                #:make-terminal-style #:make-termcolor
                #:exec-sequence #:update-style! #:make-terminal-style)
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

(define-condition buffers-not-compatible-error (error)
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
  "Computes a list of operations to transform FRONT-BUFFER into BACK-BUFFER.
Assumes buffers have the same dimensions.
Optimizes by batching contiguous character updates with the same style."
  (check-type front-buffer virtual-terminal-buffer)
  (check-type back-buffer virtual-terminal-buffer)
  (reset-rendering-stats) ; Reset stats at the beginning of a new diff computation

  (unless (and (= (buffer-width front-buffer) (buffer-width back-buffer))
               (= (buffer-height front-buffer) (buffer-height back-buffer)))
    (error 'buffers-not-compatible-error
           :front-buffer front-buffer
           :back-buffer back-buffer
           :reason "Buffer dimensions do not match."))

  ;; First-time full redraw override
  (when *compute-buffer-diff-first-call*
    (setf *compute-buffer-diff-first-call* nil)
    (log-info "BUFFER DIFF: Initial full redraw.")
    (incf (rendering-stats-full-redraws *current-rendering-stats*))
    (let ((diff-ops '())
          (height (buffer-height back-buffer))
          (width (buffer-width back-buffer)))
      (loop for r from 0 below height do
        (let ((current-batch nil))
          (loop for c from 0 below width do
            (let* ((back-cell (buffer-cell-at back-buffer r c))
                   (char (buffer-cell-char back-cell))
                   (style (buffer-cell-style back-cell)))
              (incf (rendering-stats-cells-compared *current-rendering-stats*)) ; Count even for full redraw
              (incf (rendering-stats-cells-changed *current-rendering-stats*))  ; All cells are "changed" in a full redraw
              (if current-batch
                  (if (and (char/= char #\Null) (equal style (getf current-batch :style)))
                      (setf (getf current-batch :chars) (concatenate 'string (getf current-batch :chars) (string char)))
                      (progn
                        (push current-batch diff-ops)
                        (incf (rendering-stats-diff-batches-created *current-rendering-stats*))
                        (if (char/= char #\Null)
                            (setf current-batch (list :type :write-chars :row r :start-col c :chars (string char) :style style))
                            (setf current-batch nil))))
                  (when (char/= char #\Null)
                    (setf current-batch (list :type :write-chars :row r :start-col c :chars (string char) :style style))))))
          (when current-batch
            (push current-batch diff-ops)
            (incf (rendering-stats-diff-batches-created *current-rendering-stats*)))))
      (return-from compute-buffer-diff (nreverse diff-ops))))
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
        ;; (log-info "BUFFER DIFF: Processing row ~A" r)
        (loop for c from 0 below width do
          (incf (rendering-stats-cells-compared *current-rendering-stats*))
          (let ((front-cell (buffer-cell-at front-buffer r c))
                (back-cell (buffer-cell-at back-buffer r c)))
            (if (buffer-cell-equal-p front-cell back-cell)
                (progn
                  (incf equal-count)
                  (when current-batch
                    (push current-batch diff-ops)
                    (incf (rendering-stats-diff-batches-created *current-rendering-stats*))
                    (setf current-batch nil)))
                (progn
                  (incf diff-count)
                  (incf (rendering-stats-cells-changed *current-rendering-stats*))
                  (let ((char (buffer-cell-char back-cell))
                        (style (buffer-cell-style back-cell)))
                    (if current-batch
                        (if (and (char/= char #\Null)
                                 (equal style (getf current-batch :style))
                                 (= c (+ (getf current-batch :start-col) (length (getf current-batch :chars)))))
                            (setf (getf current-batch :chars) (concatenate 'string (getf current-batch :chars) (string char)))
                            (progn
                              (push current-batch diff-ops)
                              (incf (rendering-stats-diff-batches-created *current-rendering-stats*))
                              (if (char/= char #\Null)
                                  (setf current-batch (list :type :write-chars :row r :start-col c :chars (string char) :style style))
                                  (setf current-batch nil))))
                        (when (char/= char #\Null)
                          (setf current-batch (list :type :write-chars :row r :start-col c :chars (string char) :style style))))))))
          (when current-batch
            (push current-batch diff-ops)
            (incf (rendering-stats-diff-batches-created *current-rendering-stats*))))))
    (log-info "BUFFER DIFF: Cells compared - Equal: ~A, Different: ~A" equal-count diff-count)
    (log-info "BUFFER DIFF: Final diff-ops count: ~A" (length diff-ops))
    ;; (log-info "BUFFER DIFF: Final diff-ops: ~A" diff-ops)
    (log-info "RENDERING STATS (diff): Compared=~A, Changed=~A, Batches=~A, FullRedraws=~A"
              (rendering-stats-cells-compared *current-rendering-stats*)
              (rendering-stats-cells-changed *current-rendering-stats*)
              (rendering-stats-diff-batches-created *current-rendering-stats*)
              (rendering-stats-full-redraws *current-rendering-stats*))
    (nreverse diff-ops)))

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

  ;; Compare first few rows more thoroughly
  (loop for r from 0 below (min 8 (buffer-height front-buffer)) do
    (let ((first-front-style (buffer-cell-style (buffer-cell-at front-buffer r 0)))
          (first-back-style (buffer-cell-style (buffer-cell-at back-buffer r 0))))

      ;; If they're claimed to be equal but look different, investigate further
      (when (and (equalp first-front-style first-back-style)
                 (not (equal first-front-style first-back-style)))
        (log-info "ANOMALY: styles claim to be equalp but not equal")
        (log-info "Front style type: ~A, Back style type: ~A"
                  (type-of first-front-style) (type-of first-back-style))

        ;; Check each key-value pair
        ;; (loop for slot-def in (sb-mop:class-slots (class-of first-front-style))
        ;;       do (let* ((slot-name (sb-mop:slot-definition-name slot-def))
        ;;                 (front-v (slot-value first-front-style slot-name))
        ;;                 (back-v (slot-value first-back-style slot-name)))
        ;;            ;; (log-info "Slot ~S: Front=~S, Back=~S, Equal=~A, Type equal=~A"
        ;;            ;;           slot-name front-v back-v (equal front-v back-v)
        ;;            ;;           (eq (type-of front-v) (type-of back-v)))
        ;;            ))
        ))))

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
(defmacro as-utf-8-bytes (char writer)
  "Given the character CHAR, call the WRITER for every byte in the
  UTF-8 encoded form of that character. WRITER may a function or a
  macro."
  (let ((char-code (gensym)))
    `(let ((,char-code (char-code ,char)))
       (declare (type fixnum ,char-code))
       (cond ((< ,char-code 128) (,writer ,char-code))
             ;; ((< ,char-code 2048)
             ;;  (,writer (logior #b11000000 (ldb (byte 5 6) ,char-code)))
             ;;  (,writer (logior #b10000000 (ldb (byte 6 0) ,char-code))))
             ((< ,char-code 2048)
              (,writer (logior #b11000000 (ldb (byte 5 6) ,char-code)))
              (,writer (logior #b10000000 (ldb (byte 6 0) ,char-code))))
             ((< ,char-code 65536)
              (,writer (logior #b11100000 (ldb (byte 4 12) ,char-code)))
              (,writer (logior #b10000000 (ldb (byte 6 6) ,char-code)))
              (,writer (logior #b10000000 (ldb (byte 6 0) ,char-code))))
             (t
              (,writer (logior #b11110000 (ldb (byte 3 18) ,char-code)))
              (,writer (logior #b10000000 (ldb (byte 6 12) ,char-code)))
              (,writer (logior #b10000000 (ldb (byte 6 6) ,char-code)))
              (,writer (logior #b10000000 (ldb (byte 6 0) ,char-code))))))))
(defun write-output (output stream )
  "Write output to the terminal
This method should be implemented by subclasses of low-level-terminal."
  ;; (declare (ignore style))
  ;; ;; (with-lock (term)
  ;; (exec-sequence term :cursor-set-position y x)
  (dotimes (i (length output))
    (as-utf-8-bytes (char output i) (lambda (x) (write-byte x stream)))))

;; == elmtui/renderer/apply-diff.lisp ==
(defun apply-diff-to-backend (diff-ops backend-instance
                              terminal-offset-row terminal-offset-col)
  "Apply a list of diff operations (DIFF-OPS) to BACKEND-INSTANCE.
DIFF-OPS rows/cols are relative to the canvas origin.
TERMINAL-OFFSET-ROW/COL shift the canvas so its (0,0) lands on the terminal."
  (check-type backend-instance terminal-instance)
  (check-type diff-ops list)
  (check-type terminal-offset-row (integer 0 *))
  (check-type terminal-offset-col (integer 0 *))

  ;; Cursor/model state we keep between ops
  (let ((cursor-row -1)
        (cursor-col -1)
        (current-style (elmtui.platform.api:term-style backend-instance))
        (stream (terminal-instance-stream backend-instance))
        (last-row -1))

    ;; (log:debug "APPLY-DIFF: offset (~A,~A) initial-style=~S ops=~A"
    ;;            terminal-offset-row terminal-offset-col current-style (length diff-ops))

    (dolist (op diff-ops)
      (incf (rendering-stats-ops-processed *current-rendering-stats*))

      (ecase (getf op :type)
        (:write-chars
         ;; -------------------- pull fields --------------------
         (let* ((canvas-row        (getf op :row))
                (canvas-col        (getf op :start-col))
                (chars             (getf op :chars))
                (style             (getf op :style))
                ;; translate once – now we’re in terminal coords
                (term-row (+ canvas-row terminal-offset-row))
                (term-col (+ canvas-col terminal-offset-col)))

           ;; -------------------- row change => reset style ----
           (when (and (>= last-row 0) (/= term-row last-row))
             (log:debug "Row changed ~A→~A – force style reset" last-row term-row)
             (apply-style-diff backend-instance nil)
             (incf (rendering-stats-forced-style-resets *current-rendering-stats*))
             (setf current-style nil))

           ;; -------------------- style diff -------------------
           (unless (equal style current-style)
             (apply-style-diff backend-instance style)
             (incf (rendering-stats-style-changes-applied *current-rendering-stats*))
             (setf current-style style))

           ;; -------------------- cursor move ------------------
           (unless (and (= term-row cursor-row) (= term-col cursor-col))
             (send-sequence backend-instance :cursor-set-position
                            (1+ term-row) (1+ term-col))
             (incf (rendering-stats-cursor-moves-applied *current-rendering-stats*))
             (setf cursor-row term-row
                   cursor-col term-col))

           ;; -------------------- write ------------------------
           (write-output chars stream)
           (incf (rendering-stats-chars-written *current-rendering-stats*)
                 (length chars))
           (incf cursor-col (length chars))
           (setf last-row term-row)))))             ; end :write-chars

    ;; Leave terminal tidy
    (apply-style-diff backend-instance nil)
    (incf (rendering-stats-forced-style-resets *current-rendering-stats*))

    (log-info "RENDER STATS: ops=~A styles=~A moves=~A chars=~A resets=~A"
              (rendering-stats-ops-processed *current-rendering-stats*)
              (rendering-stats-style-changes-applied *current-rendering-stats*)
              (rendering-stats-cursor-moves-applied *current-rendering-stats*)
              (rendering-stats-chars-written *current-rendering-stats*)
              (rendering-stats-forced-style-resets *current-rendering-stats*))

    (finish-output stream)
    t))
;; == end/apply-diff.lisp ==
