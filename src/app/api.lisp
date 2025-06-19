(uiop:define-package #:elmtui.app.api
  (:use #:cl)
  (:import-from :log4cl #:log-debug #:log-error #:log-info)
  (:import-from #:bordeaux-threads #:mailbox) 
  (:import-from #:elmtui.core.globals #:*applications* #:*dsl-type-to-component-class*)
  (:import-from :elmtui.core.event-channels
   :event-channel)
  (:export #:defapplication
           #:run-application

           #:get-component-instance
           #:instantiate-component-from-dsl
           #:register-dsl-component-type #:get-component-class-for-dsl-type
           #:process-command-default #:render-view-default #:read-event-default
           #:app-config #:app-config-message-queue #:app-config-command-processor-fn #:app-config-renderer-fn
           #:app-config-name #:app-config-root-component-dsl #:app-config-initial-state-plist
           #:app-config-update-fn-sym #:app-config-view-fn-sym #:app-config-subscriptions-fn-form
           #:validate-platform-options))

(in-package #:elmtui.app.api)

;;; ===================================================================
;;; INTERFACE SECTION - Public API declarations
;;; ===================================================================

;; Application configuration structure
(defstruct app-config
  (name nil :type symbol :read-only t)
  (root-component-dsl nil :type list :read-only t)
  (initial-state-plist nil :type list :read-only t)
  (update-fn-sym nil :type symbol :read-only t)
  (view-fn-sym nil :type symbol :read-only t)
  (subscriptions-fn-form nil :type (or symbol list) :read-only t)
  (command-processor-fn nil :type (or symbol function) :read-only t)
  (message-queue (error "Message queue must be provided.") :type event-channel :read-only t)
  (renderer-fn nil :type (or symbol function) :read-only t))

;; Generic function signatures with improved type declarations
(declaim (ftype (function (list t) t) get-component-instance))
(defgeneric get-component-instance (id-path state)
  (:documentation "Retrieve a component instance by its ID path in the application context.")
  )

(declaim (ftype (function (t &key (:backend-type keyword) (:platform-options list)) t) run-application))
(defgeneric run-application (app-spec &key backend-type platform-options)
  (:documentation "Run the application with the given app-spec and platform options.")
  )

(declaim (ftype (function (t t &key (:id-path list)) t) process-command-default))
(defgeneric process-command-default (command state &key id-path)
  (:documentation "Default command processing function. Can be overridden by specific applications.")
  )

(declaim (ftype (function (t t &key (:id-path list)) t) render-view-default))
(defgeneric render-view-default (view state &key id-path)
  (:documentation "Default view rendering function. Can be overridden by specific applications.")
  )

(declaim (ftype (function (t t &key (:id-path list)) t) read-event-default))
(defgeneric read-event-default (event state &key id-path)
  (:documentation "Default event reading function. Can be overridden by specific applications.")
  )

(declaim (ftype (function (list list) t) instantiate-component-from-dsl))

(declaim (ftype (function ((or symbol keyword)) (or null symbol)) get-component-class-for-dsl-type))

(declaim (ftype (function ((or symbol keyword) symbol) t) register-dsl-component-type))

(declaim (ftype (function (symbol list) t) validate-platform-options))

;;; ===================================================================
;;; IMPLEMENTATION SECTION
;;; ===================================================================

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
  (declare (type list dsl id-path))
  (log-debug "Attempting to instantiate component from DSL.~%  DSL: ~S~%  ID-PATH: ~S" dsl id-path)
  (let* ((dsl-type (first dsl))
         (component-class (get-component-class-for-dsl-type dsl-type)))
    (log-debug "DSL Type: ~S, Resolved Component Class: ~S" dsl-type component-class)
    (if component-class
        (let ((instance (make-instance component-class :id id-path)))
          (log-info "Successfully instantiated component of type ~S with ID ~S."
                    dsl-type id-path)
          (log-debug "Instantiated instance: ~A" instance)
          instance)
        (progn
          (log-error "Failed to instantiate component: No component class found for DSL type: ~S. DSL: ~S, ID-PATH: ~S"
                     dsl-type dsl id-path)
          (error "No component class found for DSL type: ~a" dsl-type)))))

(defun get-component-class-for-dsl-type (dsl-type)
  "Retrieve the component class registered for a given DSL type."
  (declare (type (or symbol keyword) dsl-type))
  (let* ((keyword-dsl-type (intern (symbol-name dsl-type) :keyword))
         (class (gethash keyword-dsl-type *dsl-type-to-component-class*)))
    (if class
        (progn
          (log-debug "Found component class ~S for DSL type ~S." class keyword-dsl-type)
          class)
        (progn
          (log-error "No component class registered for DSL type: ~S" keyword-dsl-type)
          nil))))

(defun register-dsl-component-type (dsl-type class-name)
  "Registers a component class for a given DSL type keyword."
  (declare (type (or symbol keyword) dsl-type) (type symbol class-name))
  (setf (gethash (intern (symbol-name dsl-type) :keyword) *dsl-type-to-component-class*) class-name)
  (log-info "Registered DSL type ~S with class ~S." dsl-type class-name))

(defun validate-platform-options (platform platform-options)
  "Validate PLATFORM-OPTIONS for the given PLATFORM, signalling an error on invalid keys."
  (declare (type symbol platform) (type list platform-options))
  (check-type platform-options list)
  (dolist (key (loop for (k v) on platform-options by #'cddr collect k))
    (unless (member key '(:initial-terminal-dimensions
                          :initial-cursor-position
                          :input-mode
                          :enable-mouse-support
                          :disable-mouse-support
                          :timeout
                          :motion-events-p)
                    :test #'eq)
      (error "Invalid platform option ~S for platform ~S" key platform))))
