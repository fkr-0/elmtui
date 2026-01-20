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
  "Merge a single PATCH of the form (path value) into STATE.
Returns the modified STATE (functional API)."
  (destructuring-bind (path value) patch
    (if (eq value :elmtui-delete-path)
        (multiple-value-bind (state* _) (remove-path state path)
          (declare (ignore _))
          state*)
        (set-path state path value))))

(defun merge-patches (state patches)
  "Merge a list of PATCHES into STATE.
Returns the modified STATE (functional API)."
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

(defun diff-states (old new &key (prefix nil))
  "Return a list of patches representing differences between OLD and NEW states.

The function recursively compares hash-table states and returns patches
for paths where values differ. For nested structures, it generates patches
with the full path to the changed value.

Arguments:
+ OLD — The original state (hash-table)
+ NEW — The new state (hash-table)
+ PREFIX — Internal parameter for tracking path during recursion

Returns:
+ A list of patches in the form ((path value) ...) where path is a list
  of keys and value is the new value.

Note: This is a shallow comparison that doesn't handle:
- Removed keys (only detects changes and additions)
- Non-hash-table nested structures
- Order differences in list values"
  (let ((patches '()))
    (maphash (lambda (key new-val)
               (let* ((path (append prefix (list key)))
                      (old-val (gethash key old)))
                 (typecase new-val
                   (hash-table
                    ;; For nested hash-tables, recurse
                    (if (hash-table-p old-val)
                        (setq patches (append patches (diff-states old-val new-val :prefix path)))
                        ;; Old value is not a hash-table - this is a new nested structure
                        (push (list path new-val) patches)))
                   (t
                    ;; For non-hash-table values, check if changed
                    (unless (equal old-val new-val)
                      (push (list path new-val) patches))))))
             new)
    (nreverse patches)))
