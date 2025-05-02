(uiop:define-package :uncharming-tui.state.state (:use :cl :log4cl)
  (:nicknames :ut.state.state)
  (:export :make-application-state :state-ref :get-state
    :set-state :application-state
    :application-state-transaction-log :transaction-id
    :application-state-observers :application-state-data
    :application-state-lock
    :state-data :state-data-data
    :merge-state :with-state :with-comp-state
    :state-if-unset-else :log-state-data
    :application-state-transaction-history
    :application-state-undone-history ; Added export
    :transaction-log
    :transaction-history
    :undone-history)) ; Added export

(in-package :ut.state.state)

(defstruct state-data
  "A struct to hold the application state data.
  The data is stored in a hash-table."
  (data (make-hash-table :test 'equal) :type hash-table))

(defstruct application-state
  "A struct to hold the application state.
  The application state holds the state data, observers, a lock, a transaction log,
  a transaction history (for undo), and an undone history (for redo)."
  (data (make-state-data) :type state-data)
  (observers (list) :type list)
  (lock (sb-thread:make-mutex) :type sb-thread:mutex)
  (transaction-log (list) :type list) ; Temporary log for current transaction
  (transaction-history (list) :type list) ; Stack of committed transactions (undo stack)
  (undone-history (list) :type list)) ; Stack of undone transactions (redo stack)

;; (defmethod print-object ((st application-state) stream)
;;   (print-unreadable-object (st stream :type t :identity t)
;;     (format stream "<App-State|Data:~A|Trans:~A|Obs:~A>"
;;       (hash-table-count (state-data-data (application-state-data st)))
;;       (length (application-state-transaction-log st))
;;       (hash-table-count (application-state-observers st)))))

(defmethod print-object ((s state-data) stream)
  (print-unreadable-object (s stream :type t :identity t)
    (format stream "<~A>" (hash-table-count (state-data-data s)))))

(defgeneric merge-state (state other-state &key overwrite)
  (:method ((state application-state) (other-state application-state) &key
             (overwrite nil) (as-transaction nil))
    "Merge the other-state into the state.

    Args:
      state: The state to merge into.
      other-state: The state to merge.
      overwrite: If true, overwrite existing keys in state with keys from other-state.
      as-transaction: If true, merge as a transaction.

    Returns:
      The state with the merged data."
    (when as-transaction
      (error "Not implemented."))
    (maphash
      (lambda (key value)
        (when (or overwrite
                (not
                  (gethash key
                    (state-data-data
                      (application-state-data state)))))
          (setf (state-ref state key) value)))
      (state-data-data (application-state-data other-state)))
    state)
  (:documentation "Merge the other-state into the state."))

(defmethod merge-state
  ((state null) (other-state application-state) &key (overwrite t))
  (declare (ignore overwrite))
  other-state)

(defmethod merge-state
  ((state application-state) (other-state null) &key (overwrite t))
  (declare (ignore overwrite))
  state)

(defmethod merge-state
  ((state application-state) (other-state list) &key (overwrite t))
  (loop for (key value) on other-state by #'cddr
    do (when (or overwrite
               (not
                 (gethash key
                   (state-data-data
                     (application-state-data state)))))
         (setf (state-ref state key) value)))
  state)

(defmethod merge-state
  ((state list) (other-state application-state) &key (overwrite t))
  (merge-state
    (merge-state (make-application-state) state :overwrite overwrite)
    other-state
    :overwrite overwrite))

(defmethod merge-state ((state list) (other-state null) &key (overwrite t))
  (merge-state (make-application-state) state :overwrite overwrite))

(defmethod merge-state ((state null) (other-state list) &key (overwrite t))
  (merge-state (make-application-state) other-state :overwrite overwrite))

(defmethod get-state ((app-state application-state) key)
  "Get the value of `KEY' from application state `APP-STATE'.

  Args:
    app-state: The application state to get the value from.
    key: The key to get the value for.

  Returns:
    The value of `KEY' in `APP-STATE', or nil if not found."
  (gethash key (state-data-data (application-state-data app-state))))

(defmethod set-state ((app-state application-state) key value)
  "Set the value of `KEY' in application state `APP-STATE' to `VALUE'.
  NOTE: This method bypasses transaction logging. Use within transaction logic
  (like apply/revert-transaction) or use the `set-state!` macro inside `defupdate`.

  Args:
    app-state: The application state to set the value on.
    key: The key to set.
    value: The value to set.

  Returns:
    nil"
  (setf (gethash key (state-data-data (application-state-data app-state)))
    value))

(defgeneric state-ref (app-state key &optional comp-id)
  (:documentation "Get the value of `KEY' from application state `APP-STATE'.
  Optionally provide COMP-ID to scope the key.

  Args:
    app-state: The application state to get the value from.
    key: The key to get the value for.
    comp-id: Optional component identifier to scope the key.

  Returns:
    The value of `KEY' in `APP-STATE', or nil if not found.")
  (:method ((app-state application-state) key &optional comp-id)
    (get-state app-state
      (if comp-id
        (list comp-id key)
        key))))

(defgeneric (setf state-ref) (value app-state key &optional comp-id)
  (:documentation
    "Set the value of `KEY' in application state `APP-STATE' to `VALUE'.
    Optionally provide COMP-ID to scope the key.

    NOTE: This method bypasses transaction logging and locking. It is generally
    unsafe for direct use. Use the `set-state!` macro provided within `defupdate`
    for safe, transactional updates. This method exists primarily for internal
    use or specific scenarios where transactionality is handled externally.

  Args:
    value: The value to set.
    app-state: The application state to set the value on.
    key: The key to set.
    comp-id: Optional component identifier to scope the key.

  Returns:
    The set value.")
  (:method (value (app-state application-state) key &optional comp-id)
    ;; WARNING: This bypasses the lock and transaction logging.
    ;; Prefer using set-state! within defupdate.
    (set-state app-state
      (if comp-id
        (list comp-id key)
        key)
      value)))

(defmethod log-state-data ((state application-state))
  "Log the state data."
  (log-info "=====================")
  (let ((data (state-data-data (application-state-data state)))
         (components (make-hash-table :test 'equal)))
    (maphash
      (lambda (key value)
        (let ((component
                ;; Basic check if key is a list (potential component scope)
                (when (listp key) (car key))))
          (if component
            (push (list key value) (gethash component components))
            (push (list key value) (gethash "No Component" components)))))
      data)
    (log-info "State Data:")
    (maphash
      (lambda (component keys-and-values)
        (log-info "Component: ~A" component)
        (dolist (kv keys-and-values)
          (destructuring-bind (key value) kv (log-info "  ~A: ~A" key value))))
      components))
  (log-info "====================="))

(defmacro with-state ((app-state &rest mappings) &body body)
  "Executes the body with local bindings to state paths. Updates the state if any bindings change.
   WARNING: This macro bypasses transaction logging. Prefer using `defupdate`."
  `(let ,(mapcar
           (lambda (mapping)
             (let ((var (first mapping)) (path (second mapping)))
               `(,var (get-state ,app-state ',path))))
           mappings)
     ,@body
     ;; After executing the body, update the state if there are changes
     ,@(mapcar
         (lambda (mapping)
           (let ((var (first mapping)) (path (second mapping)))
             `(when (not (equal ,var (get-state ,app-state ',path)))
                ;; Use internal set-state, bypassing transaction log
                (set-state ,app-state ',path ,var))))
         mappings)))

(defmacro with-comp-state ((app-state comp &rest mappings) &body body)
  "Executes the body with local bindings to component-scoped state paths.
   Updates the state if any bindings change.
   WARNING: This macro bypasses transaction logging. Prefer using `defupdate`."
  `(let ,(mapcar
           (lambda (mapping)
             (let ((var (first mapping)) (path (second mapping)))
               `(,var (get-state ,app-state (list ,comp ',path))))) ; Ensure path is quoted
           mappings)
     ,@body
     ;; After executing the body, update the state if there are changes
     ,@(mapcar
         (lambda (mapping)
           (let ((var (first mapping)) (path (second mapping)))
             `(let ((scoped-path (list ,comp ',path))) ; Ensure path is quoted
                (when (not
                        (equal ,var (get-state ,app-state scoped-path)))
                  ;; Use internal set-state, bypassing transaction log
                  (set-state ,app-state scoped-path ,var)))))
         mappings)))

(defmacro state-if-unset-else
  (app-state path value &optional (exclusive-else nil) &rest body)
  "Executes the body if the state at the specified path is unset.
Otherwise, executes the else body.
WARNING: This macro bypasses transaction logging. Prefer using `defupdate`.

  Args:
    app-state: The application state.
    path: The state path to check.
    value: The value to set if the state is unset.
    exclusive-else: If true, only execute the else-body if the state is set.
    body: The body to execute if the state is unset.
    else-body: The body to execute if the state is set.
  Returns:
    The result of executing the body or else-body.
  Example:
    (state-if-unset-else app-state '(\"components\" \"my-component\") 22
      (set-state app-state '(\"components\" \"my-component\") 22) ; Bypasses log
      (set-state app-state '(\"components\" \"my-component\") (+ 22 22))) ; Bypasses log"
  `(if (not (state-ref ,app-state ,path))
     (progn
       ;; Use internal set-state, bypassing transaction log
       (set-state ,app-state ,path ,value)
       (unless ,exclusive-else
         ,@body))
     (progn ,@body)))
