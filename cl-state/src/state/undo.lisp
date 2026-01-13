;;; cl-state/src/state/undo.lisp
(in-package :cl-state.undo)

(defstruct history past future)

(defun push-snapshot (hist state)
  (push state (history-past hist))
  (setf (history-future hist) nil)
  hist)

(defun undo (hist current)
  (when (history-past hist)
    (let ((prev (pop (history-past hist))))
      (push current (history-future hist))
      prev)))

(defun redo (hist current)
  (when (history-future hist)
    (let ((next (pop (history-future hist))))
      (push current (history-past hist))
      next)))
