;;; src/state/observer.lisp
(in-package :cl-state.observer)
(defvar *observers* (make-hash-table :test 'eq))

(defun add-observer (key fn) (push fn (gethash key *observers*)) t)
(defun remove-observer (key fn)
  (setf (gethash key *observers*) (remove fn (gethash key *observers*))) t)

(defun notify-observers (key old new patches)
  (dolist (fn (gethash key *observers*)) (funcall fn old new patches)))