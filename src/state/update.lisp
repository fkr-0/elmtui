;;;===============================================================
;;; File: src/state/update.lisp
;;; Transactional Update Function Macro
;;;===============================================================
(uiop:define-package :elmtui.state.update
  (:use :cl :alexandria)
  (:import-from :cl-state.core
                #:state-set
                #:state-ref
                #:application-state-plist)
  (:import-from :cl-state.utils
                #:get-path
                #:set-path
                #:remove-path)
  (:import-from :cl-state.tx
                #:with-transaction)
  (:import-from :elmtui.core.async
                #:interpret-cmd)
  (:import-from :elmtui.core.globals #:*app-sender*)
  (:import-from :log4cl #:log-debug #:log-warn #:log-info)
  (:export
   #:*log-update-results*
   #:malformed-update-result-error
   #:update-context
   #:make-update-context
   #:context-patches
   #:context-commands
   #:sref
   #:sapply
   #:sdelete
   #:send-command
   #:cmd
   #:defupdate
   #:dispatch-to-topic
   #:publish-to-topic
   #:handle-async-command))

(in-package :elmtui.state.update)

(defvar *log-update-results* nil
  "When T, logs the patches and commands returned by update functions.")

(defstruct (update-context (:constructor %make-update-context))
  state
  base-path
  draft
  patches
  commands)

(defun %full-path (ctx path)
  (let ((base (update-context-base-path ctx)))
    (cond
      ((null base) path)
      ((null path) base)
      ((symbolp path) (append base (list path)))
      ((listp path) (append base path))
      (t path))))

(defun make-update-context (state &key base-path)
  "Create an update context with an isolated draft for mutations."
  (let ((draft (application-state-plist state)))
    (%make-update-context
     :state state
     :base-path base-path
     :draft draft
     :patches nil
     :commands nil)))

(defun context-patches (ctx)
  "Return recorded patches in original order."
  (nreverse (update-context-patches ctx)))

(defun context-commands (ctx)
  "Return recorded commands in original order."
  (nreverse (update-context-commands ctx)))

(defgeneric sref (obj path &optional default))

(defmethod sref ((ctx update-context) path &optional default)
  (get-path (%full-path ctx path) (update-context-draft ctx) default))

(defmethod sref (obj path &optional default)
  (state-ref obj path default))

(defmethod (setf sref) (value (ctx update-context) path)
  (let* ((full-path (%full-path ctx path))
         (draft (update-context-draft ctx)))
    (if (eq value :elmtui-delete-path)
        (multiple-value-bind (draft* _) (remove-path draft full-path)
          (declare (ignore _))
          (setf (update-context-draft ctx) draft*))
        (setf (update-context-draft ctx)
              (set-path draft full-path value))))
  (push (list (%full-path ctx path) value) (update-context-patches ctx))
  value)

(defmethod (setf sref) (value obj path)
  (setf (state-ref obj path) value))

(defun sapply (ctx path fn &optional default)
  "Apply FN to the current value at PATH and store the result."
  (let* ((cur (sref ctx path default))
         (next (funcall fn cur)))
    (setf (sref ctx path) next)
    next))

(defun sdelete (ctx path)
  "Delete PATH in the update context."
  (setf (sref ctx path) :elmtui-delete-path))

(defun send-command (ctx command)
  "Record a command in the update context."
  (push command (update-context-commands ctx))
  command)

(defun cmd (ctx command)
  "Alias for SEND-COMMAND."
  (send-command ctx command))

(defmethod cl-state.core:state-ref ((ctx update-context) key &optional default)
  (sref ctx key default))

(defmethod (setf cl-state.core:state-ref) (value (ctx update-context) (key t))
  (setf (sref ctx key) value))

(defmethod cl-state.utils:get-path (path (ctx update-context) &optional default)
  (sref ctx path default))

(define-condition malformed-update-result-error (error)
  ((update-fn-name :initarg :update-fn-name :reader malformed-update-result-fn-name :type symbol)
   (reason :initarg :reason :reader malformed-update-result-reason :type string)
   (returned-values :initarg :returned-values :reader malformed-update-result-values :type list))
  (:report (lambda (condition stream)
             (format stream "Malformed result from update function ~S: ~A. Values: ~S"
                     (malformed-update-result-fn-name condition)
                     (malformed-update-result-reason condition)
                     (malformed-update-result-values condition)))))

(defun process-update-result (returned-values &key update-fn-name (log-p *log-update-results*))
  "Validate and process values returned by an update function."
  (unless (and (listp returned-values) (= (length returned-values) 2))
    (error 'malformed-update-result-error
           :update-fn-name update-fn-name
           :reason "Expected exactly two values: (patches-list commands-list)"
           :returned-values returned-values))
  (let ((patches-list (first returned-values))
        (commands-list (second returned-values)))
    (unless (listp patches-list)
      (error 'malformed-update-result-error
             :update-fn-name update-fn-name
             :reason "Patches list is not a list (or nil)"
             :returned-values returned-values))
    (unless (listp commands-list)
      (error 'malformed-update-result-error
             :update-fn-name update-fn-name
             :reason "Commands list is not a list (or nil)"
             :returned-values returned-values))
    (when log-p
      (log-debug "Update ~S: Patches=~S, Commands=~S"
                 update-fn-name patches-list commands-list))
    (values patches-list commands-list)))

(defun topic-command-p (cmd)
  (and (listp cmd) (eq (first cmd) :topic-dispatch) (= (length cmd) 3)))

(defun topic-command-topic (cmd) (second cmd))
(defun topic-command-payload (cmd) (third cmd))

(defmacro defupdate (name (state-var msg-var) &body body)
  "Define an Elm-style update function."
  `(defun ,name (,state-var ,msg-var)
     (declare (ignorable ,msg-var))
     (with-transaction (,state-var :name ',name)
       (multiple-value-bind (returned-patches returned-commands)
           (progn ,@body)
         (multiple-value-bind (patches commands)
             (process-update-result (list returned-patches returned-commands)
                                    :update-fn-name ',name
                                    :log-p *log-update-results*)
           (when patches
             (dolist (p patches)
               (state-set ,state-var (first p) (second p))))
           (let ((remaining-commands nil))
             (dolist (cmd commands)
               (if (topic-command-p cmd)
                   (publish-to-topic (topic-command-topic cmd) (topic-command-payload cmd))
                   (push cmd remaining-commands)))
             (dolist (cmd remaining-commands)
               (handle-async-command cmd ,state-var)))
           (values patches commands))))))

(defmethod publish-to-topic (topic-name message)
  (log-warn "Default publish-to-topic: no handler for topic ~S with message ~S."
            topic-name message)
  nil)

(defun dispatch-to-topic (topic payload)
  "Create a command that dispatches a payload to a specific topic."
  (list :topic-dispatch topic payload))

(defmethod handle-async-command (command app-state)
  "Handle asynchronous commands and feed results back to update cycle via *app-sender*."
  (declare (ignorable app-state))
  (case (first command)
    (:async
     (interpret-cmd command))
    (:log-message
     (log-info "Command: ~S" (second command)))
    (t (log-warn "Unknown command structure passed to handle-async-command: ~S" command))))
