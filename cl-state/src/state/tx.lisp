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
  "Execute BODY as one atomic logical-state transaction on APP.

Same-state nesting joins the outer transaction rather than creating a savepoint.
Body failure rolls back logical values, version, log, history, and redo metadata
without observer callbacks. Successful commits notify changes in mutation order;
an observer failure is post-commit and never rolls the transaction back."
  `(let ((app# ,app))
     (assert-state-mutation-allowed app# :operation :transaction)
     (if (cl-state.core::transaction-active-p app#)
         (progn ,@body)
         (let* ((start-log-length# (length (application-state-log app#)))
                (start-version# (application-state-version app#))
                (start-history# (application-state-history app#))
                (start-undone# (application-state-undone app#))
                (committedp# nil)
                (result-values# nil)
                (ordered-changes# nil))
           (unwind-protect
                (progn
                  (let ((*transaction-active* t)
                        (cl-state.core::*transaction-states*
                          (cons app# cl-state.core::*transaction-states*)))
                    (setf result-values#
                          (multiple-value-list (progn ,@body))))
                  (let* ((newest-changes#
                           (%changes-since app# start-log-length#))
                         (changes# (nreverse (copy-list newest-changes#)))
                         (tx# (make-tx :id (gensym "TX-")
                                      :name ,name
                                      :changes changes#)))
                    (setf ordered-changes# changes#)
                    (push tx# (application-state-history app#))
                    (setf (application-state-undone app#) nil
                          committedp# t)))
             (if committedp#
                 (%discard-transaction-log app# start-log-length#)
                 (%restore-transaction-state
                  app# start-log-length# start-version#
                  start-history# start-undone#)))
           (%notify-transaction-changes app# ordered-changes#)
           (values-list result-values#)))))

(defun undo (app)
  "Undo last tx."
  (assert-state-mutation-allowed app :operation :undo)
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
  (assert-state-mutation-allowed app :operation :redo)
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

(defun %changes-since (app start-log-length)
  "Return changes logged after START-LOG-LENGTH, newest first."
  (let* ((log (application-state-log app))
         (count (- (length log) start-log-length)))
    (subseq log 0 count)))

(defun %restore-transaction-state
    (app start-log-length start-version start-history start-undone)
  "Roll APP back to the metadata and logical values captured at transaction entry."
  (let ((changes (%changes-since app start-log-length)))
    (bt:with-lock-held ((application-state-lock app))
      (dolist (change changes)
        (let ((path (first change))
              (old (second change)))
          (setf (application-state-data app)
                (if (eq old :not-present)
                    (cl-state.utils:remove-path (application-state-data app) path)
                    (cl-state.utils:set-path (application-state-data app) path old)))))
      (let* ((log (application-state-log app))
             (new-count (- (length log) start-log-length)))
        (setf (application-state-log app) (subseq log new-count)))
      (setf (application-state-version app) start-version
            (application-state-history app) start-history
            (application-state-undone app) start-undone))))

(defun %discard-transaction-log (app start-log-length) "Discard transaction-local log entries while preserving the prior log tail." (bt:with-lock-held ((application-state-lock app)) (let* ((log (application-state-log app)) (new-count (- (length log) start-log-length))) (setf (application-state-log app) (subseq log new-count)))))

(defun %notify-transaction-changes (app ordered-changes) "Notify committed transaction changes in mutation order." (dolist (change ordered-changes) (cl-state.observer:notify-observers app (first change) (second change) (third change) :phase :transaction-commit)))
