(uiop:define-package :elmtui.tea-state.observers
  (:use :cl)
  (:import-from :elmtui.tea-state.state
                #:application-state
                #:application-state-observers)
  (:export #:add-observer
           #:remove-observer))

(in-package :elmtui.tea-state.observers)

(defun alist-get (key alist &optional default)
  "Get value from ALIST by KEY, return DEFAULT if not found."
  (let ((pair (assoc key alist)))
    (if pair
        (cdr pair)
        default)))

(defun add-observer (app key fn)
  "Adds an observer function FN for a given KEY in the application state APP."
  (let* ((observers (application-state-observers app))
         (key-obs (alist-get key observers)))
    (setf (application-state-observers app)
          (if key-obs
              ;; If the key already has observers, add the new function to the list.
              (cons (cons key (cons fn key-obs)) (remove (assoc key observers) observers))
              ;; Otherwise, create a new entry for the key with the function.
              (cons (cons key (list fn)) observers)))
    ;; If the key is new, we need to update the alist.
    (unless (assoc key observers)
      (push (cons key (list fn)) (application-state-observers app))))
  fn)

(defun remove-observer (app key fn)
  "Removes an observer function FN for a given KEY from the application state APP."
  (let* ((observers (application-state-observers app))
         (pair (assoc key observers)))
    (when pair
      (setf (cdr pair) (remove fn (cdr pair)))
      ;; If no observers remain for the key, we could remove the key from the alist,
      ;; but it's not strictly necessary.
      t)))
