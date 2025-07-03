;;;===============================================================
;;; File: src/elmtui/contracts.lisp
;;; Formal Elm Architecture Contracts & Enforcement
;;;===============================================================
(uiop:define-package :elmtui.contracts
  (:use :cl)
  (:export 
   ;; Core contract macros
   #:defupdate #:defview #:defsubscriptions
   ;; Contract validation
   #:validate-update-result #:validate-model #:validate-commands
   #:validate-dsl #:validate-subscriptions
   ;; Error conditions
   #:contract-violation #:update-contract-violation
   #:view-contract-violation #:subscription-contract-violation
   ;; Development utilities
   #:enable-contract-debugging #:trace-contracts
   ;; Stage pipeline contracts
   #:define-stage #:define-pipeline))

(in-package :elmtui.contracts)

;;;--------------------------------------------------------------
;;; Contract Violation Conditions
;;;--------------------------------------------------------------

(define-condition contract-violation (error)
  ((function-name :initarg :function-name :reader cv-function-name)
   (expected-type :initarg :expected-type :reader cv-expected-type)
   (actual-value :initarg :actual-value :reader cv-actual-value)
   (context :initarg :context :reader cv-context :initform nil))
  (:report (lambda (condition stream)
             (format stream "Contract violation in ~A: expected ~A, got ~A~@[ in ~A~]"
                     (cv-function-name condition)
                     (cv-expected-type condition)
                     (cv-actual-value condition)
                     (cv-context condition)))))

(define-condition update-contract-violation (contract-violation) ())
(define-condition view-contract-violation (contract-violation) ())
(define-condition subscription-contract-violation (contract-violation) ())

;;;--------------------------------------------------------------
;;; Model Validation
;;;--------------------------------------------------------------

(defun validate-model (model &optional (context "model validation"))
  "Validates that model follows proper structure"
  (unless (or (null model)
              (and (listp model)
                   (evenp (length model))
                   (loop for (key value) on model by #'cddr
                         always (keywordp key))))
    (error 'contract-violation
           :function-name 'validate-model
           :expected-type "property list with keyword keys"
           :actual-value model
           :context context))
  model)

(defun validate-commands (commands &optional (context "command validation"))
  "Validates that commands list is properly structured"
  (unless (or (null commands)
              (and (listp commands)
                   (every #'validate-command commands)))
    (error 'contract-violation
           :function-name 'validate-commands
           :expected-type "list of valid commands"
           :actual-value commands
           :context context))
  commands)

(defun validate-command (command)
  "Validates individual command structure"
  (and (listp command)
       (keywordp (first command))
       (evenp (length (rest command)))))

;;;--------------------------------------------------------------
;;; Update Function Contract
;;;--------------------------------------------------------------

(defmacro defupdate (name (model-param message-param) &body body)
  "Defines an update function with strict Elm Architecture contract enforcement.
   
   Contract: update(model, message) => (values new-model commands)
   - model: Current application state (immutable, property list)
   - message: Event/action to process (any value)
   - new-model: Updated state or nil (no change)
   - commands: List of side-effects to execute or nil
   
   Example:
   (defupdate counter-update (model message)
     (case message
       (:increment (values (list :count (1+ (getf model :count 0))) nil))
       (:decrement (values (list :count (1- (getf model :count 0))) nil))
       (t (values nil nil))))"
  
  (let ((doc-string (when (stringp (first body)) (first body)))
        (actual-body (if (stringp (first body)) (rest body) body)))
    `(defun ,name (,model-param ,message-param)
       ,@(when doc-string (list doc-string))
       
       ;; Input validation
       (validate-model ,model-param "update function input")
       
       ;; Execute update logic with contract enforcement
       (multiple-value-bind (new-model commands)
           (handler-case (progn ,@actual-body)
             (error (e)
               (error 'update-contract-violation
                      :function-name ',name
                      :expected-type "successful update execution"
                      :actual-value e
                      :context (format nil "processing message ~S" ,message-param))))
         
         ;; Output validation
         (validate-update-result new-model commands ',name ,model-param ,message-param)
         
         ;; Contract debugging if enabled
         (when *contract-debugging*
           (log-update-execution ',name ,model-param ,message-param new-model commands))
         
         (values new-model commands)))))

(defun validate-update-result (new-model commands function-name model message)
  "Validates the result of an update function"
  (unless (or (null new-model) (validate-model new-model "update result model"))
    (error 'update-contract-violation
           :function-name function-name
           :expected-type "valid model or nil"
           :actual-value new-model
           :context (format nil "updating model ~S with message ~S" model message)))
  
  (unless (or (null commands) (validate-commands commands "update result commands"))
    (error 'update-contract-violation
           :function-name function-name
           :expected-type "valid commands list or nil"
           :actual-value commands
           :context (format nil "updating model ~S with message ~S" model message))))

;;;--------------------------------------------------------------
;;; View Function Contract
;;;--------------------------------------------------------------

(defmacro defview (name (model-param) &body body)
  "Defines a view function with strict contract enforcement.
   
   Contract: view(model) => dsl-tree
   - model: Current application state (read-only)
   - Returns: Valid DSL tree structure
   
   Example:
   (defview counter-view (model)
     `(:container
       :id :counter-main
       :children ((:text :text ,(format nil \"Count: ~A\" (getf model :count 0)))))"
  
  (let ((doc-string (when (stringp (first body)) (first body)))
        (actual-body (if (stringp (first body)) (rest body) body)))
    `(defun ,name (,model-param)
       ,@(when doc-string (list doc-string))
       
       ;; Input validation
       (validate-model ,model-param "view function input")
       
       ;; Execute view logic with contract enforcement
       (let ((result (handler-case (progn ,@actual-body)
                       (error (e)
                         (error 'view-contract-violation
                                :function-name ',name
                                :expected-type "successful view generation"
                                :actual-value e
                                :context (format nil "rendering model ~S" ,model-param))))))
         
         ;; Output validation
         (validate-dsl result ',name ,model-param)
         
         ;; Contract debugging if enabled
         (when *contract-debugging*
           (log-view-execution ',name ,model-param result))
         
         result))))

(defun validate-dsl (dsl function-name model)
  "Validates DSL structure"
  (unless (valid-dsl-p dsl)
    (error 'view-contract-violation
           :function-name function-name
           :expected-type "valid DSL structure"
           :actual-value dsl
           :context (format nil "rendering model ~S" model)))
  dsl)

(defun valid-dsl-p (dsl)
  "Checks if DSL structure is valid"
  (or (stringp dsl)
      (numberp dsl)
      (and (listp dsl)
           (keywordp (first dsl))
           (evenp (length (rest dsl))))))

;;;--------------------------------------------------------------
;;; Subscription Contract
;;;--------------------------------------------------------------

(defstruct subscription
  "Subscription descriptor for Elm Architecture"
  type        ; :keyboard, :timer, :http, etc.
  config      ; Configuration parameters (plist)
  message-fn) ; Function: event-data -> message

(defmacro defsubscriptions (name (model-param) &body body)
  "Defines a subscriptions function with contract enforcement.
   
   Contract: subscriptions(model) => [subscription]
   - model: Current application state
   - Returns: List of active subscription descriptors
   
   Example:
   (defsubscriptions counter-subscriptions (model)
     (when (getf model :timer-active)
       (list (make-subscription :type :timer
                               :config '(:interval 1000)
                               :message-fn (lambda (tick) :timer-tick)))))"
  
  (let ((doc-string (when (stringp (first body)) (first body)))
        (actual-body (if (stringp (first body)) (rest body) body)))
    `(defun ,name (,model-param)
       ,@(when doc-string (list doc-string))
       
       ;; Input validation
       (validate-model ,model-param "subscriptions function input")
       
       ;; Execute subscriptions logic
       (let ((result (handler-case (progn ,@actual-body)
                       (error (e)
                         (error 'subscription-contract-violation
                                :function-name ',name
                                :expected-type "successful subscriptions generation"
                                :actual-value e
                                :context (format nil "generating subscriptions for model ~S" ,model-param))))))
         
         ;; Output validation
         (validate-subscriptions result ',name ,model-param)
         
         ;; Contract debugging if enabled
         (when *contract-debugging*
           (log-subscriptions-execution ',name ,model-param result))
         
         result))))

(defun validate-subscriptions (subscriptions function-name model)
  "Validates subscriptions list structure"
  (unless (or (null subscriptions)
              (and (listp subscriptions)
                   (every #'subscription-p subscriptions)))
    (error 'subscription-contract-violation
           :function-name function-name
           :expected-type "list of subscription structures"
           :actual-value subscriptions
           :context (format nil "generating subscriptions for model ~S" model)))
  subscriptions)

;;;--------------------------------------------------------------
;;; Pipeline Stage Contracts (from existing contracts.lisp)
;;;--------------------------------------------------------------

(define-condition pipeline-contract-violation (error)
  ((stage         :initarg :stage :reader violation-stage)
   (expected-type :initarg :expected-type :reader violation-expected)
   (got-object    :initarg :got-object :reader violation-got))
  (:report (lambda (c s)
             (with-slots (stage expected-type got-object) c
               (format s "~a expected ~s but got ~s (~s)."
                       stage expected-type got-object (type-of got-object))))))

(defmacro define-stage (name (in-type out-type) arglist &body body)
  "Wrap BODY in run-time CHECK-TYPE and restartable contract checks."
  (let ((result (gensym "RES")))
    `(defun ,name ,arglist
       (check-type (first ,arglist) ,in-type
         ,(format nil "~a input violated contract (expected ~a)." name in-type))
       (handler-bind
           ((error (lambda (e)
                     (error 'pipeline-contract-violation
                            :stage ',name
                            :expected-type ',in-type
                            :got-object e))))
         (let ((,result (progn ,@body)))
           (unless (typep ,result ',out-type)
             (restart-case
                 (error 'pipeline-contract-violation
                        :stage ',name
                        :expected-type ',out-type
                        :got-object ,result)
               (coerce-result (new)
                 :report "Provide replacement value and continue."
                 :interactive (lambda ()
                                (format t "~%New value? ")
                                (list (eval (read))))
                 (setq ,result new))
               (skip-stage ()
                 :report "Skip this stage and propagate input forward."
                 (setq ,result (first ,arglist)))))
           ,result)))))

(defmacro define-pipeline (name &rest stage-fns)
  "Compose STAGE-FNS into a single function that threads a context plist through them."
  (let ((context (gensym "CONTEXT")))
    `(defun ,name (,context)
       (reduce (lambda (ctx fn) (funcall fn ctx))
               ',stage-fns
               :initial-value ,context))))

;;;--------------------------------------------------------------
;;; Contract Debugging & Development Support
;;;--------------------------------------------------------------

(defvar *contract-debugging* nil
  "Enable contract debugging and tracing")

(defvar *update-log* nil
  "Log of update function executions")

(defvar *view-log* nil
  "Log of view function executions")

(defvar *subscriptions-log* nil
  "Log of subscription function executions")

(defun enable-contract-debugging (&optional (enabled t))
  "Enable/disable contract debugging"
  (setf *contract-debugging* enabled)
  (when enabled
    (setf *update-log* nil
          *view-log* nil
          *subscriptions-log* nil)))

(defun log-update-execution (function-name model message new-model commands)
  "Log update function execution for debugging"
  (push (list :timestamp (get-universal-time)
              :function function-name
              :input-model model
              :message message
              :output-model new-model
              :commands commands)
        *update-log*))

(defun log-view-execution (function-name model dsl)
  "Log view function execution for debugging"
  (push (list :timestamp (get-universal-time)
              :function function-name
              :model model
              :dsl-size (if (listp dsl) (length dsl) 1))
        *view-log*))

(defun log-subscriptions-execution (function-name model subscriptions)
  "Log subscriptions function execution for debugging"
  (push (list :timestamp (get-universal-time)
              :function function-name
              :model model
              :subscription-count (length subscriptions))
        *subscriptions-log*))

(defun trace-contracts (&key update view subscriptions)
  "Enable tracing for specific contract types"
  (when update
    (format t "~&Tracing UPDATE contracts...~%"))
  (when view
    (format t "~&Tracing VIEW contracts...~%"))
  (when subscriptions
    (format t "~&Tracing SUBSCRIPTION contracts...~%")))

;;;--------------------------------------------------------------
;;; Contract Validation Utilities
;;;--------------------------------------------------------------

(defun validate-elm-application (update-fn view-fn subscriptions-fn &optional init-model)
  "Validates that an Elm application's functions conform to contracts"
  (let ((test-model (or init-model '(:test t))))
    
    ;; Test update function
    (multiple-value-bind (new-model commands)
        (funcall update-fn test-model :test-message)
      (validate-model new-model "update function result")
      (validate-commands commands "update function commands"))
    
    ;; Test view function
    (let ((dsl (funcall view-fn test-model)))
      (validate-dsl dsl 'validate-elm-application test-model))
    
    ;; Test subscriptions function
    (let ((subs (funcall subscriptions-fn test-model)))
      (validate-subscriptions subs 'validate-elm-application test-model))
    
    t))

(defun contract-summary ()
  "Returns summary of contract executions for debugging"
  (list :update-executions (length *update-log*)
        :view-executions (length *view-log*)
        :subscription-executions (length *subscriptions-log*)
        :debugging-enabled *contract-debugging*))
