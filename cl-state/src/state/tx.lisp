;;; src/state/tx.lisp
(in-package :cl-state.tx)

(defstruct (tx-context (:constructor %make-tx-context))
  base-state patches committed?)
(defun make-tx-context (state) (%make-tx-context :base-state state :patches '()))

(defmacro with-transaction ((tx state) &body body)
  `(let ((,tx (make-tx-context ,state)))
     (unwind-protect
          (progn ,@body (tx-commit ,tx))
       (unless (tx-committed? ,tx) (tx-rollback ,tx)))))

(defun tx-commit (tx)
  (setf (tx-committed? tx) t)
  (values (cl-state.patch:apply-patches (tx-context-base-state tx) (tx-context-patches tx))
          (tx-context-patches tx)))

(defun tx-rollback (tx) (values (tx-context-base-state tx) nil))
