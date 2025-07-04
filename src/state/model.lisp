;;;===============================================================
;;; File: src/state/model.lisp
;;; Enhanced State Model System with Contracts and Transactions
;;;===============================================================
(uiop:define-package :elmtui.state.model
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.contracts #:validate-model #:contract-violation)
  (:export
   ;; Core model definition
   #:defmodel-contracted #:defmodel #:get-state-schema #:*state-schemas*
   ;; State validation
   #:validate-state-schema #:validate-state-instance
   ;; State patches and transactions
   #:defpatch #:deftransaction #:apply-state-patches
   #:state-patch #:make-state-patch #:state-patch-p
   #:transaction-status
   #:transaction-id #:transaction-patches
   #:transaction-pre-hooks #:transaction-post-hooks
   #:transaction-rollback #:transaction-timestamp
   #:transaction-description #:transaction-source
   ;; Transaction management
   #:transaction #:make-transaction #:transaction-p
   ;; State utilities
   #:get-state-value #:set-state-value #:update-state-value
   #:merge-state-updates #:diff-states
   ;; State observers
   #:add-state-observer #:remove-state-observer #:notify-state-observers))

(in-package :elmtui.state.model)

;;;--------------------------------------------------------------
;;; State Schema Registry and Core Structures
;;;--------------------------------------------------------------

(defparameter *state-schemas* (make-hash-table :test 'eq)
  "Registry of defined state schemas with their validation rules")

(defparameter *state-observers* (make-hash-table :test 'eq)
  "Registry of state observers for different state types")

;; State patch structure for atomic updates
(defstruct state-patch
  "Represents a single atomic state change"
  path        ; Path to the state field (list of keywords)
  value       ; New value to set
  operation   ; :set, :update, :delete, :append, :prepend
  validator   ; Optional validation function for the value
  timestamp   ; When the patch was created
  source      ; Source identifier (for debugging/auditing)
  metadata)   ; Additional metadata for the patch

;; Transaction structure for grouped updates
(defstruct transaction
  "Represents a group of state patches applied atomically"
  id          ; Unique transaction identifier
  patches     ; List of state-patch instances
  pre-hooks   ; Functions to execute before applying patches
  post-hooks  ; Functions to execute after applying patches
  rollback    ; Rollback information (original state)
  timestamp   ; When transaction was created
  description ; Human-readable description
  status)     ; :pending, :committed, :rolled-back, :failed

;;;--------------------------------------------------------------
;;; Enhanced State Model Definition
;;;--------------------------------------------------------------

(defmacro defmodel-contracted (name slots &key validation transactions observers
                                            documentation export-accessors)
  "Defines a contract-enforced state model with validation, transactions, and observers"

  (let* ((schema-name (intern (format nil "~A-SCHEMA" name)))
         (validator-name (intern (format nil "VALIDATE-~A" name)))
         (constructor-name (intern (format nil "MAKE-~A" name)))
         (updater-name (intern (format nil "UPDATE-~A" name)))
         (accessor-names (mapcar (lambda (slot)
                                   (intern (format nil "~A-~A" name (first slot))))
                                 slots))
         (slot-keywords (mapcar (lambda (slot)
                                  (intern (symbol-name (first slot)) :keyword))
                                slots)))

    `(progn
       ;; Define the model schema with comprehensive metadata
       (defparameter ,schema-name
         (list :name ',name
               :slots ',slots
               :validation ',validation
               :transactions ',transactions
               :observers ',observers
               :documentation ,(or documentation (format nil "State model: ~A" name))
               :created-at ,(get-universal-time)))

       ;; Register schema in global registry
       (setf (gethash ',name *state-schemas*) ,schema-name)

       ;; Define comprehensive validation function
       (defun ,validator-name (state &optional (context ,(format nil "~A validation" name)))
         ,(format nil "Validates ~A state against its schema with detailed error reporting" name)

         ;; Basic structure validation
         (unless (listp state)
           (error 'contract-violation
                  :function-name ',validator-name
                  :expected-type "property list"
                  :actual-value state
                  :context context))

         (unless (evenp (length state))
           (error 'contract-violation
                  :function-name ',validator-name
                  :expected-type "valid property list (even length)"
                  :actual-value state
                  :context context))

         ;; Validate each slot according to its specification
         ,@(mapcar (lambda (slot slot-keyword)
                     (let ((slot-name (first slot))
                           (default-value (second slot))
                           (slot-options (cddr slot))
                           (slot-type (getf (cddr slot) :type t))
                           (required-p (getf (cddr slot) :required))
                           (validator-fn (getf (cddr slot) :validator)))
                       (declare (ignore slot-options))

                       `(let ((value (getf state ,slot-keyword ',default-value))
                              (has-value-p (member ,slot-keyword state)))

                          ;; Check required constraint
                          ,@(when required-p
                              `((unless has-value-p
                                  (error 'contract-violation
                                         :function-name ',validator-name
                                         :expected-type ,(format nil "required slot ~A" slot-name)
                                         :actual-value nil
                                         :context context))))

                          ;; Check type constraint
                          ,@(unless (eq slot-type t)
                              `((when (and has-value-p (not (typep value ',slot-type)))
                                  (error 'contract-violation
                                         :function-name ',validator-name
                                         :expected-type ',slot-type
                                         :actual-value value
                                         :context (format nil "~A slot ~A" context ',slot-name)))))

                          ;; Apply custom validator if provided
                          ,@(when validator-fn
                              `((when has-value-p
                                  (unless (funcall ,validator-fn value)
                                    (error 'contract-violation
                                           :function-name ',validator-name
                                           :expected-type ,(format nil "valid ~A (custom validation)" slot-name)
                                           :actual-value value
                                           :context (format nil "~A custom validation for ~A" context ',slot-name)))))))))
                   slots slot-keywords)

         ;; Apply global validation rules if provided
         ,@(when validation
             `((handler-case
                   (funcall ,validation state)
                 (error (e)
                   (error 'contract-violation
                          :function-name ',validator-name
                          :expected-type "state passing global validation"
                          :actual-value state
                          :context (format nil "~A global validation: ~A" context e))))))

         ;; Return validated state
         state)

       ;; Define constructor with validation and defaults
       (defun ,constructor-name (&key ,@(mapcar (lambda (slot)
                                                  `(,(first slot) ,(second slot)))
                                                slots) &allow-other-keys)
         ,(format nil "Creates a new ~A instance with validation and proper defaults" name)
         (let ((state (list ,@(mapcan (lambda (slot slot-keyword)
                                        `(,slot-keyword ,(first slot)))
                                      slots slot-keywords))))
           ;; Validate constructed state
           (,validator-name state ,(format nil "~A construction" name))
           ;; Notify observers of new state creation
           (notify-state-observers ',name nil state :created)
           state))

       ;; Define safe update function with validation
       (defun ,updater-name (state &rest updates)
         ,(format nil "Updates ~A state with validation" name)
         (let ((old-state (copy-tree state))
               (new-state (copy-list state)))

           ;; Apply updates
           (loop for (slot-key value) on updates by #'cddr
                 do (setf (getf new-state slot-key) value))

           ;; Validate updated state
           (,validator-name new-state ,(format nil "~A update" name))

           ;; Notify observers of state change
           (notify-state-observers ',name old-state new-state :updated)

           new-state))

       ;; Define individual slot accessors if requested
       ,@(when export-accessors
           (mapcar (lambda (slot accessor-name slot-keyword)
                     `(defun ,accessor-name (state)
                        ,(format nil "Safely accesses ~A from ~A state" (first slot) name)
                        (getf state ,slot-keyword ,(second slot))))
                   slots accessor-names slot-keywords))

       ;; Register predefined transactions
       ,@(when transactions
           (mapcar (lambda (transaction-spec)
                     (let ((trans-name (first transaction-spec))
                           (trans-params (second transaction-spec))
                           (trans-body (cddr transaction-spec)))
                       `(deftransaction ,trans-name ,trans-params
                          ,@trans-body)))
                   transactions))

       ;; Register observers
       ,@(when observers
           `((dolist (observer ',observers)
               (add-state-observer ',name observer))))

       ;; Export public interface if requested
       ,@(when export-accessors
           `((export '(,name ,schema-name ,validator-name ,constructor-name
                       ,updater-name ,@accessor-names))))

       ;; Return the model name
       ',name)))

;; Backward compatibility alias
(defmacro defmodel (name slots &rest options)
  "Backward compatible defmodel (delegates to defmodel-contracted)"
  `(defmodel-contracted ,name ,slots ,@options))

;;;--------------------------------------------------------------
;;; State Patch Operations
;;;--------------------------------------------------------------

(defmacro defpatch (name (state-var &rest args) &body body)
  "Defines a named state patch operation with validation"
  `(defun ,name (,state-var ,@args)
     (declare (ignorable ,state-var))
     ,(format nil "Patch operation: ~A" name)
     (let ((patches (progn ,@body)))
       ;; Ensure result is a list of patches
       (let ((patch-list (if (state-patch-p patches)
                             (list patches)
                             patches)))
         ;; Validate all patches
         (dolist (patch patch-list)
           (unless (state-patch-p patch)
             (error "Patch operation ~A must return state-patch instances" ',name))
           ;; Apply patch validator if present
           (when (state-patch-validator patch)
             (unless (funcall (state-patch-validator patch) (state-patch-value patch))
               (error 'contract-violation
                      :function-name ',name
                      :expected-type "valid patch value"
                      :actual-value (state-patch-value patch)
                      :context "patch validation failed"))))
         patch-list))))

(defun apply-state-patches (state patches)
  "Applies a list of state patches to a state, returning the new state"
  (let ((new-state (copy-tree state)))
    (dolist (patch patches)
      (let ((path (state-patch-path patch))
            (value (state-patch-value patch))
            (operation (state-patch-operation patch)))

        (case operation
          (:set
           (if (= (length path) 1)
               ;; Direct property update
               (setf (getf new-state (first path)) value)
               ;; Nested property update
               (setf (getf (get-nested-property new-state (butlast path))
                           (car (last path)))
                     value)))

          (:update
           ;; Apply update function to current value
           (if (= (length path) 1)
               (setf (getf new-state (first path))
                     (funcall value (getf new-state (first path))))
               (let ((current (get-nested-property new-state path)))
                 (set-nested-property new-state path (funcall value current)))))

          (:delete
           (if (= (length path) 1)
               (remf new-state (first path))
               (remf (get-nested-property new-state (butlast path))
                     (car (last path)))))

          (:append
           (let ((current (get-nested-property new-state path)))
             (set-nested-property new-state path
                                  (append (ensure-list current) (ensure-list value)))))

          (:prepend
           (let ((current (get-nested-property new-state path)))
             (set-nested-property new-state path
                                  (append (ensure-list value) (ensure-list current)))))

          (t (error "Unknown patch operation: ~A" operation)))))
    new-state))

;;;--------------------------------------------------------------
;;; Transaction System
;;;--------------------------------------------------------------

(defmacro deftransaction (name (state-var &rest args) &body body)
  "Defines a transactional state update with rollback capability"
  `(defun ,name (,state-var ,@args)
     ,(format nil "Transaction: ~A" name)
     (let* ((transaction-id (gensym ,(format nil "~A-TRANSACTION" name)))
            (original-state (copy-tree ,state-var))
            (start-time (get-universal-time)))

       (handler-case
           (let ((patches (progn ,@body)))
             ;; Normalize to patch list
             (let ((patch-list (if (state-patch-p patches)
                                   (list patches)
                                   patches)))

               ;; Create transaction record
               (let ((transaction (make-transaction
                                   :id transaction-id
                                   :patches patch-list
                                   :rollback original-state
                                   :timestamp start-time
                                   :description ,(format nil "Transaction: ~A" name)
                                   :status :pending)))

                 ;; Execute pre-hooks if any exist
                 (dolist (hook (transaction-pre-hooks transaction))
                   (funcall hook original-state))

                 ;; Apply patches atomically
                 (let ((new-state (apply-state-patches ,state-var patch-list)))
                   ;; Mark transaction as committed
                   (setf (transaction-status transaction) :committed)

                   ;; Execute post-hooks
                   (dolist (hook (transaction-post-hooks transaction))
                     (funcall hook original-state new-state))

                   ;; Return new state and transaction info
                   (values new-state transaction)))))

         (error (e)
           ;; Transaction failed - rollback and report
           (warn "Transaction ~A failed: ~A. State unchanged." transaction-id e)
           (values ,state-var nil))))))

;;;--------------------------------------------------------------
;;; State Utilities
;;;--------------------------------------------------------------

(defun get-state-schema (model-name)
  "Retrieves the schema for a state model"
  (gethash model-name *state-schemas*))

(defun validate-state-schema (model-name)
  "Validates that a state schema is properly defined"
  (let ((schema (get-state-schema model-name)))
    (unless schema
      (error "No schema found for state model: ~A" model-name))
    (unless (getf schema :slots)
      (error "Schema for ~A missing slot definitions" model-name))
    schema))

(defun validate-state-instance (state model-name)
  "Validates a state instance against its schema"
  (let ((schema (validate-state-schema model-name)))
    (declare (ignore schema))
    (log-debug "Validating state instance against schema: ~A" model-name)
    (let ((validator-name (intern (format nil "VALIDATE-~A" model-name))))
      (when (fboundp validator-name)
        (funcall (symbol-function validator-name) state)))))

(defun get-state-value (state path &optional default)
  "Gets a value from state using a path (list of keywords)"
  (get-nested-property state path default))

(defun set-state-value (state path value)
  "Sets a value in state using a path (returns new state)"
  (let ((new-state (copy-tree state)))
    (set-nested-property new-state path value)
    new-state))

(defun update-state-value (state path update-function)
  "Updates a value in state using a function (returns new state)"
  (let ((current-value (get-state-value state path)))
    (set-state-value state path (funcall update-function current-value))))

(defun merge-state-updates (state &rest updates)
  "Merges multiple state updates into a new state"
  (let ((new-state (copy-list state)))
    (loop for (key value) on (apply #'append updates) by #'cddr
          do (setf (getf new-state key) value))
    new-state))

(defun diff-states (old-state new-state)
  "Computes the differences between two states"
  (let ((changes nil))
    ;; Find changed and new properties
    (loop for (key value) on new-state by #'cddr
          do (let ((old-value (getf old-state key :not-found)))
               (unless (equal value old-value)
                 (push (list :changed key old-value value) changes))))

    ;; Find removed properties
    (loop for (key value) on old-state by #'cddr
          unless (member key new-state)
            do (push (list :removed key value nil) changes))

    (nreverse changes)))

;;;--------------------------------------------------------------
;;; State Observer System
;;;--------------------------------------------------------------

(defun add-state-observer (model-name observer-function)
  "Adds an observer function for a state model"
  (push observer-function (gethash model-name *state-observers*)))

(defun remove-state-observer (model-name observer-function)
  "Removes an observer function for a state model"
  (setf (gethash model-name *state-observers*)
        (remove observer-function (gethash model-name *state-observers*))))

(defun notify-state-observers (model-name old-state new-state change-type)
  "Notifies all observers of a state change"
  (let ((observers (gethash model-name *state-observers*)))
    (dolist (observer observers)
      (handler-case
          (funcall observer old-state new-state change-type)
        (error (e)
          (warn "State observer error for ~A: ~A" model-name e))))))

;;;--------------------------------------------------------------
;;; Helper Functions
;;;--------------------------------------------------------------

(defmethod get-nested-property (plist path &optional default)
  "Gets a nested property from a plist using a path"
  (if (null path)
      plist
      (let ((value (getf plist (first path) :not-found)))
        (if (eq value :not-found)
            default
            (if (rest path)
                (get-nested-property value (rest path) default)
                value)))))

(defmethod (setf get-nested-property) (value plist path)
  "Sets a nested property in a plist using a path (destructively modifies)"
  (if (null path)
      (error "Cannot set value at empty path")
      (let ((key (first path)))
        (if (= (length path) 1)
            (setf (getf plist key) value)
            (let ((next-level (getf plist key)))
              (unless next-level
                (setf next-level nil)
                (setf (getf plist key) next-level))
              (set-nested-property next-level (rest path) value))))))

(defun set-nested-property (plist path value)
  "Sets a nested property in a plist using a path (destructively modifies)"
  (if (= (length path) 1)
      (setf (getf plist (first path)) value)
      (let ((next-level (getf plist (first path))))
        (unless next-level
          (setf next-level nil)
          (setf (getf plist (first path)) next-level))
        (set-nested-property next-level (rest path) value))))

;;;--------------------------------------------------------------
;;; Example Enhanced Model Definitions
;;;--------------------------------------------------------------

;; Example: Enhanced form state model
(defmodel-contracted form-state
    ((name "" :type string :required t
              :validator (lambda (v) (and (stringp v) (> (length v) 0))))
     (email "" :type string :required t
               :validator (lambda (v) (or (string= v "") (search "@" v))))
     (subject "" :type string :required t)
     (message "" :type string)
     (submitted nil :type boolean)
     (validation-errors nil :type list)
     (focus-manager nil :type (or null t))
     (last-modified nil :type (or null integer)))

  :validation (lambda (state)
                ;; Global validation: if submitted, all required fields must be filled
                (when (getf state :submitted)
                  (let ((name (getf state :name))
                        (email (getf state :email))
                        (subject (getf state :subject)))
                    (when (or (string= name "") (string= email "") (string= subject ""))
                      (error "Cannot submit form with empty required fields")))))

  :transactions
  ((update-field-transaction (state field value)
                             "Updates a form field and clears validation errors"
                             (list (make-state-patch :path (list field) :value value :operation :set)
                                   (make-state-patch :path '(:validation-errors) :value nil :operation :set)
                                   (make-state-patch :path '(:last-modified) :value (get-universal-time) :operation :set)))

   (submit-form-transaction (state)
                            "Validates and submits the form"
                            (let ((errors nil))
                              ;; Validate required fields
                              (when (string= (getf state :name) "") (push "Name is required" errors))
                              (when (string= (getf state :email) "") (push "Email is required" errors))
                              (when (string= (getf state :subject) "") (push "Subject is required" errors))

                              (if errors
                                  ;; Set validation errors
                                  (list (make-state-patch :path '(:validation-errors) :value errors :operation :set))
                                  ;; Mark as submitted
                                  (list (make-state-patch :path '(:submitted) :value t :operation :set)
                                        (make-state-patch :path '(:validation-errors) :value nil :operation :set))))))

  :observers
  ((lambda (old-state new-state change-type)
     ;; Log significant state changes
     (when (eq change-type :updated)
       (let ((old-submitted (getf old-state :submitted))
             (new-submitted (getf new-state :submitted)))
         (when (and (not old-submitted) new-submitted)
           (format t "~&Form submitted at ~A~%" (get-universal-time)))))))

  :documentation "Enhanced form state model with validation, transactions, and observers"
  :export-accessors t)

;; Example patch operations for the form
(defpatch update-form-field (state field value)
  "Updates a form field with validation"
  (make-state-patch
   :path (list field)
   :value value
   :operation :set
   :validator (case field
                (:email (lambda (v) (or (string= v "") (search "@" v))))
                ((:name :subject) (lambda (v) (stringp v)))
                (:submitted (lambda (v) (typep v 'boolean)))
                (t (constantly t)))
   :source :user-input
   :timestamp (get-universal-time)
   :metadata (list :field field :change-type :user-edit)))

(defpatch add-validation-error (state error-message)
  "Adds a validation error to the state"
  (make-state-patch
   :path '(:validation-errors)
   :value error-message
   :operation :append
   :source :validation
   :timestamp (get-universal-time)))

;; Example transaction
(deftransaction reset-form (state)
  "Resets the form to its initial state"
  (list (make-state-patch :path '(:name) :value "" :operation :set)
        (make-state-patch :path '(:email) :value "" :operation :set)
        (make-state-patch :path '(:subject) :value "" :operation :set)
        (make-state-patch :path '(:message) :value "" :operation :set)
        (make-state-patch :path '(:submitted) :value nil :operation :set)
        (make-state-patch :path '(:validation-errors) :value nil :operation :set)
        (make-state-patch :path '(:last-modified) :value (get-universal-time) :operation :set)))
