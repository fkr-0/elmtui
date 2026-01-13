;;; cl-state/src/state/patch.lisp
(in-package :cl-state.patch)

(defstruct patch path op value)
;; path: list designating a place in your state (e.g., (:components :main :count))
;; op  : :set | :update | :remove | :merge
;; value: depends on op

(defun %normalize-patch (p)
  (cond
    ((patch-p p) p)
    ((and (listp p) (= (length p) 2) (listp (first p)))
     (make-patch :path (first p) :op :set :value (second p)))
    (t
     (error "Unsupported patch format: ~S" p))))

(defun normalize-patches (patches)
  (mapcar #'%normalize-patch patches))

(defun merge-patch (state patch)
  "Merge a single PATCH of the form (path value) into STATE."
  (destructuring-bind (path value) patch
    (if (eq value :elmtui-delete-path)
        (multiple-value-bind (state* _) (remove-path state path)
          (declare (ignore _))
          state*)
        (set-path state path value))))

(defun merge-patches (state patches)
  "Merge a list of PATCHES into STATE."
  (reduce #'merge-patch patches :initial-value state))

(defun apply-patch (state p)
  (let* ((patch (%normalize-patch p))
         (path (patch-path patch))
         (op (patch-op patch))
         (value (patch-value patch)))
    (ecase op
      (:set
       (set-path state path value))
      (:remove
       (multiple-value-bind (state* _) (remove-path state path)
         (declare (ignore _))
         state*))
      (:merge
       (let* ((cur (get-path path state nil))
              (new (append value cur)))
         (set-path state path new)))
      (:update
       (let* ((cur (get-path path state nil))
              (fn value))
         (set-path state path (funcall fn cur))))))
  state)

(defun apply-patches (state patches)
  (reduce #'apply-patch patches :initial-value state))

(defun diff-states (old new)
  "Very naive: returns :set patches where values differ."
  (declare (ignore old new))
  '())
