(uiop:define-package :elmtui.tea-state.transactions
  (:use :cl #:log4cl)
  (:import-from :elmtui.tea-state.state
                #:state-set
                #:application-state
                #:application-state-p
                #:application-state-data
                #:application-state-lock
                #:application-state-log
                #:application-state-history
                #:application-state-undone
                #:application-state-observers
                #:state-ref
                #:tx
                #:make-tx
                #:tx-p
                #:tx-id
                #:tx-name
                #:tx-changes)
  (:import-from :alexandria #:when-let )
  (:export #:with-transaction
           #:application-state-p
           #:apply-patches
           #:undo
           #:redo
           #:state-set))

(in-package :elmtui.tea-state.transactions)

(defun alist-get (key alist &optional default)
  "Get value from ALIST by KEY, return DEFAULT if not found."
  (let ((pair (assoc key alist)))
    (if pair
        (cdr pair)
        default)))

;;;── Primitive Setter (always logs) ────────────────────────────
;; (defun state-set (app key new)
;;   "Atomically set KEY in APP, record old→new in the tx log."
;;   (sb-thread:with-mutex ((application-state-lock app))
;;     (let ((old (state-ref app key :not-present)))
;;       (setf (state-ref app key) new)
;;       (push (list key old new) (application-state-log app))
;;       new)))

;;;── Transaction Macro ────────────────────────────────────────
(defmacro with-transaction ((app &key name) &body body)
  "Wrap changes in a transaction named NAME.

  Arguments:
  - APP: The application state object.
  - NAME: A keyword or symbol to name the transaction.
  - BODY: The body of code that performs changes to the application state."
  `(let* ((app# ,app)
          (start-log-len# (length (application-state-log app#)))
          (successp nil))
     (unwind-protect
          (multiple-value-prog1
              (let ((result (progn ,@body))) ; user code calls state-set
                ;; commit
                (let* ((full-log (application-state-log app#))
                       (changes (subseq full-log 0 (- (length full-log) start-log-len#)))
                       (tx# (make-tx :id (gensym "TX-")
                                     :name ,name
                                     :changes (nreverse changes))))
                  ;; update histories
                  (push tx# (application-state-history app#))
                  (setf (application-state-undone app#) nil)
                  ;; notify observers
                  (dolist (chg (tx-changes tx#))
                    (let ((key (first chg))
                          (old (second chg))
                          (new (third chg)))
                      (dolist (fn (alist-get key (application-state-observers app#)))
                        (funcall fn old new)))))
                result) ;; Return the result of the body
            (setq successp t))
       ;; on error or unwind: rollback if not successful
       (let* ((full-log (application-state-log app#))
              (new-changes (subseq full-log 0 (- (length full-log) start-log-len#))))
         ;; Truncate the log back to its original state
         (setf (application-state-log app#) (subseq full-log (- (length full-log) start-log-len#)))
         ;; If the transaction did not succeed, revert the changes
         (unless successp
           (dolist (chg new-changes)
             (let ((key (first chg))
                   (old (second chg)))
               (sb-thread:with-mutex ((application-state-lock app#))
                 (if (eq old :not-present)
                     (remhash key (application-state-data app#))
                     (setf (gethash key (application-state-data app#)) old))))))))))


;;;── Patches & Undo/Redo ───────────────────────────────────────

(defun apply-patches (app patches)
  "Given patches = ((key new) …), do (state-set…) for each."
  (log-info "Applying patches: ~A" patches)
  (with-transaction (app :name :apply-patches)
    (dolist (p patches)
      (state-set app (first p) (second p)))
    t)

  ;; (log-info "PPPPPPPP~&~% ~A~%" (list
  ;;                                :app
  ;;                                (elmtui.state.api:pprinc-application-state
  ;;                                 app)
  ;;                                :patches patches))
  t)

(defun undo (app)
  "Undo last tx."
  (let ((tx (pop (application-state-history app))))
    (when tx
      (push tx (application-state-undone app))
      ;; revert in reverse
      (dolist (chg (reverse (tx-changes tx)))
        (sb-thread:with-mutex ((application-state-lock app))
          (let ((ht (application-state-data app)))
            (if (eq (second chg) :not-present)
                (remhash (first chg) ht)
                (setf (gethash (first chg) ht) (second chg))))))
      tx)))

(defun redo (app)
  "Redo last undone tx."
  (let ((tx (pop (application-state-undone app))))
    (when tx
      (push tx (application-state-history app))
      (dolist (chg (tx-changes tx))
        (sb-thread:with-mutex ((application-state-lock app))
          (setf (gethash (first chg) (application-state-data app))
                (third chg)))))
    tx))
