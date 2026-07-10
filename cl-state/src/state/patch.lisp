;;; cl-state/src/state/patch.lisp
(in-package :cl-state.patch)

(defstruct patch path op value)
;; path: list designating a place in your state (e.g., (:components :main :count))
;; op  : :set | :update | :remove | :merge
;; value: depends on op

(defun %normalize-patch (p)
  (cond
    ((patch-p p) p)
    ((and (listp p)
          (= (length p) 2)
          (or (symbolp (first p)) (listp (first p))))
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

(defun %apply-patch-to-container (state patch)
  "Apply normalized PATCH to a raw hash-table/plist container."
  (let ((path (patch-path patch))
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
          (set-path state path (funcall fn cur)))))))

(defun %remove-from-application-state (state path)
  "Remove PATH while preserving the application-state log/observer contract."
  (bt:with-lock-held ((application-state-lock state))
    (let* ((data (application-state-data state))
           (old (get-path path data :not-present)))
      (multiple-value-bind (updated removedp) (remove-path data path)
        (when removedp
          (setf (application-state-data state) updated)
          (push (list path old :elmtui-delete-path)
                (application-state-log state))
          (incf (application-state-version state))
          (unless *transaction-active*
            (ignore-errors
              (cl-state.observer:notify-observers
               state path old :elmtui-delete-path))))
        (values state removedp)))))

(defun %apply-patch-to-application-state (state patch)
  "Apply PATCH through the application-state mutation/logging protocol."
  (let ((path (patch-path patch))
        (op (patch-op patch))
        (value (patch-value patch)))
    (ecase op
      (:set
       (state-set state path value))
      (:remove
       (%remove-from-application-state state path))
      (:merge
       (state-set state path
                  (append value (get-path path state nil))))
      (:update
       (state-set state path
                  (funcall value (get-path path state nil)))))
    state))

(defun apply-patch (state p)
  "Apply P to a raw container or APPLICATION-STATE."
  (let ((patch (%normalize-patch p)))
    (if (application-state-p state)
        (%apply-patch-to-application-state state patch)
        (%apply-patch-to-container state patch))))

(defun apply-patches (state patches)
  "Apply PATCHES in order.

For raw containers this is a direct reduction. For APPLICATION-STATE values,
the whole batch is one undoable transaction unless already inside one."
  (if (and (application-state-p state)
           (not *transaction-active*))
      (cl-state.tx:with-transaction (state :name :apply-patches)
        (reduce #'apply-patch patches :initial-value state))
      (reduce #'apply-patch patches :initial-value state)))

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
- Non-hash-table nested structures
- Order differences in list values"
  (let ((patches '()))
    ;; Detect changes and additions
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
    ;; Detect removed keys
    (when old
      (maphash (lambda (key old-val)
                 (declare (ignore old-val))
                 (let ((path (append prefix (list key))))
                   (unless (gethash key new)
                     (push (list path :removed) patches))))
               old))
    (nreverse patches)))
