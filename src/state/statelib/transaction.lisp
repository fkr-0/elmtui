(uiop:define-package :uncharming-tui.state.transaction
  (:use :cl :log4cl :ut.state.state)
  (:import-from :ut.state.observe #:notify-observers) ; Import the real notify-observers
  (:nicknames :ut.state.transaction)
  (:export :transaction :transaction-id :transaction-changes
    :transaction-timestamp :make-transaction :record-change :apply-transaction
    :revert-transaction :with-transaction :undo-last-transaction
    :redo-last-transaction :clear-transaction-history
    ;; :notify-observers ; No longer exporting from here
    ))

(in-package :ut.state.transaction)

(defvar *transaction-counter* 0
  "A counter for generating unique transaction IDs.")

(defstruct transaction
  "Represents a single atomic transaction on the application state."
  (id (incf *transaction-counter*) :type integer)
  (changes (list) :type list) ; List of (key old-value new-value) tuples
  (timestamp (get-universal-time) :type integer))

(defmethod print-object ((tx transaction) stream)
  (print-unreadable-object (tx stream :type t :identity nil)
    (format stream "ID: ~A, Changes: ~A, Time: ~A"
      (transaction-id tx)
      (length (transaction-changes tx))
      (transaction-timestamp tx))))

(defun record-change (app-state key old-value new-value)
  "Records a change within the current transaction log of the application state.
   This should typically be called within a `with-transaction` block via `set-state!`."
  (log-debug "Recording change: Key=~S, Old=~S, New=~S" key old-value new-value)
  (push (list key old-value new-value)
    (application-state-transaction-log app-state)))

;; Removed the placeholder notify-observers function definition

(defun apply-transaction (app-state transaction)
  "Applies the changes recorded in a transaction to the application state.
   This is used for redoing transactions."
  (log-info "Applying transaction ID: ~A" (transaction-id transaction))
  (sb-thread:with-mutex ((application-state-lock app-state))
    (dolist (change (reverse (transaction-changes transaction))) ; Apply in original order
      (destructuring-bind (key old-value new-value) change
        (declare (ignore old-value))
        (log-debug "Applying change: Key=~S, New=~S" key new-value)
        ;; Use internal set-state to bypass logging within apply/revert
        (set-state app-state key new-value))))
  ;; Call the imported notify-observers
  (notify-observers app-state (transaction-changes transaction)))

(defun revert-transaction (app-state transaction)
  "Reverts the changes recorded in a transaction from the application state.
   This is used for undoing transactions."
  (log-info "Reverting transaction ID: ~A" (transaction-id transaction))
  (sb-thread:with-mutex ((application-state-lock app-state))
    (dolist (change (transaction-changes transaction)) ; Revert in reverse order of application
      (destructuring-bind (key old-value new-value) change
        (declare (ignore new-value))
        (log-debug "Reverting change: Key=~S, Old=~S" key old-value)
        ;; Use internal set-state to bypass logging within apply/revert
        (if (eq old-value :%not-present%) ; Check if the key was originally absent
          (remhash key (state-data-data (application-state-data app-state)))
          (set-state app-state key old-value)))))
  ;; Call the imported notify-observers
  (notify-observers app-state (transaction-changes transaction)))

(defmacro with-transaction ((app-state &key (label "Unnamed Transaction"))
                             &body body)
  "Executes BODY within a transaction context.

  Changes made to the APP-STATE using the `set-state!` macro (defined within
  `defupdate`) within this block will be recorded. If the block completes
  successfully, the transaction is committed to the history, and the undone
  history is cleared. If an error occurs, the transaction is discarded.

  NOTE: This macro does NOT automatically roll back state changes made by BODY
  if an error occurs. Rollback happens via the `undo-last-transaction` function.

  Args:
    app-state: The application-state instance.
    label: An optional label for the transaction (currently logged).
    body: The code to execute transactionally.

  Returns:
    The result of the last form in BODY."
  (let ((committed (gensym "COMMITTED"))
        (original-log (gensym "ORIGINAL-LOG"))
        (app-state-var (gensym "APP_STATE"))) ; Avoid capturing app-state symbol
    `(let* ((,app-state-var ,app-state)
            (,original-log (copy-list (application-state-transaction-log ,app-state-var)))
            (,committed nil))
       (unwind-protect
            (progn
              ;; Execute the body - assumes set-state! is used inside for changes
              (multiple-value-prog1
                  (progn ,@body)
                ;; If body completes without error, mark as committed
                (setf ,committed t)))
         ;; Cleanup phase (always runs)
         (if ,committed
             (let ((changes (nreverse (ldiff (application-state-transaction-log ,app-state-var)
                                               ,original-log))))
               (when changes
                 (let ((transaction (make-transaction :changes changes)))
                   (log-info "Committing transaction ID: ~A (~A) with ~D changes."
                     (transaction-id transaction) ,label (length changes))
                   ;; Push to main history
                   (push transaction (application-state-transaction-history ,app-state-var))
                   ;; Clear the redo stack upon new commit
                   (setf (application-state-undone-history ,app-state-var) nil)
                   ;; Clear the temporary log for this transaction
                   (setf (application-state-transaction-log ,app-state-var) ,original-log)
                   ;; Notify observers about the committed transaction changes
                   (notify-observers ,app-state-var changes)))) ; Call imported notify-observers
             ;; If not committed (error occurred), discard the changes from the log
             (progn
               (log-warn "Transaction (~A) aborted. Discarding changes." ,label)
               (setf (application-state-transaction-log ,app-state-var) ,original-log)
               ;; NOTE: Rollback is not automatic on error, must use undo explicitly.
               ))))))

(defun undo-last-transaction (app-state)
  "Reverts the most recent transaction from the history and moves it to the undone history.
   Returns the reverted transaction or NIL if history is empty."
  (let ((transaction-to-undo (pop (application-state-transaction-history app-state))))
    (when transaction-to-undo
      (log-info "Undoing transaction ID: ~A" (transaction-id transaction-to-undo))
      (revert-transaction app-state transaction-to-undo) ; This now calls notify-observers
      (push transaction-to-undo (application-state-undone-history app-state))
      transaction-to-undo)))

(defun redo-last-transaction (app-state)
  "Re-applies the most recently undone transaction and moves it back to the main history.
   Returns the redone transaction or NIL if undone history is empty."
  (let ((transaction-to-redo (pop (application-state-undone-history app-state))))
    (when transaction-to-redo
      (log-info "Redoing transaction ID: ~A" (transaction-id transaction-to-redo))
      (apply-transaction app-state transaction-to-redo) ; This now calls notify-observers
      (push transaction-to-redo (application-state-transaction-history app-state))
      transaction-to-redo)))

(defun clear-transaction-history (app-state)
  "Clears both the main transaction history (undo stack) and the undone history (redo stack)."
  (log-info "Clearing transaction history.")
  (setf (application-state-transaction-history app-state) nil)
  (setf (application-state-undone-history app-state) nil))
