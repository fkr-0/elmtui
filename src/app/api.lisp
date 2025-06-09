(uiop:define-package #:elmtui.app.api
  (:use #:cl)
  (:import-from :log4cl #:log-debug #:log-error #:log-info) ; Added for logging
  (:import-from #:elmtui.core.globals #:*applications* #:*dsl-type-to-component-class*)
  ;; (:import-from #:elmtui.platform.driver #:run-application) ; Import for platform driver
  (:export #:defapplication
           #:run-application

           #:get-component-instance
           #:instantiate-component-from-dsl
           ;; #:run-application ; This is now achieved by run-<app-name>
           #:register-dsl-component-type #:get-component-class-for-dsl-type
           #:get-component-instance
           #:process-command-default #:render-view-default #:read-event-default ; These are defaults, can be overridden
           #:app-config #:app-config-message-queue #:app-config-command-processor-fn #:app-config-renderer-fn
           ))

(in-package #:elmtui.app.api)
(defstruct app-config
  (name nil :type symbol :read-only t)
  (root-component-dsl nil :type list :read-only t)
  (initial-state-plist nil :type list :read-only t)
  (update-fn-sym nil :type symbol :read-only t)
  (view-fn-sym nil :type symbol :read-only t)
  (subscriptions-fn-form nil :type function)
  (command-processor-fn nil :type (or symbol function) :read-only t)
  (message-queue nil :read-only t) ; Consider a more specific type if available
  (renderer-fn nil :type (or symbol function) :read-only t))

(defgeneric get-component-instance (id-path state)
  (:documentation"Retrieve a component instance by its ID path in the application context."))
(defgeneric run-application
    (app-spec
     &key backend-type
       ;; Pass through platform options which might include tty-path, initial dims, etc.
       platform-options)
  ;; Canvas options for run-application are less relevant now, driver gets from root-vp
  (:documentation "Run the application with the given app-spec and platform options.")
  )

(defgeneric process-command-default (command state &key id-path)
  (:documentation "Default command processing function. Can be overridden by specific applications."))

(defgeneric render-view-default (view state &key id-path)
  (:documentation "Default view rendering function. Can be overridden by specific applications."))

(defgeneric read-event-default (event state &key id-path)
  (:documentation "Default event reading function. Can be overridden by specific applications."))

(defun instantiate-component-from-dsl (dsl id-path)
  "Instantiates a component instance from its Domain Specific Language (DSL) representation.

This function serves as a bridge between the declarative component definitions
used in the application's view logic and the actual Common Lisp component objects.

Args:
  dsl (list): The DSL form representing the component.
              Example: '(my-widget-type :property1 value1 :child (...))
              The first element of the list is the DSL type identifier.
  id-path (list, optional): A list of keywords or symbols forming a unique path
                            to this component instance within the application's
                            state tree. This ID is passed to the component's
                            constructor. Example: '(:components :main-panel :button-1)

Returns:
  An instance of the component class corresponding to the DSL type.

Signals:
  An error if no component class is registered for the given DSL type.

Workflow:
  1. Extracts the DSL type from the `dsl` form.
  2. Looks up the corresponding Lisp class using `get-component-class-for-dsl-type`.
  3. If a class is found, creates an instance of it using `make-instance`,
     passing `id-path` (as :id) and the original `dsl` form (as :dsl)
     as initialization arguments.
  4. If no class is found, signals an error."
  (log-debug "Attempting to instantiate component from DSL.~%  DSL: ~S~%  ID-PATH: ~S" dsl id-path)
  (let* ((dsl-type (first dsl))
         (component-class (get-component-class-for-dsl-type dsl-type)))
    (log-debug "DSL Type: ~S, Resolved Component Class: ~S" dsl-type component-class)
    (if component-class
        (let ((instance (make-instance component-class :id id-path :dsl dsl)))
          (log-info "Successfully instantiated component of type ~S with ID ~S."
                    dsl-type id-path)
          (log-debug "Instantiated instance: ~A" instance)
          instance)
        (progn
          (log-error "Failed to instantiate component: No component class found for DSL type: ~S. DSL: ~S, ID-PATH: ~S"
                     dsl-type dsl id-path)
          (error "No component class found for DSL type: ~a" dsl-type)))))


(defun get-component-class-for-dsl-type (dsl-type)
  "Retrieve the component class registered for a given DSL type.
   DSL-TYPE is a keyword or symbol representing the DSL type of the component."
  (let ((class (getf *dsl-type-to-component-class* dsl-type)))
    (if class
        (progn
          (log-debug "Found component class ~S for DSL type ~S." class dsl-type)
          class)
        (progn
          (log-error "No component class registered for DSL type: ~S" dsl-type)
          nil))))

(defun register-dsl-component-type (dsl-type class-name)
  "Registers a component class for a given DSL type keyword.
   DSL-TYPE is a keyword or symbol representing the DSL type.
   CLASS-NAME is the name of the Lisp class that implements this component."
  (setf (getf *dsl-type-to-component-class* dsl-type) class-name)
  (log-info "Registered DSL type ~S with class ~S." dsl-type class-name)
  (export dsl-type class-name)) ; Ensure the DSL type and class are exported
