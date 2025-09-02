;;; src/state/patch.lisp
(in-package :cl-state.patch)

(defstruct patch path op value)
;; path: list designating a place in your state (e.g., (:components :main :count))
;; op  : :set | :update | :remove | :merge (extend as needed)
;; value: depends on op

(defun plist-getf* (plist path)
  (if (endp path)
      plist
      (plist-getf* (getf plist (first path)) (rest path))))

(defun plist-setf* (plist path value)
  (if (endp path)
      value
      (let* ((key (first path))
             (rest-path (rest path))
             (sub (getf plist key)))
        (setf (getf plist key)
              (plist-setf* (if (consp sub) sub nil) rest-path value))
        plist)))

(defun plist-remf* (plist path)
  (cond
    ((endp path) plist)
    ((endp (rest path))
     (remf plist (first path))
     plist)
    (t
     (let* ((key (first path))
            (sub (getf plist key)))
       (when (consp sub)
         (setf (getf plist key) (plist-remf* sub (rest path))))
       plist))))

(defun apply-patch (state p)
  (ecase (patch-op p)
    (:set    (plist-setf* state (patch-path p) (patch-value p)))
    (:remove (plist-remf* state (patch-path p)))
    (:merge  (let* ((cur (plist-getf* state (patch-path p)))
                    (new (alexandria:alist-plist (patch-value p))))
               (plist-setf* state (patch-path p) (append new cur))))
    (:update (let* ((cur (plist-getf* state (patch-path p)))
                    (fn (patch-value p)))
               (plist-setf* state (patch-path p) (funcall fn cur)))))
  state)

(defun apply-patches (state patches)
  (reduce #'apply-patch patches :initial-value state))

(defun diff-states (old new)
  "Very naive: returns :set patches where values differ."
  (declare (ignore old new)) ; implement your keyed diff as needed
  '())


