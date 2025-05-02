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
  (%walk-tree (lambda (node)
                (when (listp node)
                  (let ((op (first node)))
                    (cond
                      ;; Check for (setf/setq/set-state ...)
                      ((member op '(setf setq ut.state.state:set-state) :test #'eq)
                       ;; Avoid warning on the setf inside our own set-state! macroexpansion
                       (unless (and (eq op 'setf)
                                    (listp (second node))
                                    (eq (first (second node)) 'gethash)) ; Check if it's (setf (gethash ...))
                         (warn "Discouraged direct state modification (~A) found in defupdate body for '~A'. Use the local set-state! macro instead for transactional updates." op name)))
                      ;; Check for (setf (state-ref ...))
                      ((and (eq op 'setf) (listp (second node)) (eq (first (second node)) 'ut.state.state:state-ref))
                       (warn "Discouraged direct (setf state-ref) found in defupdate body for '~A'. Use the local set-state! macro instead for transactional updates." name)))))
                node) ; Return the node itself for walk-tree
              body)

  `(defun ,name (,app-state-arg ,msg-arg)
     (with-transaction (,app-state-arg :label ',name) ; Pass function name as transaction label
       (macrolet ((set-state! (key value)
                    "Sets KEY to VALUE in the current APP-STATE transactionally.
                     Must be used within a DEFUPDATE body. Records the change
                     and performs the state update."
                    ;; Use gensyms to avoid capturing key/value if they are complex forms
                    ;; and ensure proper evaluation order.
                    (let ((key-gs (gensym "KEY"))
                          (value-gs (gensym "VALUE"))
                          (old-value-gs (gensym "OLD_VALUE"))
                          (state-data-gs (gensym "STATE_DATA")))
                      `(let* ((,key-gs ,key)
                              (,value-gs ,value)
                              (,state-data-gs (application-state-data ,',app-state-arg))
                              ;; Capture old value *before* setting the new one.
                              ;; Use a sentinel value if the key is not present for accurate recording.
                              (,old-value-gs (gethash ,key-gs (state-data-data ,state-data-gs) :%not-present%)))
                         ;; Record the change for the transaction log
                         (record-change ,',app-state-arg ,key-gs ,old-value-gs ,value-gs)
                         ;; Perform the actual state update using gethash for direct access
                         (setf (gethash ,key-gs (state-data-data ,state-data-gs)) ,value-gs)
                         ;; Return the new value, mimicking setf behavior
                         ,value-gs))))
         ;; The user's body code executes here, using set-state!
         ;; The result of the last form in body is returned by with-transaction
         ,@body))))
