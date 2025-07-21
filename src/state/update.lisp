;;;===============================================================
;;; File: src/state/update.lisp
;;; Transactional Update Function Macro
;;;===============================================================
(uiop:define-package :elmtui.state.update
  (:use :cl :alexandria)

  (:import-from :elmtui.tea-state.state ; For application-state structure if needed
   :application-state ;; Assuming this is the type from statelib
                :application-state-data   ;; Accessor for the raw data within app-state
                )
  (:import-from :elmtui.state.api ; Import from the central API
   :handle-async-command :application-state :get-state
                :application-state :with-transaction
                :merge-patches ; For applying patches to state data
   :publish-to-topic :dispatch-to-topic :handle-async-command
                :malformed-update-result-error)
  ;; (:import-from :elmtui.statelib.state ; For direct access to app-state internals if needed
  ;;  :state-data-data) ; Accessor for the raw data plist within app-state
  (:import-from :elmtui.core.globals #:*app-sender*)
  (:import-from :log4cl #:log-debug #:log-warn #:log-info)
  (:export ;; Symbols defined *in this file* that are part of the public API
   ;; These are already exported by elmtui.state.api
   :defupdate
   ;; :publish-to-topic :dispatch-to-topic :handle-async-command (already imported and re-exported by api)
   ;; :malformed-update-result-error (already imported and re-exported by api)
   :*log-update-results* ;; This can be a local export if not in the main API
   ))
(in-package :elmtui.state.update)

;; `publish-to-topic` should be defined if it's not just a re-export.
;; Assuming it's related to command handling and might be more complex.
;; For now, if it's just a concept, elmtui.state.api exports it.
;; If it needs an implementation here:


;; Default method for publish-to-topic (can be specialized by users or other systems)
(defmethod publish-to-topic (topic-name message)
  (log-warn "Default publish-to-topic: No specific handler for topic ~S with message ~S. Consider using elmtui.core.topics:publish."
            topic-name message)
  ;; Or, integrate with elmtui.core.topics if that's the intended mechanism
  ;; (elmtui.core.topics:publish topic-name message)
  nil)


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
   The first value should be a list of patches (or nil).
   The second value should be a list of commands (or nil).
   Returns (values patches-list commands-list) or signals MALFORMED-UPDATE-RESULT-ERROR."
  (unless (and (listp returned-values) (= (length returned-values) 2))
    (error 'malformed-update-result-error
           :update-fn-name update-fn-name
           :reason "Expected exactly two values: (patches-list commands-list)"
           :returned-values returned-values))

  (let ((patches-list (first returned-values))
        (commands-list (second returned-values)))

    ;; Validate patches-list: must be a list (can be nil). Each patch itself should be (path value).
    (unless (listp patches-list)
      (error 'malformed-update-result-error
             :update-fn-name update-fn-name
             :reason "Patches list is not a list (or nil)"
             :returned-values returned-values))
    ;; Further validation for each patch structure can be added if needed.
    ;; e.g., (every #'(lambda (p) (and (listp p) (= (length p) 2) (listp (first p)))) patches-list)

    ;; Validate commands-list: must be a list (can be nil).
    (unless (listp commands-list)
      (error 'malformed-update-result-error
             :update-fn-name update-fn-name
             :reason "Commands list is not a list (or nil)"
             :returned-values returned-values))

    (when log-p
      (log-debug "Update ~S: Patches=~S, Commands=~S"
                 update-fn-name patches-list commands-list))

    (values patches-list commands-list)))

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
  "Define an Elm-style update function.
   The function takes the current application-state (STATE-VAR) and a message (MSG-VAR).
   The BODY is expected to return two values:
     1. A list of patches (property list or list of path-value pairs) to apply to the state.
     2. A list of commands to be executed.
   This macro wraps the body in a transaction (`elmtui.state.api:with-transaction`).
   Inside the transaction, it applies the returned patches to the STATE-VAR's internal data
   using `elmtui.state.api:merge-patches`.
   The commands-list is processed for topic dispatch and then returned by the generated function.

   Example:
   (defupdate my-updater (current-app-state message)
     (if (eq message :increment)
         (values (list :counter (1+ (getf (elmtui.state.api:get-state current-app-state :counter) 0))) ; Patches
                 (list '(:log \"Counter incremented\"))) ; Commands
         (values nil nil))) ; No change, no commands
  "
  `(defun ,name (,state-var ,msg-var)
     (declare (ignorable ,msg-var)
              (type elmtui.tea-state.api:application-state ,state-var))
     (elmtui.tea-state.api:with-transaction (,state-var :name ',name)
       (multiple-value-bind (returned-patches returned-commands)
           (progn ,@body) ; Execute the user-provided body
         (let ((processed-patches (process-update-result (list returned-patches returned-commands)
                                                         :update-fn-name ',name
                                                         :log-p *log-update-results*)))
           (when processed-patches
             ;; Correctly access the nested data structure:
             ;; state-var (application-state) -> its 'data' slot (state-data instance) -> its 'data' slot (raw hash-table)
             (let* ((the-state-data-object (application-state-data ,state-var))
                    (current-raw-data (application-state-data the-state-data-object)))
               (setf (application-state-data the-state-data-object)
                     (elmtui.state.api:merge-patches
                      current-raw-data
                      processed-patches))))

           ;; Process commands: dispatch topic commands, handle async commands
           (let ((remaining-commands nil))
             (dolist (cmd returned-commands)
               (if (topic-command-p cmd)
                   (publish-to-topic (topic-command-topic cmd) (topic-command-payload cmd))
                   (push cmd remaining-commands)))
             ;; Handle other async commands (those not dispatched to topics)
             (dolist (cmd remaining-commands)
               (handle-async-command cmd ,state-var)) ;; Pass state-var for context if needed
             )
           ;; The generated function itself returns the patches and original commands list
           ;; for potential further processing or inspection by the caller (e.g., the main app loop).
           (values processed-patches returned-commands))))))

;; `dispatch-to-topic` is a helper to create a command, exported by API.
(defun dispatch-to-topic (topic payload)
  "Create a command that dispatches a payload to a specific topic."
  (list :topic-dispatch topic payload))

;; `handle-async-command` is for processing commands, exported by API.
(defmethod handle-async-command (command app-state)
  "Handle asynchronous commands and feed results back to update cycle via *app-sender*."
  (declare (ignorable app-state)) ; app-state might be needed for context
  (case (first command)
    (:async-task
     (let ((task-fn (second command))
           (on-complete-msg-constructor (third command))) ; Expects a function that takes result and returns a message
       ;; Assuming cleve-elm.async is available or a similar promise mechanism
       ;; For simplicity, using bordeaux-threads for a detached thread.
       ;; A real promise library would be better.
       (bt:make-thread
        (lambda ()
          (let ((result (funcall task-fn))) ; task-fn should not rely on dynamic context from here
            (when on-complete-msg-constructor
              (let ((msg (funcall on-complete-msg-constructor result)))
                (funcall elmtui.core.globals:*app-sender* msg))))))))
    ;; Potentially handle other async command types here
    (:log-message
     (log-info "Command: ~S" (second command)))
    (t (log-warn "Unknown command structure passed to handle-async-command: ~S" command))))
