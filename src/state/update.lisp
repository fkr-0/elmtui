;;;===============================================================
;;; File: src/state/update.lisp
;;; Transactional Update Function Macro
;;;===============================================================
(uiop:define-package :elmtui.state.update
  (:use :cl :alexandria)
  (:import-from :ut.state.state #:application-state #:state-data-data #:application-state-data #:state-ref)
  (:import-from :ut.state.transaction #:with-transaction) ; Removed record-change, assuming set-state! handles it
  (:import-from :elmtui.core.topic-registry #:publish) ; Assuming this exists
  (:import-from :elmtui.clevelib.async #:with-promise #:then) ; For async command
  (:import-from :elmtui.core.loop #:publish) ; For async command callback, assuming publish is the correct function
  (:export :defupdate :dispatch-to-topic :handle-async-command))
(in-package :elmtui.state.update)

;; Helper for the basic macroexpansion-time check (simple walker)
(defun %walk-tree (fn tree)
  "Recursively applies FN to each node (cons or atom) in TREE."
  (cond
    ((atom tree) (funcall fn tree))
    (t (funcall fn (cons (%walk-tree fn (car tree))
                         (%walk-tree fn (cdr tree)))))))
;; Helper functions for topic commands (assuming structure)
(defun topic-command-p (cmd)
  (and (listp cmd) (eq (first cmd) :topic-dispatch) (= (length cmd) 3)))

(defun topic-command-topic (cmd)
  (second cmd))

(defun topic-command-payload (cmd)
  (third cmd))

(defmacro defupdate (name (state-var msg-var) &body body)
  "Define an update function with topic-based message dispatching support.
   The body is expected to use a local set-state! macro (not provided by defupdate itself)
   for state changes, which should be handled within the with-transaction.
   The body should return a list of commands."
  ;; The original defupdate expected the body to return (values state-patch-plist commands)
  ;; This new version expects the body to perform state changes using a (presumably)
  ;; lexically available set-state! and return only commands.
  ;; The with-transaction now wraps the entire body.
  `(defun ,name (,state-var ,msg-var)
     (declare (ignorable ,msg-var))
     (with-transaction (,state-var :name ',name) ; Added :name for better transaction logging
       ;; The body is now responsible for using a (hypothetical) set-state!
       ;; that correctly interacts with with-transaction's change recording.
       (let ((result (progn ,@body)))
         ;; Dispatch any returned commands that are topic commands
         (when (and result (listp result))
           (dolist (cmd result)
             (when (topic-command-p cmd)
               (elmtui.core.topic-registry:publish
                (topic-command-topic cmd)
                (topic-command-payload cmd)))))
         ;; Return all results from the body (which should be commands)
         result))))

(defun dispatch-to-topic (topic payload)
  "Create a command that dispatches a payload to a specific topic."
  (list :topic-dispatch topic payload))

(defun handle-async-command (command app-state)
  "Handle asynchronous commands and feed results back to update cycle."
  (declare (ignorable app-state)) ; app-state might be needed for more complex commands
  (case (first command)
    (:async-task
     (let ((task-fn (second command))
           (on-complete-msg-fn (third command))) ; Renamed for clarity: expects a function that returns a message
       (elmtui.clevelib.async:with-promise (promise)
         ;; Execute the async task
         (funcall task-fn promise)
         ;; When the promise resolves, construct and publish the completion message
         (elmtui.clevelib.async:then
          promise
          (lambda (result)
            (when on-complete-msg-fn
              ;; Assuming elmtui.core.loop:publish takes a topic and a message
              ;; and that the application's main loop subscribes to "app/update"
              ;; to feed messages back into an update function.
              (elmtui.core.loop:publish
               "app/update" ; This topic needs to be conventional or configurable
               (funcall on-complete-msg-fn result))))))))
    ;; Potentially handle other async command types here
    (:another-async-type
     (log:warn "Unhandled async command type: ~A" (first command)))
    (t (log:warn "Unknown command structure passed to handle-async-command: ~S" command))))
