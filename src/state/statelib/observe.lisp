(uiop:define-package :elmtui.statelib.observe
  (:use :cl :log4cl)
  (:import-from :elmtui.statelib.state
   :application-state :application-state-observers :application-state-lock)
  (:export
   :observer ; Exporting struct name
   :observer-key :observer-callback :observer-id ; Exporting accessors
   :add-observer
   :remove-observer
   :notify-observers
   :*trace-observers* ; Export tracing flag
   :with-observers-traced)) ; Export tracing helper macro

(in-package :elmtui.statelib.observe)

;; (defun add-observer (app-state key callback)
;;   "Registers a CALLBACK function to be called when the state associated with KEY changes.
;;    Returns the unique ID of the observer, which can be used for removal.

;;    Args:
;;      app-state: The application-state instance.
;;      key: The state key (e.g., a symbol, list) to observe.
;;      callback: A function designator (function or symbol) that accepts three
;;                arguments: (key old-value new-value).

;;    Returns:
;;      The unique ID (symbol) of the registered observer."
;;   (check-type app-state application-state)
;;   (check-type callback (or function symbol))
;;   (let ((new-observer (make-observer :key key :callback callback)))
;;     (when *trace-observers*
;;       (log-info "Adding observer ~A for key ~S" (observer-id new-observer) key))
;;     (sb-thread:with-mutex ((application-state-lock app-state))
;;       (push new-observer (application-state-observers app-state)))
;;     (observer-id new-observer)))
(defvar *trace-observers* nil
  "When true, enables detailed tracing of observer activity.
   This is useful for debugging observer behavior and chains of updates.
   
   Values:
     nil - No tracing (default)
     t - Basic tracing (adds observer activity to logs)
     :verbose - Detailed tracing including value diffs")

(defmacro with-observers-traced ((level) &body body)
  "Executes body with observer tracing enabled at the specified level.
   
   Args:
     level: Tracing level, one of nil (disabled), t (basic), or :verbose (detailed)
     
   Body:
     Forms to execute with tracing enabled.
     
   Example:
     (with-observers-traced (:verbose)
       (update-counter-model app-state 5))"
  `(let ((*trace-observers* ,level))
     ,@body))

(defstruct observer
  "Represents an observer watching a specific key in the application state."
  (id (gensym "OBSERVER-") :type symbol) ; Unique ID for removal
  (key nil :type T) ; The state key (or path) being observed
  (callback nil :type (or function symbol))) ; Function to call on change

(defun add-observer (app-state key callback)
  "Registers a CALLBACK function to be called when the state associated with KEY changes.
   Returns the unique ID of the observer, which can be used for removal.

   Args:
     app-state: The application-state instance.
     key: The state key (e.g., a symbol, list) to observe.
     callback: A function designator (function or symbol) that accepts three
               arguments: (key old-value new-value).

   Returns:
     The unique ID (symbol) of the registered observer."
  (check-type app-state application-state)
  (check-type callback (or function symbol))
  (let ((new-observer
          (make-observer :key key :callback callback)))
    (log-info "Adding observer ~A for key ~S" (observer-id new-observer) key)
    (sb-thread:with-mutex ((application-state-lock app-state))
      (push new-observer (application-state-observers app-state)))
    (observer-id new-observer)))

(defun remove-observer (app-state observer-id)
  "Removes the observer identified by OBSERVER-ID from the application state.

   Args:
     app-state: The application-state instance.
     observer-id: The unique ID (symbol) returned by add-observer.

   Returns:
     T if an observer was removed, NIL otherwise."
  (check-type app-state application-state)
  (check-type observer-id symbol)
  (when *trace-observers*
    (log-info "Removing observer ~A" observer-id))
  (sb-thread:with-mutex ((application-state-lock app-state))
    (let ((original-length (length (application-state-observers app-state))))
      (setf (application-state-observers app-state)
            (remove observer-id (application-state-observers app-state)
                    :key #'observer-id :test #'eq))
      (/= original-length (length (application-state-observers app-state))))))

(defun notify-observers (app-state changes)
  "Notifies registered observers about state changes recorded in CHANGES.
   Called internally by transaction commit/apply/revert logic.

   Args:
     app-state: The application-state instance.
     changes: A list of change tuples, where each tuple is (key old-value new-value)."
  (check-type app-state application-state)
  (check-type changes list)
  (when changes ; Only proceed if there are changes
    (let ((observers-to-notify (application-state-observers app-state)))
      (when observers-to-notify ; Only proceed if there are observers
        (when *trace-observers*
          (log-debug "Notifying ~D observers about ~D changes."
                     (length observers-to-notify) (length changes)))
        ;; Iterate through each change
        (dolist (change changes)
          (destructuring-bind (changed-key old-value new-value) change
            ;; Iterate through each observer
            (dolist (observer observers-to-notify)
              ;; Check if the observer's key matches the changed key
              (when (equal (observer-key observer) changed-key)
                (when *trace-observers*
                  (log-debug "Triggering observer ~A for key ~S"
                             (observer-id observer) changed-key)
                  (when (eq *trace-observers* :verbose)
                    (log-debug "  Old value: ~S" old-value)
                    (log-debug "  New value: ~S" new-value)))
                (handler-case
                    (funcall (observer-callback observer) changed-key old-value new-value)
                  (error (e)
                    (log-error "Error in observer callback for key ~S (Observer ID: ~A): ~A"
                               changed-key (observer-id observer) e)))))))))))
