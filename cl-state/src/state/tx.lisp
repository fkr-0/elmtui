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
         (let ((*transaction-active* t))
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
        (let ((rollback-notifications# nil))
          (bt:with-lock-held ((application-state-lock app#))
            (let* ((full-log (application-state-log app#))
                   (new-changes (subseq full-log 0 (- (length full-log) start-log-len#))))
              (setf (application-state-log app#)
                (subseq full-log 0 start-log-len#))
              (unless successp
                (dolist (chg new-changes)
                  (let ((key (first chg))
                         (old (second chg))
                         (new (third chg)))
                    (if (eq old :not-present)
                      (setf (application-state-data app#)
                        (cl-state.utils:remove-path (application-state-data app#) key))
                      (setf (application-state-data app#)
                        (cl-state.utils:set-path (application-state-data app#) key old)))
                    (push (list key new old) rollback-notifications#))))))
          (dolist (chg (nreverse rollback-notifications#))
            (cl-state.observer:notify-observers app# (first chg) (second chg) (third chg)))))))

(defun undo (app)
  "Undo last tx."
  (let ((tx (pop (application-state-history app))))
    (when tx
      (push tx (application-state-undone app))
      (dolist (chg (reverse (tx-changes tx)))
        (bt:with-lock-held ((application-state-lock app))
          (let ((key (first chg))
                 (old (second chg)))
            (if (eq old :not-present)
              (setf (application-state-data app)
                (cl-state.utils:remove-path (application-state-data app) key))
              (setf (application-state-data app)
                (cl-state.utils:set-path (application-state-data app) key old)))))))
    tx))

(defun redo (app)
  "Redo last undone tx."
  (let ((tx (pop (application-state-undone app))))
    (when tx
      (push tx (application-state-history app))
      (dolist (chg (tx-changes tx))
        (bt:with-lock-held ((application-state-lock app))
          (setf (application-state-data app)
                (if (eq (third chg) :elmtui-delete-path)
                    (cl-state.utils:remove-path
                     (application-state-data app) (first chg))
                    (cl-state.utils:set-path
                     (application-state-data app)
                     (first chg) (third chg)))))))
    tx))
