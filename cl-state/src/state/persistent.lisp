(in-package :cl-state.patch)

(defun %shared-copy-hash-table (table) (let ((copy (make-hash-table :test (hash-table-test table) :size (hash-table-size table) :rehash-size (hash-table-rehash-size table) :rehash-threshold (hash-table-rehash-threshold table)))) (maphash (lambda (key value) (setf (gethash key copy) value)) table) copy))

(defun %shared-set-entry (container key value) (when (null key) (error "SHARED-SET-ENTRY: KEY cannot be NIL")) (cond ((hash-table-p container) (let ((copy (%shared-copy-hash-table container))) (setf (gethash key copy) value) copy)) ((null container) (list key value)) ((listp container) (if (cl-state.utils::%alist-p container) (let ((foundp nil)) (let ((copy (mapcar (lambda (pair) (if (eq key (car pair)) (progn (setf foundp t) (cons key value)) (cons (car pair) (cdr pair)))) container))) (if foundp copy (append copy (list (cons key value)))))) (let ((copy (copy-list container))) (setf (getf copy key) value) copy))) (t (error "SHARED-SET-ENTRY: unsupported container type ~S" (type-of container)))))

(defun %shared-remove-entry (container key) (cond ((hash-table-p container) (multiple-value-bind (_value foundp) (gethash key container) (declare (ignore _value)) (if foundp (let ((copy (%shared-copy-hash-table container))) (remhash key copy) (values copy t)) (values container nil)))) ((listp container) (if (cl-state.utils::%alist-p container) (if (assoc key container :test #'eq) (values (remove key container :key #'car :test #'eq :count 1) t) (values container nil)) (let ((marker (gensym "MISSING-"))) (if (eq (getf container key marker) marker) (values container nil) (values (loop for (item-key item-value) on container by #'cddr unless (eq item-key key) append (list item-key item-value)) t))))) (t (values container nil))))

(defun %shared-empty-container-p (value) (typecase value (null t) (hash-table (zerop (hash-table-count value))) (list (null value)) (t nil)))

(defun %set-path-shared (data path value &key (createp t)) (etypecase path (symbol (%shared-set-entry data path value)) (list (if (= 1 (length path)) (%shared-set-entry data (car path) value) (let* ((key (car path)) (rest (cdr path)) (child (get-path key data nil))) (when (and (null child) (not createp)) (error "Missing node ~S in path ~S and :CREATEP is NIL" key path)) (let* ((child* (or child (if (hash-table-p data) (make-hash-table :test 'equal) nil))) (new-child (%set-path-shared child* rest value :createp createp))) (%shared-set-entry data key new-child))))) (t (error "SET-PATH-SHARED: invalid PATH ~S" path))))

(defun %remove-path-shared (data path &key (prune-empty t)) (etypecase path (symbol (%shared-remove-entry data path)) (list (if (null (cdr path)) (%shared-remove-entry data (car path)) (let* ((key (car path)) (rest (cdr path)) (child (get-path key data nil))) (if (null child) (values data nil) (multiple-value-bind (new-child removedp) (%remove-path-shared child rest :prune-empty prune-empty) (if (not removedp) (values data nil) (let ((child-empty (%shared-empty-container-p new-child))) (cond ((and prune-empty child-empty) (%shared-remove-entry data key)) (child-empty (values (%shared-set-entry data key (typecase child (hash-table (make-hash-table :test 'equal)) (t nil))) t)) (t (values (%shared-set-entry data key new-child) t)))))))))) (t (values data nil))))

(defun %apply-patch-shared-data (data patch)
  (let* ((path (patch-path patch))
         (op (patch-op patch))
         (value (patch-value patch))
         (old (get-path path data :not-present)))
    (ecase op
      (:set
       (let ((stored (freeze-state-value value)))
         (values (%set-path-shared data path stored)
                 (list path (copy-state-value old) (copy-state-value stored))
                 t)))
      (:remove
       (multiple-value-bind (next removedp)
           (%remove-path-shared data path)
         (values next
                 (and removedp
                      (list path (copy-state-value old) :elmtui-delete-path))
                 removedp)))
      (:merge
       (let* ((current (get-path path data nil))
              (candidate (append (copy-state-value value)
                                 (copy-state-value current)))
              (stored (freeze-state-value candidate)))
         (values (%set-path-shared data path stored)
                 (list path (copy-state-value old) (copy-state-value stored))
                 t)))
      (:update
       (let* ((current (get-path path data nil))
              (candidate (funcall value (copy-state-value current)))
              (stored (freeze-state-value candidate)))
         (values (%set-path-shared data path stored)
                 (list path (copy-state-value old) (copy-state-value stored))
                 t))))))

(defun %notify-shared-commit-observers (state changes)
  "Notify observers for a completed persistent commit in mutation order."
  (dolist (change changes)
    (cl-state.observer:notify-observers
     state (first change) (second change) (third change)
     :phase :persistent-commit)))

(defun apply-patches-shared (state patches &key (name :apply-patches-shared))
  "Apply PATCHES with persistent path copying and structural sharing.

For APPLICATION-STATE, the source state is never mutated. Containers on changed
paths are copied while untouched branches are shared. Values crossing a strict
ownership boundary pass through FREEZE-STATE-VALUE; history metadata receives
independent COPY-STATE-VALUE copies. Custom mutable leaves can therefore provide
state-specific copy/freeze semantics without changing the patch engine.

The returned APPLICATION-STATE is frozen. Observer registrations are runtime
metadata: the registry is copied from the source at commit time, but remains
independently mutable on each snapshot. APPLY-PATCHES-PERSISTENT remains the
eager full-copy oracle used for differential tests."
  (if (application-state-p state)
      (let ((data (application-state-data state))
            (log (copy-list (application-state-log state)))
            (version (application-state-version state))
            (changes nil))
        (dolist (item patches)
          (let ((patch (%normalize-patch item)))
            (multiple-value-bind (next-data change changedp)
                (%apply-patch-shared-data data patch)
              (setf data next-data)
              (when changedp
                (push change log)
                (push change changes)
                (incf version)))))
        (let* ((ordered-changes (nreverse changes))
               (transaction (cl-state.tx:make-tx
                             :id (gensym "TX-")
                             :name name
                             :changes ordered-changes))
               (next (make-application-state
                      :data data
                      :backend (application-state-backend state)
                      :lock (bt:make-lock "cl-state.lock")
                      :log log
                      :history (cons transaction
                                     (copy-list (application-state-history state)))
                      :undone nil
                      :version version
                      :observers (copy-state-value
                                  (application-state-observers state))
                      :frozen-p t)))
          (%notify-shared-commit-observers next ordered-changes)
          next))
      (let ((data state))
        (dolist (item patches data)
          (multiple-value-bind (next-data _change _changedp)
              (%apply-patch-shared-data data (%normalize-patch item))
            (declare (ignore _change _changedp))
            (setf data next-data))))))
