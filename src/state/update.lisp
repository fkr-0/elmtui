;;;===============================================================
;;; File: src/state/update.lisp
;;; Transactional Update Function Macro
;;;===============================================================
(uiop:define-package :elmtui.state.update
  (:use :cl :alexandria) ; Using alexandria for warnings
  (:import-from :ut.state.state #:application-state #:state-data-data #:application-state-data #:state-ref)
  (:import-from :ut.state.transaction #:with-transaction #:record-change)
  (:export :defupdate))
(in-package :elmtui.state.update)

;; Helper for the basic macroexpansion-time check (simple walker)
(defun %walk-tree (fn tree)
  "Recursively applies FN to each node (cons or atom) in TREE."
  (cond
    ((atom tree) (funcall fn tree))
    (t (funcall fn (cons (%walk-tree fn (car tree))
                         (%walk-tree fn (cdr tree)))))))

(defmacro defupdate (name (app-state-arg msg-arg) &body body)
  "Defines a transactional update function: (App-State Msg) -> [Cmd].

   Updates operate directly on the provided APP-STATE within a transaction,
   managed by ut.state.transaction:with-transaction. State modifications
   MUST be performed using the local `set-state!` macro provided within the
   body of the defupdate form. This ensures changes are recorded for potential
   undo/redo (when fully implemented in statelib).

   Direct use of `setf`, `setq`, `ut.state.state:set-state`, or
   `(setf ut.state.state:state-ref)` within the body is strongly discouraged
   as it will likely bypass transaction recording and potentially lead to
   inconsistent state during rollbacks or undos.

   Args:
     NAME: The symbol naming the update function.
     APP-STATE-ARG: The symbol bound to the application-state instance.
     MSG-ARG: The symbol bound to the incoming message.
     BODY: The forms constituting the update logic. Expected to return a list
           of commands (Cmd Msg) or NIL.

   Returns:
     The defined function `NAME`.

   Example:
     (defupdate handle-increment (app-state message)
       (declare (ignore message)) ; Or use message data
       (let ((current-count (state-ref app-state :counter 0))) ; Assuming :counter exists
         (set-state! :counter (1+ current-count)))
       ;; No commands returned in this case
       nil)"

  ;; Basic macroexpansion-time check for discouraged state modification forms
  ;; Removed %walk-tree as set-state! is no longer a local macro to check for.
  ;; The user's code inside defupdate will now return a state-patch plist and commands.
  `(defun ,name (,app-state-arg ,msg-arg)
     (declare (ignorable ,msg-arg)) ; Ignore the message argument for now
     ;; The user's body is expected to perform its logic and return two values:
     ;; 1. A state-patch-plist: a plist of key-value pairs to update in the state.
     ;; 2. A commands-list: a list of commands to be executed.
     (multiple-value-bind (state-patch-plist returned-commands)
         (progn ,@body)
       ;; If a state patch is returned, apply it transactionally.
       (when state-patch-plist
         (with-transaction (,app-state-arg :label ',name)
           (loop for (key value) on state-patch-plist by #'cddr
                 do (let* ((state-data (application-state-data ,app-state-arg))
                           (old-value (gethash key (state-data-data state-data) :%not-present%)))
                      ;; Ensure key is not nil before using it in gethash or record-change
                      (unless key (error "State patch contains a nil key: ~S" state-patch-plist))
                      (record-change ,app-state-arg key old-value value)
                      (setf (gethash key (state-data-data state-data)) value)))))
       ;; Return the commands.
       returned-commands)))
