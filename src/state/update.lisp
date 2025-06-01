;;;===============================================================
;;; File: src/state/update.lisp
;;; Transactional Update Function Macro
;;;===============================================================
(uiop:define-package :elmtui.state.update
  (:use :cl :alexandria)
  (:import-from :ut.state.state #:application-state #:state-data-data #:application-state-data #:state-ref #:merge-state) ; Added merge-state
  (:import-from :ut.state.transaction #:with-transaction)
  (:import-from :cleve-elm.async #:with-promise #:then) ; For async command
  (:import-from :elmtui.core.globals #:*app-sender*) ; Use *app-sender*
  (:import-from :log4cl #:log-debug) ; Ensure log-debug is available
  (:export :publish-to-topic :defupdate :dispatch-to-topic :handle-async-command
           :malformed-update-result-error :*log-update-results*))
(in-package :elmtui.state.update)
(defgeneric publish-to-topic (topic-name message))

(define-condition malformed-update-result-error (error)
  ((update-fn-name :initarg :update-fn-name :reader malformed-update-result-fn-name :type symbol)
   (reason :initarg :reason :reader malformed-update-result-reason :type string)
   (returned-values :initarg :returned-values :reader malformed-update-result-values :type list))
  (:report (lambda (condition stream)
             (format stream "Malformed result from update function ~S: ~A. Values: ~S"
                     (malformed-update-result-fn-name condition)
                     (malformed-update-result-reason condition)
                     (malformed-update-result-values condition)))))

(defvar *log-update-results* nil
  "When T, logs the state patch and commands returned by update functions defined with defupdate.")

(defun process-update-result (returned-values &key update-fn-name (log-p *log-update-results*))
  "Validates and processes the values returned by an update function's body.
   Expects RETURNED-VALUES to be a list of values from MULTIPLE-VALUE-LIST.
   Returns (values state-patch-plist commands-list) or signals MALFORMED-UPDATE-RESULT-ERROR."
  (unless (and (listp returned-values) (= (length returned-values) 2))
    (error 'malformed-update-result-error
           :update-fn-name update-fn-name
           :reason "Expected exactly two values: (state-patch-plist commands-list)"
           :returned-values returned-values))

  (let ((state-patch-plist (first returned-values))
        (commands-list (second returned-values)))

    ;; Validate state-patch-plist: must be a list (plist or nil) and have an even number of elements if not nil.
    (unless (and (listp state-patch-plist)
                 (or (null state-patch-plist) (evenp (length state-patch-plist))))
      (error 'malformed-update-result-error
             :update-fn-name update-fn-name
             :reason "State patch is not a valid property list (must be a list with an even number of elements, or nil)"
             :returned-values returned-values))

    ;; Validate commands-list: must be a list (can be nil).
    (unless (listp commands-list)
      (error 'malformed-update-result-error
             :update-fn-name update-fn-name
             :reason "Commands list is not a list (or nil)"
             :returned-values returned-values))

    (when log-p
      (log-debug "Update ~S: StatePatch=~S, Commands=~S"
                 update-fn-name state-patch-plist commands-list))

    (values state-patch-plist commands-list)))

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
   The body is expected to return two values: a state-patch-plist and a commands-list.
   The state-patch-plist is applied to the state-var using ut.state.state:merge-state
   within the transaction.
   The commands-list is processed for topic dispatch (if any :topic-dispatch commands are present)
   and then returned by the generated function.
   Example: (defupdate my-updater (app-state msg) (values '(:key :new-value) (list '(:some-command))))"
  `(defun ,name (,state-var ,msg-var)
     (declare (ignorable ,msg-var))
     (with-transaction (,state-var :name ',name)
       (multiple-value-bind (state-patch-plist commands-list)
           (process-update-result (multiple-value-list (progn ,@body))
                                  :update-fn-name ',name
                                  :log-p *log-update-results*)

         ;; Apply the state patch if it's not nil (process-update-result validates its structure)
         (when state-patch-plist
           (ut.state.state:merge-state ,state-var state-patch-plist))

         ;; Dispatch any topic commands from the actual commands-list (process-update-result validates it's a list)
         (when commands-list ; Already known to be a list or nil
           (dolist (cmd commands-list)
             (when (topic-command-p cmd)
               (publish-to-topic
                (topic-command-topic cmd)
                (topic-command-payload cmd)))))
         ;; Return the actual commands-list
         commands-list))))

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
       (with-promise (promise)
         ;; Execute the async task
         (funcall task-fn promise)
         ;; When the promise resolves, construct and publish the completion message
         (then
          promise
          (lambda (result)
            (when on-complete-msg-fn
              ;; Use *app-sender* (which is elmtui.core.loop:publish at runtime)
              ;; This takes a single event argument.
              ;; This event will be wrapped as (:app-message <event>) if necessary
              ;; and enqueued to the main event channel.
              (funcall elmtui.core.globals:*app-sender*
                       (funcall on-complete-msg-fn result))))))))
    ;; Potentially handle other async command types here
    (:another-async-type
     (log:warn "Unhandled async command type: ~A" (first command)))
    (t (log:warn "Unknown command structure passed to handle-async-command: ~S" command))))
