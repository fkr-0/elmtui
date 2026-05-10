;;; cl-state/src/state/tx.lisp
(in-package :cl-state.tx)

(defstruct tx
  id
  name
  changes)  ; list of (key old new)

(defun %alist-get (key alist &optional default)
  (let ((pair (assoc key alist)))
    (if pair
      (cdr pair)
      default)))

(defmacro with-transaction ((app &key name) &body body)
  "Wrap changes in a transaction named NAME."
  `(let* ((app# ,app)
           (start-log-len# (length (application-state-log app#)))
           (successp nil)
           (result-values# nil))
     (unwind-protect
       (multiple-value-prog1
         (progn
           (setf result-values# (multiple-value-list (progn ,@body)))
           (let* ((full-log (application-state-log app#))
                   (changes (subseq full-log 0 (- (length full-log) start-log-len#)))
                   (tx# (make-tx :id (gensym "TX-")
                          :name ,name
                          :changes (nreverse changes))))
             (push tx# (application-state-history app#))
             (setf (application-state-undone app#) nil)
             (dolist (chg (tx-changes tx#))
               (let ((key (first chg))
                      (old (second chg))
                      (new (third chg)))
                 (dolist (fn (%alist-get key (application-state-observers app#)))
                   (funcall fn old new))))
             (values-list result-values#)))
         (setq successp t))
       (let* ((full-log (application-state-log app#))
               (new-changes (subseq full-log 0 (- (length full-log) start-log-len#))))
         (setf (application-state-log app#)
           (subseq full-log (- (length full-log) start-log-len#)))
         (unless successp
           (dolist (chg new-changes)
             (let ((key (first chg))
                    (old (second chg)))
               (bt:with-lock-held ((application-state-lock app#))
                 (if (eq old :not-present)
                   (remhash key (application-state-data app#))
                   (setf (gethash key (application-state-data app#)) old))))))))))

(defun apply-patches (app patches)
  "Given patches = ((path value) ...), do (state-set ...) for each."
  (with-transaction (app :name :apply-patches)
    (dolist (p patches)
      (let ((path (first p))
             (value (second p)))
        (if (eq value :elmtui-delete-path)
          (bt:with-lock-held ((application-state-lock app))
            (let* ((data (application-state-data app))
                    (old (cl-state.utils:get-path path data :not-present)))
              (multiple-value-bind (data* _) (cl-state.utils:remove-path data path)
                (declare (ignore _))
                (setf (application-state-data app) data*)
                (push (list path old :elmtui-delete-path) (application-state-log app))
                (incf (application-state-version app)))))
          (state-set app path value))))
    t)
  t)

(defun undo (app)
  "Undo last tx."
  (let ((tx (pop (application-state-history app))))
    (when tx
      (push tx (application-state-undone app))
      (dolist (chg (reverse (tx-changes tx)))
        (bt:with-lock-held ((application-state-lock app))
          (let ((ht (application-state-data app)))
            (if (eq (second chg) :not-present)
              (remhash (first chg) ht)
              (setf (gethash (first chg) ht) (second chg)))))))
    tx))

(defun redo (app)
  "Redo last undone tx."
  (let ((tx (pop (application-state-undone app))))
    (when tx
      (push tx (application-state-history app))
      (dolist (chg (tx-changes tx))
        (bt:with-lock-held ((application-state-lock app))
          (setf (gethash (first chg) (application-state-data app))
            (third chg)))))
    tx))
