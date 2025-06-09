(uiop:define-package :elmtui.state.transactions
  (:use :cl)
  (:import-from :elmtui.statelib.state ; For application-state structure if needed
   :application-state ;; Assuming this is the type from statelib
                :state-data-data   ;; Accessor for the raw data within app-state
                )
  (:import-from :elmtui.statelib.transaction
                ;; If we are wrapping statelib.transaction, import its symbols.
                ;; If this *IS* the primary transaction implementation for the API,
                ;; then these are defined here and exported via elmtui.state.api.
                ;; Let's assume elmtui.statelib.transaction provides the base,
                ;; and this file might extend or specialize it.
                ;; For the current request, this file seems to *be* the transaction system.
                )
  (:export ;; Symbols defined *in this file* that are part of the public API
   ;; These are already exported by elmtui.state.api, but good practice to list them here.
   :with-transaction
   :begin-transaction :commit-transaction :rollback-transaction
   :in-transaction-p
   ;; :set-slot ; This is a low-level utility, consider if it should be part of the main API.
   ;;           ; For now, keeping it internal to this system or used by defupdate.
   :undo-last-transaction :redo-last-transaction :clear-transaction-history
   ;; Change listeners might be internal or a more advanced API feature
   ;; :register-change-listener :unregister-change-listener
   ))
(in-package :elmtui.state.transactions)

;; This implementation seems to be a standalone transaction system, not directly
;; using elmtui.statelib.transaction's `with-transaction` but defining its own.
;; It should operate on the `application-state` object defined in `elmtui.statelib.state`.

;; Transaction State Management
(defvar *current-transaction* nil
  "Current active transaction. Should hold an `elmtui.statelib.transaction:transaction` object if integrated.")
(defvar *transaction-history* nil
  "List of committed transactions (application-state snapshots or diffs).")
(defvar *undone-history* nil
  "List of undone transactions for redo.")

;; For this example, we'll assume transactions store snapshots of the app-state's data plist.
;; A more advanced system would store diffs/patches.

(defstruct transaction-record
  (id (gensym "TX-") :read-only t)
  (name nil :type (or null symbol))
  (timestamp (get-universal-time) :read-only t)
  (previous-state-data nil) ; The state *before* this transaction
  (next-state-data nil)     ; The state *after* this transaction (after commit)
  )

(defun begin-transaction (app-state &key name)
  "Starts a new transaction for the given APP-STATE.
   Records the current state data for potential rollback.
   Returns a transaction context (could be the app-state itself or a marker)."
  (when *current-transaction*
    (warn "Starting nested transaction ~:[~;~:*named '~A' ~]within active transaction ~A."
          name (transaction-record-id *current-transaction*)))
  (setf *current-transaction*
        (make-transaction-record :name name
                                 :previous-state-data (copy-tree (elmtui.statelib.state:state-data-data app-state))))
  app-state) ; Return app-state as context

(defun commit-transaction (app-state)
  "Commits the current transaction for APP-STATE.
   Stores the transaction in history."
  (unless *current-transaction*
    (error "No active transaction to commit for app-state."))
  (unless (eq (elmtui.statelib.state:state-data-data app-state)
              (transaction-record-previous-state-data *current-transaction*))
    ;; State has changed, finalize the record
    (setf (transaction-record-next-state-data *current-transaction*)
          (copy-tree (elmtui.statelib.state:state-data-data app-state)))

    (push *current-transaction* *transaction-history*)
    (setf *undone-history* nil) ; Clear redo stack on new commit
    (setf *current-transaction* nil)
    t) ; Indicate success
  (progn
    ;; No changes were made during the transaction
    (setf *current-transaction* nil)
    nil)) ; Indicate no changes committed

(defun rollback-transaction (app-state)
  "Rolls back the current transaction for APP-STATE.
   Restores the state data from before the transaction started."
  (unless *current-transaction*
    (error "No active transaction to rollback for app-state."))
  (setf (elmtui.statelib.state:state-data-data app-state)
        (transaction-record-previous-state-data *current-transaction*))
  (let ((rolled-back-tx *current-transaction*))
    (setf *current-transaction* nil)
    rolled-back-tx)) ; Return the rolled-back transaction record

(defun in-transaction-p ()
  "Checks if there's an active transaction."
  (not (null *current-transaction*)))

(defun symbolicate (prefix sym)
  "Generates a symbol with PREFIX and SYM, ensuring uniqueness."
  (intern (format nil "~A~A" prefix (symbol-name sym)) *package*))
(defmacro with-transaction ((app-state-var &key name) &body body)
  "Executes BODY within a transaction on APP-STATE-VAR.
   APP-STATE-VAR must be bound to an `application-state` object.
   If BODY completes successfully, the transaction is committed.
   If an error occurs or an explicit rollback is called, changes are reverted."
  (let ((tx-name (or name (symbolicate "TX-" (gensym)))))
    `(let ((*current-transaction* nil)) ; Ensure it's fresh for this scope if not already managed globally per thread
       (begin-transaction ,app-state-var :name ',tx-name)
       (unwind-protect
            (multiple-value-prog1
                (progn ,@body)
              (commit-transaction ,app-state-var))
         (when *current-transaction* ; If commit didn't clear it (e.g., error before commit)
           (rollback-transaction ,app-state-var))))))

(defun undo-last-transaction (app-state)
  "Undoes the last committed transaction on APP-STATE.
   Returns the undone transaction record or NIL if history is empty."
  (when *transaction-history*
    (let ((last-tx (pop *transaction-history*)))
      (setf (elmtui.statelib.state:state-data-data app-state)
            (transaction-record-previous-state-data last-tx))
      (push last-tx *undone-history*)
      last-tx)))

(defun redo-last-transaction (app-state)
  "Redoes the last undone transaction on APP-STATE.
   Returns the redone transaction record or NIL if undone history is empty."
  (when *undone-history*
    (let ((tx-to-redo (pop *undone-history*)))
      (setf (elmtui.statelib.state:state-data-data app-state)
            (transaction-record-next-state-data tx-to-redo))
      (push tx-to-redo *transaction-history*)
      tx-to-redo)))

(defun clear-transaction-history ()
  "Clears both transaction history and undone history."
  (setf *transaction-history* nil
        *undone-history* nil)
  t)

;; The `set-slot` and listener mechanisms from the original file are not directly
;; compatible with this snapshot-based transaction model without significant adaptation.
;; `set-slot` would need to be used by `defupdate` *before* `merge-patches` if it were
;; to record fine-grained changes. However, `defupdate` is now expected to return patches.
;; For TEA, direct slot setting outside of the update->patch->merge cycle is discouraged.
;; If `set-slot` is needed, it should be part of how `merge-patches` applies changes,
;; or `defupdate` itself would use it to build the patch list.
;; Given the current direction, `set-slot` as a public API for direct mutation seems
;; contrary to the TEA model being built.
