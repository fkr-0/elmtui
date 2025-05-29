(uiop:define-package :elmtui.statelib.transaction
  (:use :cl :log4cl :ut.state.state)
  (:import-from :elmtui.statelib.observe #:notify-observers) ; Import the real notify-observers
  (:nicknames :ut.state.transaction)
  (:export :transaction :transaction-id :transaction-changes
   :transaction-timestamp :transaction-name :transaction-description
           :make-transaction :record-change :apply-transaction
   :revert-transaction :with-transaction :undo-last-transaction
           :redo-last-transaction :clear-transaction-history
           :selective-undo ; Added
           ;; Transaction history utilities
           :print-transaction-history :format-transaction-summary
           :export-transaction-history
           :visualize-transaction-history ; Added
           ;; :notify-observers ; No longer exporting from here
           ))

(in-package :ut.state.transaction)

(defvar *transaction-counter* 0
  "A counter for generating unique transaction IDs.")

(defstruct transaction
  "Represents a single atomic transaction on the application state."
  (id (incf *transaction-counter*) :type integer)
  (changes (list) :type list) ; List of (key old-value new-value) tuples
  (timestamp (get-universal-time) :type integer)
  (name nil :type (or null symbol string)) ; Optional name for the transaction
  (description nil :type (or null string))) ; Optional longer description

(defmethod print-object ((tx transaction) stream)
  (print-unreadable-object (tx stream :type t :identity nil)
    (format stream "ID: ~A~@[, Name: ~A~], Changes: ~A, Time: ~A"
            (transaction-id tx)
            (transaction-name tx)  
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

;;;  Replace the existing WITH-TRANSACTION macro with the one below
(defmacro with-transaction ((app-state &key 
                                         (label "Unnamed Transaction")
                                         name
                                         description)
                            &body body)
  "Execute BODY, then bundle all state changes into *one* transaction.
If BODY unwinds with an error, the changes are discarded (no commit).
Actual data rollback is still done later by `undo-last-transaction`.

Args:
  app-state: The application-state instance.
  label: A simple string label for logging (primarily for backward compatibility).
  name: A symbol or string identifying this transaction (for undo/redo labeling).
  description: A more detailed description of what this transaction does.

Example:
  (with-transaction (app-state 
                    :name 'increment-counter
                    :description \"Increment counter value by 1\")
    (setf (state-ref app-state :counter) (1+ (state-ref app-state :counter))))"
  (let ((state-var    (gensym "APP_STATE"))
        (start-len    (gensym "START_LEN"))
        (committed    (gensym "COMMITTED"))
        (saved-log    (gensym "SAVED_LOG")))
    `(let* ((,state-var ,app-state)
            (,start-len (length (application-state-transaction-log ,state-var)))
            (,saved-log (copy-list (application-state-transaction-log ,state-var)))
            (,committed nil))
       (unwind-protect
            ;; run BODY – mark success afterwards
            (multiple-value-prog1
                (progn ,@body)
              (setf ,committed t))
         ;; ─────────── cleanup ───────────
         (if ,committed
             (let* ((curr-log (application-state-transaction-log ,state-var))
                    (delta-len (- (length curr-log) ,start-len))
                    (tail      (nthcdr ,start-len curr-log))
                    (changes   (when (> delta-len 0) (nreverse tail))))
               (when changes
                 (let ((tx (make-transaction 
                            :changes changes
                            :name ,name
                            :description ,description)))
                   (log:info "Committing transaction ~A~@[ (~A)~]~@[ \"~A\"~]: ~D change~:P."
                             (transaction-id tx)
                             (transaction-name tx)
                             (transaction-description tx)
                             (length changes))
                   (push tx (application-state-transaction-history ,state-var))
                   (setf (application-state-undone-history ,state-var) nil)
                   ;; reset temp log
                   (setf (application-state-transaction-log ,state-var)
                         ,saved-log)
                   ;; notify observers
                   (notify-observers ,state-var changes))))
             ;; error path – revert temp log
             (progn
               (log:warn "Transaction (~A) aborted; discarding changes."
                         ,label)
               (setf (application-state-transaction-log ,state-var)
                     ,saved-log)))))))

(defun undo-last-transaction (app-state)
  "Undo the last transaction in the application state.
   This function reverts the last committed transaction and applies its changes
   in reverse order. The transaction is then pushed to the undone history for
   potential redo.

   Args:
     app-state: The application state instance.

   Returns:
     The reverted transaction, or NIL if no transactions are available."
  (check-type app-state application-state)
  (let ((history (application-state-transaction-history app-state)))
    (if (null history)
        (progn
          (log-warn "No transactions to undo.")
          nil)
        (let ((transaction (pop history)))
          (log-info "Undoing transaction ID: ~A" (transaction-id transaction))
          ;; Revert the changes
          (revert-transaction app-state transaction)
          ;; Push to undone history for potential redo
          (push transaction (application-state-undone-history app-state))
          ;; Notify observers about the undone changes
          (notify-observers app-state (transaction-changes transaction))
          transaction))))

(defun redo-last-transaction (app-state)
  "Redo the last undone transaction in the application state.
   This function reapplies the last undone transaction and pushes it back to
   the main transaction history.

   Args:
     app-state: The application state instance.

   Returns:
     The redone transaction, or NIL if no transactions are available."
  (check-type app-state application-state)
  (let ((undone-history (application-state-undone-history app-state)))
    (if (null undone-history)
        (progn
          (log-warn "No transactions to redo.")
          nil)
        (let ((transaction (pop undone-history)))
          (log-info "Redoing transaction ID: ~A" (transaction-id transaction))
          ;; Apply the changes
          (apply-transaction app-state transaction)
          ;; Push back to main history
          (push transaction (application-state-transaction-history app-state))
          ;; Notify observers about the redone changes
          (notify-observers app-state (transaction-changes transaction))
          transaction))))

(defun get-transaction-history (app-state)
  "Returns the list of committed transactions."
  (application-state-transaction-history app-state))

(defun move-transaction-to-redo (app-state transaction)
  "Moves a specific transaction from the main history to the undone history.
   The transaction is removed from its current position in the main history
   and pushed onto the head of the undone-history stack."
  (setf (application-state-transaction-history app-state)
        (delete transaction (application-state-transaction-history app-state) :count 1))
  (push transaction (application-state-undone-history app-state)))

(defun selective-undo (app-state transaction-id)
  "Undo a specific transaction by ID.
   The transaction is reverted, moved from the main history to the undone history,
   and observers are notified.
   Returns the reverted transaction, or NIL if not found."
  (check-type app-state application-state)
  (let* ((history (get-transaction-history app-state))
         (tx (find transaction-id history :key #'transaction-id)))
    (if tx
        (progn
          (log-info "Selectively undoing transaction ID: ~A" (transaction-id tx))
          (revert-transaction app-state tx)
          (move-transaction-to-redo app-state tx)
          (notify-observers app-state (transaction-changes tx))
          tx)
        (progn
          (log-warn "Selective undo: Transaction ID ~A not found in history." transaction-id)
          nil))))

;; (defmacro with-transaction ((app-state &key (label "Unnamed Transaction"))
;;                              &body body)
;;   "Executes BODY within a transaction context.

;;   Changes made to the APP-STATE using the `set-state!` macro (defined within
;;   `defupdate`) within this block will be recorded. If the block completes
;;   successfully, the transaction is committed to the history, and the undone
;;   history is cleared. If an error occurs, the transaction is discarded.

;;   NOTE: This macro does NOT automatically roll back state changes made by BODY
;;   if an error occurs. Rollback happens via the `undo-last-transaction` function.

;;   Args:
;;     app-state: The application-state instance.
;;     label: An optional label for the transaction (currently logged).
;;     body: The code to execute transactionally.

;;   Returns:
;;     The result of the last form in BODY."
;;   (let ((committed (gensym "COMMITTED"))
;;         (original-log (gensym "ORIGINAL-LOG"))
;;         (app-state-var (gensym "APP_STATE"))) ; Avoid capturing app-state symbol
;;     `(let* ((,app-state-var ,app-state)
;;             (,original-log (copy-list (application-state-transaction-log ,app-state-var)))
;;             (,committed nil))
;;        (unwind-protect
;;             (progn
;;               ;; Execute the body - assumes set-state! is used inside for changes
;;               (multiple-value-prog1
;;                   (progn ,@body)
;;                 ;; If body completes without error, mark as committed
;;                 (setf ,committed t)))
;;          ;; Cleanup phase (always runs)
;;          (if ,committed
;;              (let ((changes (nreverse (ldiff (application-state-transaction-log ,app-state-var)
;;                                                ,original-log))))
;;                (when changes
;;                  (let ((transaction (make-transaction :changes changes)))
;;                    (log-info "Committing transaction ID: ~A (~A) with ~D changes."
;;                      (transaction-id transaction) ,label (length changes))
;;                    ;; Push to main history
;;                    (push transaction (application-state-transaction-history ,app-state-var))
;;                    ;; Clear the redo stack upon new commit
;;                    (setf (application-state-undone-history ,app-state-var) nil)
;;                    ;; Clear the temporary log for this transaction
;;                    (setf (application-state-transaction-log ,app-state-var) ,original-log)
;;                    ;; Notify observers about the committed transaction changes
;;                    (notify-observers ,app-state-var changes)))) ; Call imported notify-observers
;;              ;; If not committed (error occurred), discard the changes from the log
;;              (progn
;;                (log-warn "Transaction (~A) aborted. Discarding changes." ,label)
;;                (setf (application-state-transaction-log ,app-state-var) ,original-log)
;;                ;; NOTE: Rollback is not automatic on error, must use undo explicitly.
;;                ))))))

(defun format-universal-time (time)
  "Formats a universal time into a human-readable string."
  (multiple-value-bind (second minute hour day month year zone)
      (decode-universal-time time)
    (declare (ignorable zone))
    (format nil "~A-~2,'0D-~2,'0D ~2,'0D:~2,'0D:~2,'0D" year month day hour minute second)))

(defun print-transaction-history (app-state &key (stream *standard-output*) (max-changes 5))
  "Print the transaction history of an application state in a formatted way.
   
   Args:
     app-state: The application state instance
     stream: Output stream to print to (default: *standard-output*)
     max-changes: Maximum number of changes to show per transaction (default: 5)
     
   Returns:
     The number of transactions in history"
  (check-type app-state application-state)
  (let ((history (application-state-transaction-history app-state)))
    (format stream "~&Transaction History (~D transaction~:P):~%" (length history))
    (loop for tx in history
          for i from 1
          do (let ((changes-count (length (transaction-changes tx))))
               (format stream "~&~D. Transaction #~D~@[ '~A'~]~@[ - ~A~]~@[ Cats: ~{~S~^,~}~] (~D change~:P)~%   Time: ~A~%"
                       i
                       (transaction-id tx)
                       (transaction-name tx)
                       (transaction-description tx)
                       (transaction-categories tx)
                       changes-count
                       (format-universal-time (transaction-timestamp tx)))
               (when (> changes-count 0)
                 (format stream "   Changes:~%")
                 (loop for change in (subseq (transaction-changes tx) 0 (min max-changes changes-count))
                       do (destructuring-bind (key old-value new-value) change
                            (format stream "     - ~S: ~S => ~S~%" key old-value new-value)))
                 (when (> changes-count max-changes)
                   (format stream "     ...~D more change~:P...~%" (- changes-count max-changes))))))
    (length history)))

(defun visualize-transaction-history (app-state &optional output-file)
  "Generate a visualization of the transaction history."
  (check-type app-state application-state)
  (let ((history (get-transaction-history app-state))
        (stream (if output-file
                    (open output-file :direction :output :if-exists :supersede)
                    *standard-output*)))
    (format stream "~&Transaction History Visualization (~D transaction~:P):~%" (length history))
    (format stream "~&----------------------------------------------------------~%")
    (loop for tx in history
          for i from 1
          do (format stream "~&~3D: [~A] ~A~@[ Cats: ~{~S~^,~}~]~%"
                    i
                    (format-universal-time (transaction-timestamp tx))
                    (or (transaction-name tx) "Unnamed transaction")
                    (transaction-categories tx))
             (format stream "     Changes: ~A~%" (length (transaction-changes tx)))
             (format stream "     ID: ~A~%~%" (transaction-id tx)))
    (when output-file (close stream))
    (length history)))

(defun format-transaction-summary (transaction)
  "Returns a one-line summary string for a transaction."
  (with-output-to-string (s)
    (format s "Transaction #~D" (transaction-id transaction))
    (when (transaction-name transaction)
      (format s " '~A'" (transaction-name transaction)))
    (when (transaction-categories transaction)
      (format s " [~{~S~^,~}]" (transaction-categories transaction)))
    (format s " - ~D change~:P" (length (transaction-changes transaction)))
    (when (transaction-description transaction)
      (format s " (~A)" (transaction-description transaction)))))

(defun escape-html (text)
  "Basic HTML escaping for text content."
  (if (stringp text)
      (cl-ppcre:regex-replace-all "&"
       (cl-ppcre:regex-replace-all "<"
        (cl-ppcre:regex-replace-all ">" text ">")
        "<")
       "&")
      (princ-to-string text)))

(defun export-transaction-history (app-state &key (stream *standard-output*) (format :text) (include-changes nil))
  "Export the transaction history in various formats."
  (check-type app-state application-state)
  (check-type format (member :text :json :s-exp :html)) ; Added :html
  (let ((history (application-state-transaction-history app-state)))
    (case format
      (:text (print-transaction-history app-state :stream stream))
      (:html
       (format stream "<!DOCTYPE html>~%<html><head><title>Transaction History</title>")
       (format stream "<style>body {font-family: sans-serif;} table {border-collapse: collapse; width: 90%; margin: 20px auto;} th, td {border: 1px solid #ccc; padding: 8px; text-align: left;} tr:nth-child(even){background-color: #f2f2f2;} th {background-color: #4CAF50; color: white;} pre {white-space: pre-wrap; word-wrap: break-word;}</style>")
       (format stream "</head><body>~%<h2>Transaction History (~D)</h2>~%" (length history))
       (format stream "<table><thead><tr><th>ID</th><th>Timestamp</th><th>Name</th><th>Description</th><th>Categories</th><th>Changes Count</th>~@[<th>Details</th>~]</tr></thead><tbody>~%"
               (if include-changes "<th>Details</th>" ""))
       (loop for tx in history
             do (format stream "<tr><td>~D</td><td>~A</td><td>~A</td><td>~A</td><td>~{~S~^, ~}</td><td>~D</td>~@[<td><pre>~{~A~%~}</pre></td>~]</tr>~%"
                        (transaction-id tx)
                        (format-universal-time (transaction-timestamp tx))
                        (escape-html (or (transaction-name tx) ""))
                        (escape-html (or (transaction-description tx) ""))
                        (transaction-categories tx)
                        (length (transaction-changes tx))
                        (when include-changes
                          (mapcar (lambda (ch) (escape-html (format nil "~S: ~S => ~S" (first ch) (second ch) (third ch))))
                                  (transaction-changes tx)))))
       (format stream "</tbody></table></body></html>~%"))
      (:json
       (format stream "{\"transactions\": [~{~A~^, ~}]}~%"
               (loop for tx in history
                     collect (with-output-to-string (s)
                               (format s "{\"id\": ~D, \"name\": ~S, \"description\": ~S, \"timestamp\": ~D, \"categories\": ~S, \"changes_count\": ~D~@[, \"changes\": ~A~]}"
                                       (transaction-id tx)
                                       (transaction-name tx)
                                       (transaction-description tx)
                                       (transaction-timestamp tx)
                                       (transaction-categories tx)
                                       (length (transaction-changes tx))
                                       (when include-changes
                                         (format nil "[~{~A~^, ~}]"
                                                 (mapcar (lambda (ch)
                                                           (format nil "{\"key\": ~S, \"old_value\": ~S, \"new_value\": ~S}"
                                                                   (first ch) (second ch) (third ch)))
                                                         (transaction-changes tx)))))))))
      (:s-exp
       (format stream "(:transactions~{ ~S~})~%"
               (loop for tx in history
                     collect `(:id ,(transaction-id tx)
                               :name ,(transaction-name tx)
                               :description ,(transaction-description tx)
                               :timestamp ,(transaction-timestamp tx)
                               :categories ,(transaction-categories tx)
                               :changes-count ,(length (transaction-changes tx))
                               ,@(when include-changes `(:changes ,(transaction-changes tx))))))))
    (length history)))

(defun clear-transaction-history (app-state)
  "Clears the transaction history."
  (log-info "Clearing transaction history.")
  (setf (application-state-transaction-history app-state) nil)
  (setf (application-state-undone-history app-state) nil)
  (setf (application-state-transaction-log app-state) nil)))

;; Placeholder for advanced filtering
(defun filter-transaction-history (app-state &key category time-start time-end name-regex affected-key)
  "Filters the transaction history based on provided criteria.
   Returns a new list of transactions. (Placeholder - not fully implemented)"
  (declare (ignore category time-start time-end name-regex affected-key))
  (warn "filter-transaction-history is a placeholder and not fully implemented.")
  (copy-list (get-transaction-history app-state)))

;; Placeholder for diff visualization
(defun generate-transaction-diff (transaction1 transaction2)
  "Generates a diff between two transaction states or a transaction and current state.
   Returns a structured diff representation. (Placeholder - very complex)"
  (declare (ignore transaction1 transaction2))
  (warn "generate-transaction-diff is a placeholder and not fully implemented.")
  nil)
