(uiop:define-package :elmtui.render.diff
  (:use :cl)
  (:import-from :elmtui.view.geo #:=?)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
    #:virtual-terminal-buffer #:buffer-width #:buffer-height
    #:buffer-cell-at #:buffer-cell-char #:buffer-cell-style #:buffer-cell-equal-p)
  (:export #:compute-buffer-diff #:buffers-not-compatible-error
           #:buffers-not-compatible-error-front #:buffers-not-compatible-error-back
           #:buffers-not-compatible-error-reason
           #:diff-metrics #:diff-metrics-cells-compared
           #:diff-metrics-cells-changed #:diff-metrics-batches
           #:diff-metrics-full-redraws))
(in-package :elmtui.render.diff)

(define-condition buffers-not-compatible-error (elmtui.core.errors:elmtui-error)
  ((front-buffer :initarg :front-buffer :reader buffers-not-compatible-error-front)
   (back-buffer :initarg :back-buffer :reader buffers-not-compatible-error-back)
   (reason :initarg :reason :reader buffers-not-compatible-error-reason))
  (:report (lambda (condition stream)
             (format stream "Buffers are not compatible for diffing: ~A"
                     (buffers-not-compatible-error-reason condition)))))

(defstruct diff-metrics
  (cells-compared 0 :type fixnum)
  (cells-changed 0 :type fixnum)
  (batches 0 :type fixnum)
  (full-redraws 0 :type fixnum))

(defun %unpainted-cell-p (cell)
  "Background spaces with NIL style do not overwrite an unknown terminal."
  (let ((char (buffer-cell-char cell)))
    (and (null (buffer-cell-style cell))
         (or (char= char #\Space) (char= char #\Null)))))

(defun compute-buffer-diff (front back &key (initial-frame-p (null front)))
  "Compute (values operations metrics) without mutating either frame or globals.
INITIAL-FRAME-P is explicit: only styled/painted cells of BACK are emitted.
Incremental comparisons require compatible FRONT and BACK dimensions.
Operations carry zero-based frame coordinates and batched :WRITE-CHARS values."
  (check-type back virtual-terminal-buffer)
  (unless initial-frame-p
    (check-type front virtual-terminal-buffer)
    (unless (and (= (buffer-width front) (buffer-width back))
                 (= (buffer-height front) (buffer-height back)))
      (error 'buffers-not-compatible-error
             :front-buffer front :back-buffer back
             :reason "Buffer dimensions do not match.")))
  (let ((operations nil)
        (compared 0)
        (changed 0)
        (batches 0))
    (labels ((flush (batch)
               (when batch
                 (push batch operations)
                 (incf batches)))
             (new-batch (row col char style)
               (let ((chars (make-array 16 :element-type 'character
                                       :adjustable t :fill-pointer 0)))
                 (vector-push-extend char chars)
                 (list :type :write-chars :row row :start-col col
                       :chars chars :style style))))
      (loop for row below (buffer-height back) do
        (let ((batch nil))
          (loop for col below (buffer-width back) do
            (let* ((cell (buffer-cell-at back row col))
                   (paint-p (if initial-frame-p
                                (not (%unpainted-cell-p cell))
                                (not (buffer-cell-equal-p
                                      (buffer-cell-at front row col) cell)))))
              (incf compared)
              (if paint-p
                  (let ((char (buffer-cell-char cell))
                        (style (buffer-cell-style cell)))
                    (when (char= char #\Null) (setf char #\Space))
                    (incf changed)
                    (if (and batch
                             (=? style (getf batch :style))
                             (= col (+ (getf batch :start-col)
                                       (length (getf batch :chars)))))
                        (vector-push-extend char (getf batch :chars))
                        (progn
                          (flush batch)
                          (setf batch (new-batch row col char style)))))
                  (progn
                    (flush batch)
                    (setf batch nil)))))
          (flush batch))))
    (values (nreverse operations)
            (make-diff-metrics :cells-compared compared
                               :cells-changed changed :batches batches
                               :full-redraws (if initial-frame-p 1 0)))))
