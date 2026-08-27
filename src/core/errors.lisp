;;;===================================================================
;;; File: src/core/errors.lisp
;;; Enhanced Error Handling System for Elmtui
;;;===================================================================
;;;
;;; Provides comprehensive error messages with context, suggestions,
;;; and actionable debugging information for the entire Elmtui system.
;;;
;;; Key Features:
;;; - Context-rich error messages with path information
;;; - Automatic suggestions based on common mistakes
;;; - Development vs production mode error handling
;;; - Consistent error formatting across all modules

(uiop:define-package :elmtui.core.errors
  (:use :cl)
  (:import-from :alexandria #:when-let)
  (:export
   #:elmtui-condition
   #:elmtui-information
   #:elmtui-warning
   #:+diagnostic-context-keys+
   #:diagnostic-context-key-p
   #:elmtui-error
   #:elmtui-error-message
   #:elmtui-error-context
   #:elmtui-error-suggestions
   #:elmtui-error-module
   #:state-error
   #:state-error-operation
   #:state-error-path
   #:state-error-type
   #:component-error
   #:component-error-type
   #:component-error-id
   #:component-error-operation
   #:defcomponent-error
   #:defcomponent-error-arg
   #:defcomponent-error-validation-type
   #:dsl-error
   #:dsl-error-form
   #:dsl-error-position
   #:backend-error
   #:backend-error-type
   #:backend-error-operation
   #:make-elmtui-error
   #:error-with-context
   #:suggest-fixes
   #:development-mode-p
   #:with-error-context))

(in-package :elmtui.core.errors)

;;;===================================================================
;;; Configuration
;;;===================================================================

(defvar *development-mode* t
  "When true, provides detailed error messages with suggestions.
   Set to NIL in production for cleaner error messages.")

(defun development-mode-p ()
  "Returns true if we're in development mode."
  *development-mode*)

;;;===================================================================
;;; Base Error Classes
;;;===================================================================

(define-condition elmtui-condition (condition) ()
  (:documentation
   "Inspectable root for maintained ElmTUI framework conditions.

ELMTUI-INFORMATION, ELMTUI-WARNING, and ELMTUI-ERROR form the public severity
families. Subsystem conditions remain inspectable through their concrete type
while a handler on ELMTUI-CONDITION can observe the whole framework family."))

(define-condition elmtui-information (elmtui-condition) ()
  (:documentation "Base class for non-warning informational ElmTUI conditions."))

(define-condition elmtui-warning (warning elmtui-condition) ()
  (:documentation "Base class for ElmTUI warnings."))

(defparameter +diagnostic-context-keys+
  '(:operation :component-id :component-path :state-path :backend
    :message :event :offending-value :expected-type :underlying-condition)
  "Canonical keys for structured ElmTUI diagnostic context.

The vocabulary is deliberately small and orthogonal: operation identifies the
action, component/state/backend keys identify ownership and location,
message/event identifies runtime input, offending-value and expected-type
explain validation failures, and underlying-condition preserves causal errors.")

(defun diagnostic-context-key-p (key)
  "Return true when KEY belongs to the canonical diagnostic context vocabulary."
  (and (keywordp key) (member key +diagnostic-context-keys+ :test #'eq)))

(define-condition elmtui-error (error elmtui-condition)
  ((message
    :initarg :message
    :initform nil
    :reader elmtui-error-message
    :documentation "Optional human-readable summary of the failure.")
   (context
    :initarg :context
    :initform nil
    :reader elmtui-error-context
    :documentation "Inspectable structured context, conventionally an association list.")
   (suggestions
    :initarg :suggestions
    :initform nil
    :reader elmtui-error-suggestions
    :documentation "Ordered list of actionable recovery suggestions.")
   (module
    :initarg :module
    :initform nil
    :reader elmtui-error-module
    :documentation "Logical module or subsystem where the condition originated."))
  (:documentation
   "Base error condition for ElmTUI failures.

Instances are intended to remain inspectable in the debugger: MESSAGE summarizes
the failure, CONTEXT carries machine-readable details, MODULE identifies the
subsystem, and SUGGESTIONS provides human-oriented remediation.  Signaling this
condition does not mutate application state; callers may establish handlers and
invoke restarts supplied around the signaling operation.")
  (:report
   (lambda (condition stream)
     (format stream "~A~@[: ~A~]~@[~&Context: ~A~]~%~@[[~A]~]~%~@{~&   Suggestion: ~A~^~%~}"
             (type-of condition)
             (elmtui-error-message condition)
             (elmtui-error-context condition)
             (elmtui-error-module condition)
             (elmtui-error-suggestions condition)))))

(defmethod print-object ((obj elmtui-error) stream)
  ;; Preserve the historical exact-ELMTUI-ERROR debugger representation while
  ;; allowing newly migrated subclasses to keep DEFINE-CONDITION :REPORT output.
  (if (eq (class-of obj) (find-class 'elmtui-error))
      (print-unreadable-object (obj stream :type t)
        (when-let ((context (elmtui-error-context obj)))
          (format stream " context: ~A" context))
        (when-let ((module (elmtui-error-module obj)))
          (format stream " module: ~A" module))
        (when-let ((suggestions (elmtui-error-suggestions obj)))
          (format stream " suggestions: ~A" suggestions)))
      (call-next-method)))

(define-condition state-error (elmtui-error)
  ((operation :initarg :operation
     :reader state-error-operation
     :documentation "Operation that failed (get, set, update, etc.)")
    (path :initarg :path
      :reader state-error-path
      :documentation "Path that caused the error")
    (state-type :initarg :state-type
      :reader state-error-type
      :documentation "Type of state object (hash-table, plist, etc.)"))
  (:report (lambda (condition stream)
             (let ((op (state-error-operation condition))
                    (path (state-error-path condition))
                    (state-type (state-error-type condition)))
               (format stream "State error in ~A operation~@[ on path ~A~]~@[ with ~A state~]"
                 op path state-type)
               (when (elmtui-error-context condition)
                 (format stream "~&~A" (elmtui-error-context condition)))))))

(defmethod print-object ((obj state-error) stream)
  (print-unreadable-object (obj stream :type t)
    (when-let ((context (elmtui-error-context obj)))
      (format stream " context: ~A" context))
    (when-let ((module (elmtui-error-module obj)))
      (format stream " module: ~A" module))
    (when-let ((suggestions (elmtui-error-suggestions obj)))
      (format stream " suggestions: ~A" suggestions))
    (when-let ((operation (state-error-operation obj)))
      (format stream " operation: ~A" operation))
    (when-let ((path (state-error-path obj)))
      (format stream " path: ~A" path))
    (when-let ((state-type (state-error-type obj)))
      (format stream " state-type: ~A" state-type))))

(define-condition component-error (elmtui-error)
  ((component-type :initarg :component-type
     :reader component-error-type
     :documentation "Type of component that failed")
    (component-id :initarg :component-id
      :reader component-error-id
      :documentation "ID of component that failed")
    (operation :initarg :operation
      :reader component-error-operation
      :documentation "Operation that failed (init, update, view, etc.)"))
  (:report (lambda (condition stream)
             (format stream "Component error: ~A failed ~A operation~@[ on component ~A~]"
               (component-error-type condition)
               (component-error-operation condition)
               (component-error-id condition)))))

(defmethod print-object ((obj component-error) stream)
  (print-unreadable-object (obj stream :type t)
    (when-let ((context (elmtui-error-context obj)))
      (format stream " context: ~A" context))
    (when-let ((module (elmtui-error-module obj)))
      (format stream " module: ~A" module))
    (when-let ((suggestions (elmtui-error-suggestions obj)))
      (format stream " suggestions: ~A" suggestions))
    (when-let ((component-type (component-error-type obj)))
      (format stream " component-type: ~A" component-type))
    (when-let ((component-id (component-error-id obj)))
      (format stream " component-id: ~A" component-id))
    (when-let ((operation (component-error-operation obj)))
      (format stream " operation: ~A" operation))))

(define-condition defcomponent-error (component-error)
  ((macro-arg :initarg :macro-arg
     :reader defcomponent-error-arg
     :documentation "Macro argument that caused the error")
    (validation-type :initarg :validation-type
      :reader defcomponent-error-validation-type
      :documentation "Type of validation that failed"))
  (:report (lambda (condition stream)
             (format stream "Defcomponent validation error: ~A~@[ in argument ~A~]"
               (defcomponent-error-validation-type condition)
               (defcomponent-error-arg condition)))))

(define-condition dsl-error (elmtui-error)
  ((dsl-form :initarg :dsl-form
     :reader dsl-error-form
     :documentation "DSL form that caused the error")
    (position :initarg :position
      :reader dsl-error-position
      :documentation "Position in DSL where error occurred"))
  (:report (lambda (condition stream)
             (format stream "DSL error in form: ~A~@[ at position ~A~]"
               (dsl-error-form condition)
               (dsl-error-position condition)))))

(defmethod print-object ((obj dsl-error) stream)
  (print-unreadable-object (obj stream :type t)
    (when-let ((context (elmtui-error-context obj)))
      (format stream " context: ~A" context))
    (when-let ((module (elmtui-error-module obj)))
      (format stream " module: ~A" module))
    (when-let ((suggestions (elmtui-error-suggestions obj)))
      (format stream " suggestions: ~A" suggestions))
    (when-let ((dsl-form (dsl-error-form obj)))
      (format stream " dsl-form: ~A" dsl-form))
    (when-let ((position (dsl-error-position obj)))
      (format stream " position: ~A" position))))

(define-condition backend-error (elmtui-error)
  ((backend-type :initarg :backend-type
     :reader backend-error-type
     :documentation "Type of backend that failed")
    (operation :initarg :operation
      :reader backend-error-operation
      :documentation "Backend operation that failed"))
  (:report (lambda (condition stream)
             (format stream "Backend error: ~A backend failed during ~A operation"
               (backend-error-type condition)
               (backend-error-operation condition)))))

(defmethod print-object ((obj backend-error) stream)
  (print-unreadable-object (obj stream :type t)
    (when-let ((context (elmtui-error-context obj)))
      (format stream " context: ~A" context))
    (when-let ((module (elmtui-error-module obj)))
      (format stream " module: ~A" module))
    (when-let ((suggestions (elmtui-error-suggestions obj)))
      (format stream " suggestions: ~A" suggestions))
    (when-let ((backend-type (backend-error-type obj)))
      (format stream " backend-type: ~A" backend-type))
    (when-let ((operation (backend-error-operation obj)))
      (format stream " operation: ~A" operation))))

;;;===================================================================
;;; Error Construction Helpers
;;;===================================================================

(defun make-elmtui-error (type &rest args
                         &key message context suggestions module
                         &allow-other-keys)
  "Construct and return an inspectable ElmTUI condition of TYPE.

Arguments:
  TYPE is ELMTUI-ERROR or one of its subclasses. MESSAGE is an optional concise
  summary. CONTEXT is preserved as the caller supplied it, so structured
  plists/alists remain debugger-inspectable. SUGGESTIONS is normalized to a
  list. MODULE identifies the logical subsystem. Remaining keyword arguments
  are passed to MAKE-CONDITION for subclass-specific slots.

Returns:
  A condition object. The condition is not signaled by this function.

Mutation:
  None. Caller-owned CONTEXT and SUGGESTIONS are referenced, not modified.

Conditions:
  MAKE-CONDITION may signal an error when TYPE is unknown or required
  subclass initargs are missing. Those conditions propagate unchanged.

Example:
  (make-elmtui-error 'state-error
    :message \"Counter state is invalid\"
    :operation :update
    :path '(:counter :value)
    :state-type :plist
    :context '((:component-id . :counter)))"
  (let ((base-args
          (remove-from-plist args :message :context :suggestions :module)))
    (apply #'make-condition type
           :message message
           :context context
           :suggestions (ensure-list suggestions)
           :module module
           base-args)))

(defun error-with-context (error-type &rest args)
  "Signal an error with rich context information."
  (let ((error (apply #'make-elmtui-error error-type args)))
    (error error)))

(defun suggest-fixes (&rest suggestions)
  "Create a list of suggested fixes for error messages."
  (mapcar (lambda (suggestion)
            (if (stringp suggestion)
              suggestion
              (format nil "~A" suggestion)))
    (remove nil suggestions)))

;;;===================================================================
;;; Context Management Macros
;;;===================================================================

(defmacro with-error-context ((&key context module operation component-id macro-arg) &body body)
  "Annotate ElmTUI errors signaled by BODY without replacing the condition object.

CONTEXT, MODULE, OPERATION, COMPONENT-ID, and MACRO-ARG are evaluated once.  If
BODY signals ELMTUI-ERROR, the same condition object is enriched in place and
continues through the active condition machinery.  Preserving object identity
also preserves every subclass slot, debugger state, and restart association.

Existing structured context is retained.  Non-list context is wrapped as a
:CONTEXT entry before new entries are appended.  MODULE, when non-NIL, also
updates the condition's module slot.

Mutation: mutates only diagnostic slots of a signaled ELMTUI-ERROR; application
state is untouched.
Conditions: does not catch or suppress ELMTUI-ERROR.  The original condition
continues outward and remains available to HANDLER-BIND, the debugger, and
active restarts.

Example:
  (with-error-context (:module :renderer :operation :draw :component-id id)
    (render-component component))"
  (let ((context-var (gensym "CONTEXT"))
        (module-var (gensym "MODULE"))
        (operation-var (gensym "OPERATION"))
        (component-id-var (gensym "COMPONENT-ID"))
        (macro-arg-var (gensym "MACRO-ARG")))
    `(let ((,context-var ,context)
           (,module-var ,module)
           (,operation-var ,operation)
           (,component-id-var ,component-id)
           (,macro-arg-var ,macro-arg))
       (handler-bind
           ((elmtui-error
              (lambda (condition)
                (let* ((old-context (elmtui-error-context condition))
                       (normalized
                         (cond
                           ((null old-context) nil)
                           ((listp old-context) old-context)
                           (t (list (cons :context old-context)))))
                       (extra
                         (remove nil
                                 (list
                                  (when ,context-var (cons :context ,context-var))
                                  (when ,module-var (cons :module ,module-var))
                                  (when ,operation-var (cons :operation ,operation-var))
                                  (when ,component-id-var
                                    (cons :component-id ,component-id-var))
                                  (when ,macro-arg-var (cons :macro-arg ,macro-arg-var))))))
                  (setf (slot-value condition 'elmtui.core.errors::context)
                        (append normalized extra))
                  (when ,module-var
                    (setf (slot-value condition 'elmtui.core.errors::module)
                          ,module-var))))))
         ,@body))))



;;;===================================================================
;;; Common Error Patterns with Automatic Suggestions
;;;===================================================================

(defun signal-state-type-error (operation path state-type &optional value)
  "Signal a state type error with helpful suggestions."
  (error-with-context
    'state-error
    :operation operation
    :path path
    :state-type state-type
    :context (when value
               (format nil "Attempted value: ~A" value))
    :suggestions (remove nil
                   (list
                     "Check if the state object is the correct type"
                     "Use state-ref/state-set for hash-table states, getf/setf for plists"
                     "Ensure the state was properly initialized"
                     (when (eq state-type 'null)
                       "The state object is nil - did you forget to initialize it?")
                     (when (and path (listp path) (not (keywordp (first path))))
                       "State paths should start with keywords, e.g., '(:counter) not '(counter)")))))

(defun signal-component-not-found (component-id &optional state context)
  "Signal a component not found error."
  (error-with-context
    'component-error
    :component-id component-id
    :operation "lookup"
    :context (format nil "Component not found in state~A ~@[ at path ~A~]" context state)
    :suggestions (suggest-fixes
                   (format nil "Check if component ~A was properly initialized" component-id)
                   "Verify the component ID is correct"
                   "Ensure the component was added to the state during initialization"
                   "Check for typos in the component ID")))

(defun signal-dsl-validation-error (dsl-form position message &rest suggestions)
  "Signal a DSL validation error with position information."
  (error-with-context
    'dsl-error
    :dsl-form dsl-form
    :position position
    :context message
    :suggestions (apply #'suggest-fixes suggestions)))

(defun signal-backend-operation-failed (backend-type operation &optional underlying-error)
  "Signal a backend operation failure with context."
  (error-with-context
    'backend-error
    :backend-type backend-type
    :operation operation
    :context (when underlying-error
               (format nil "Underlying error: ~A" underlying-error))
    :suggestions (suggest-fixes
                   "Check if the backend is properly initialized"
                   "Verify terminal permissions and accessibility"
                   "Try switching to a different backend (e.g., :faketerm for testing)"
                   "Ensure no other process is using the terminal")))

;;;===================================================================
;;; Utilities
;;;===================================================================

(defun remove-from-plist (plist &rest keys)
  "Remove specified keys from a plist."
  (loop for (k v) on plist by #'cddr
    unless (member k keys)
    collect k and collect v))

(defun ensure-list (thing)
  "Ensure THING is a list."
  (if (listp thing) thing (list thing)))

(defun concat-or-nil (&rest strings)
  "Concatenate strings, returning nil if all are nil or empty."
  (let ((result (apply #'concatenate 'string
                  (remove nil (remove "" strings)))))
    (when (and result (plusp (length result)))
      result)))

;;;===================================================================
;;; Development Mode Enhancements
;;;===================================================================

(defmacro with-development-mode (&body body)
  "Execute BODY with enhanced error reporting if development mode is enabled.

When in development mode (as determined by (development-mode-p)), this macro wraps BODY in a handler-bind for the elmtui-error condition. If such an error is signaled, it prints enhanced error details to *error-output*, including:

  + Error type
  + Context (if available)
  + Module (if available)
  + Suggestions (if available)

After printing, it invokes the debugger for interactive inspection.

If not in development mode, BODY is executed normally without enhanced error reporting.

Example usage:
  (with-development-mode
    (do-something-that-might-error))

This macro is useful for providing richer diagnostics during development while keeping production error handling clean."
  `(if (development-mode-p)
     (handler-bind
        ((elmtui-error #'(lambda (e)
                           (format *error-output* "~%=== Enhanced Error Details ===~%")
                           (format *error-output* "Error Type: ~A~%" (type-of e))
                           (when (elmtui-error-context e)
                             (format *error-output* "Context: ~A~%" (elmtui-error-context e)))
                           (when (elmtui-error-module e)
                             (format *error-output* "Module: ~A~%" (elmtui-error-module e)))
                           (format *error-output* "Suggestions:~%~{  - ~A~%~}~%"
                             (elmtui-error-suggestions e))
                           (format *error-output* "=== End Error Details ===~%")
                           (invoke-debugger e))))
        ,@body)
     (progn ,@body)))

;;;===================================================================
;;; Integration Examples
;;;===================================================================
#|
;; Example usage in state management:
(defun safe-state-get (state path &optional default)
(with-error-context (:operation "state-get" :path path)
(typecase state
(hash-table (gethash (car path) state default))
(list (getf state (car path) default))
(null (signal-state-type-error "get" path 'null))
(t (signal-state-type-error "get" path (type-of state))))))

;; Example usage in defcomponent validation:
(defun validate-component-option (option value component-name)
(unless (valid-component-option-p option value)
(error-with-context
'defcomponent-error
:component-type component-name
:macro-arg option
:validation-type "invalid-option"
:context (format nil "Invalid value for option ~A: ~A" option value)
:suggestions (suggest-fixes
(format nil "Valid options for ~A are: ~A"
option (valid-options-for option))
"Check the defcomponent documentation for valid options"
"Ensure values are of the correct type"))))
|#
