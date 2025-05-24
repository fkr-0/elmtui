(defpackage :elmtui.state.transactions
  (:use :cl)
  (:export :with-transaction
   :begin-transaction
           :commit-transaction
   :rollback-transaction
           :in-transaction-p
   :set-slot
           :register-change-listener
   :unregister-change-listener
   :undo-last-transaction
   :redo-last-transaction
   :clear-transaction-history))

(in-package :elmtui.state.transactions)

;; Transaction State Management
(defvar *current-transaction* nil
  "Current active transaction")

(defvar *change-listeners* nil
  "List of registered change listeners")

(defstruct transaction
  (id (gensym "TRANSACTION-") :read-only t)
  (name nil :type (or null string symbol)) ; Added for named transactions
  (changes nil :type list)
  (timestamp (get-universal-time) :read-only t))

(defun in-transaction-p ()
  "Check if there's an active transaction"
  (not (null *current-transaction*)))

;; Change listener interface
(defun register-change-listener (listener-fn)
  "Register a function to be called when changes are committed"
  (pushnew listener-fn *change-listeners*))

(defun unregister-change-listener (listener-fn)
  "Remove a previously registered change listener"
  (setf *change-listeners* (remove listener-fn *change-listeners*)))

(defun notify-change-listeners (changes)
  "Notify all registered listeners of changes"
  (dolist (listener *change-listeners*)
    (funcall listener changes)))

;; Transaction Management
(defun begin-transaction (&key name)
  "Start a new transaction, optionally with a name."
  (let ((new-transaction (make-transaction :name name)))
    (when *current-transaction*
      (warn "Starting nested transaction ~:[~;~:*named '~A' ~]within ~A~:[~;~:* (named '~A')~]"
            name
            (transaction-id *current-transaction*)
            (transaction-name *current-transaction*)))
    (setf *current-transaction* new-transaction)
    new-transaction))

(defun commit-transaction ()
  "Commit the current transaction"
  (unless *current-transaction*
    (error "No active transaction to commit"))
  (let ((changes (transaction-changes *current-transaction*)))
    (push *current-transaction* *transaction-history*)
    (setf *current-transaction* nil)
    ;; Notify listeners of committed changes
    (notify-change-listeners changes)
    changes))

(defun rollback-transaction ()
  "Rollback the current transaction"
  (unless *current-transaction*
    (error "No active transaction to rollback"))
  (let ((transaction *current-transaction*))
    ;; Undo all changes in reverse order
    (dolist (change (reverse (transaction-changes transaction)))
      (destructuring-bind (object slot-name old-value) change
        (slot-makunbound object slot-name)
        (when old-value
          (setf (slot-value object slot-name) old-value))))
    (setf *current-transaction* nil)
    transaction))

(defmacro with-transaction ((&key name) &body body)
  "Execute body within a transaction, optionally named."
  `(let ((*current-transaction* (begin-transaction :name ,name)))
     (unwind-protect
          (multiple-value-prog1
              (progn ,@body)
            (commit-transaction))
       (when *current-transaction*
         (rollback-transaction)))))

;; Enhanced slot modification with validation
(defun set-slot (object slot-name new-value)
  "Set a slot value with transaction support and validation"
  (let ((old-value nil)
        (had-value nil))
    
    ;; Perform validation before changing the slot
    (when (find-method #'validate-before-change '() 
                       (list (class-of object) t t) nil)
      (validate-before-change object slot-name new-value))
    
    ;; Record old value if in transaction
    (when (in-transaction-p)
      (when (slot-boundp object slot-name)
        (setf old-value (slot-value object slot-name)
              had-value t)))
    
    ;; Set the new value
    (setf (slot-value object slot-name) new-value)
    
    ;; Record change in transaction
    (when (in-transaction-p)
      (push (list object slot-name (when had-value old-value))
            (transaction-changes *current-transaction*)))
    
    new-value))

;; Define a generic function for validation
(defgeneric validate-before-change (object slot-name new-value)
  (:documentation "Validation hook for slot changes - to be implemented by models"))

;; Default method does no validation
(defmethod validate-before-change ((object t) slot-name new-value)
  (declare (ignore slot-name new-value))
  t)

;; Transaction history for undo/redo
(defvar *transaction-history* nil 
  "List of committed transactions for undo operations")

(defvar *redo-stack* nil
  "Stack of undone transactions for redo operations")

(defun clear-transaction-history ()
  "Clear the transaction history and redo stack."
  (setf *transaction-history* nil
        *redo-stack* nil)
  t)

(defun undo-last-transaction ()
  "Undo the most recent transaction in the history.
   Returns the undone transaction or NIL if there's nothing to undo."
  (when *transaction-history*
    (let ((last-transaction (pop *transaction-history*)))
      ;; Push to redo stack
      (push last-transaction *redo-stack*)
      ;; Undo each change in reverse order
      (dolist (change (reverse (transaction-changes last-transaction)))
        (let ((object (first change))
              (slot (second change))
              (old-value (third change)))
          (set-slot object slot old-value)))
      ;; Notify listeners about the undo
      (dolist (listener *change-listeners*)
        (funcall listener :undo last-transaction))
      last-transaction)))

(defun redo-last-transaction ()
  "Redo the most recently undone transaction.
   Returns the redone transaction or NIL if there's nothing to redo."
  (when *redo-stack*
    (let ((last-undone (pop *redo-stack*)))
      ;; Push back to history
      (push last-undone *transaction-history*)
      ;; Redo each change
      (dolist (change (transaction-changes last-undone))
        (let ((object (first change))
              (slot (second change))
              (old-value (third change))
              (new-value (fourth change)))
          (set-slot object slot new-value)))
      ;; Notify listeners about the redo
      (dolist (listener *change-listeners*)
        (funcall listener :redo last-undone))
      last-undone)))
