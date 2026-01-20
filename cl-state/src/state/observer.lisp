;;; cl-state/src/state/observer.lisp
(in-package :cl-state.observer)

(defun %alist-get (key alist &optional default)
  (let ((pair (assoc key alist)))
    (if pair
        (cdr pair)
        default)))

(defun add-observer (app key fn)
  "Adds an observer FN for KEY in application-state APP."
  (let* ((observers (application-state-observers app))
         (pair (assoc key observers)))
    (if pair
        ;; Key exists: add fn to existing observer list
        (setf (cdr pair) (cons fn (cdr pair)))
        ;; Key doesn't exist: create new entry
        (push (cons key (list fn)) (application-state-observers app)))
    fn))

(defun remove-observer (app key fn)
  "Removes observer FN for KEY in application-state APP. Returns T if FN was found and removed, NIL otherwise."
  (let* ((observers (application-state-observers app))
         (pair (assoc key observers)))
    (when (and pair (member fn (cdr pair)))
      (setf (cdr pair) (remove fn (cdr pair)))
      t)))

(defun notify-observers (app key old new)
  "Notify observers for KEY in application-state APP."
  (dolist (fn (%alist-get key (application-state-observers app)))
    (funcall fn old new)))
