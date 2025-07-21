(uiop:define-package #:elmtui.app.api
  (:use #:cl)
  (:import-from :log4cl #:log-debug #:log-error #:log-info)
  (:import-from #:bordeaux-threads #:mailbox) 
  (:import-from #:elmtui.core.globals #:*applications* #:*dsl-type-to-component-class*)
  (:import-from :elmtui.api #:get-component-class-for-dsl-type)

  (:import-from #:elmtui.ui.api #:instantiate-component-from-dsl)
  (:import-from :elmtui.core.event-channels
   :event-channel)
  (:import-from :elmtui.state :get-path)
  (:export #:defapplication
           #:with-temporary-dsl-component-registry
           #:run-application
           #:registered-dsl-component-p
           #:get-component-instance
           #:register-dsl-component-type #:get-component-class-for-dsl-type
           #:process-command-default #:render-view-default #:read-event-default
           #:app-config #:app-config-message-queue #:app-config-command-processor-fn #:app-config-renderer-fn
           #:app-config-name #:app-config-root-component-dsl #:app-config-initial-state-plist
           #:app-config-update-fn-sym #:app-config-view-fn-sym #:app-config-subscriptions-fn-form
           #:validate-platform-options
           #:clear-dsl-component-registry))

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
;;(declaim (ftype (function (list t) t) get-component-instance))
(defun %kw (x)
  (etypecase x
    (null     nil)
    (keyword  x)
    (symbol   (intern (string-upcase x) "KEYWORD"))
    (string   (intern (string-upcase x) "KEYWORD"))))
(defgeneric get-component-instance (id-path state)
  (:method ((id-path list) (state elmtui.tea-state.api:application-state))
    "Retrieve a component instance from STATE by following ID-PATH."
    (let* ((path-keys (if (eq :components (car id-path))
                          (rest id-path)
                          id-path))
           (components-root (get-path :components state))
           ;; (id-path (if (listp id-path)
           ;;              (if (eql (first id-path) :components)
           ;;                  (rest id-path)
           ;;                  id-path)
           ;;              (list :components id-path)))
           (component-state (get-path path-keys components-root)
                            ;; (reduce (lambda (ht key)
                            ;;           (when (hash-table-p ht)
                            ;;             (gethash key ht)))
                            ;;         path-keys
                            ;;         :initial-value components-root)
                            ))
      (if (and (hash-table-p component-state) (gethash :type component-state))
          (let ((component-class
                  (get-component-class-for-dsl-type
                   (gethash :type component-state))))
            (when component-class
              (make-instance component-class :id (gethash :id component-state))))
          (error
           (format
            nil
            ">get-component-instance[list state]: Component[~S] not found(compt-state: ~A~%)"
            id-path component-state))))))

(defmethod get-component-instance ((id-path t) (state t))
  "Retrieve a component instance by ID path symbol."
  (let ((idp
          (if (listp id-path)
              (mapcar #'%kw id-path)
              (list :components (%kw id-path)))))
    (when (null idp)
      (log-error "Invalid ID path: ~S" id-path)
      (error "Invalid ID path: ~S" id-path))
    (get-component-instance idp state)))
;; (log-info "Retrieving ~A~%" idp)
;; (unless (listp idp)
;;   (get-component-instance (list :components
;;                                 idp) state))))
;;(declaim (ftype (function (t &key (:backend-type keyword) (:platform-options list)) t) run-application))
(defgeneric run-application (app-spec &key backend-type platform-options)
  (:documentation "Run the application with the given app-spec and platform options."))

;;(declaim (ftype (function (t t &key (:id-path list)) t) process-command-default))
(defgeneric process-command-default (command state &key id-path)
  (:documentation "Default command processing function. Can be overridden by specific applications.")
  )

;;(declaim (ftype (function (t t &key (:id-path list)) t) render-view-default))
(defgeneric render-view-default (view state &key id-path)
  (:documentation "Default view rendering function. Can be overridden by specific applications.")
  )

;;(declaim (ftype (function (t t &key (:id-path list)) t) read-event-default))
(defgeneric read-event-default (event state &key id-path)
  (:documentation "Default event reading function. Can be overridden by specific applications.")
  )

(declaim (ftype (function (list list) t) instantiate-component-from-dsl))

;;(declaim (ftype (function ((or symbol keyword)) (or null symbol)) get-component-class-for-dsl-type))

(declaim (ftype (function ((or symbol keyword) symbol) t) register-dsl-component-type))

(declaim (ftype (function (symbol list) t) validate-platform-options))

;;; ===================================================================
;;; IMPLEMENTATION SECTION
;;; ===================================================================

(defmethod instantiate-component-from-dsl (dsl id-path)
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
          (log-info "Successfully instantiated component of type ~S with ID-Path ~S."
                    dsl-type id-path)
          (log-debug "Instantiated instance: ~A" instance)
          instance)
        (progn
          (log-error "Failed to instantiate component: No component class found for DSL type: ~S. DSL: ~S, ID-PATH: ~S"
                     dsl-type dsl id-path)
          (error "No component class found for DSL type: ~a" dsl-type)))))

(defmethod get-component-class-for-dsl-type ((dsl-type list))
  "Retrieve the component class registered for a given DSL type."
  (when (null dsl-type)
    (log-error "DSL type is nil or empty. Cannot retrieve component class.")
    (error "DSL type cannot be nil or empty."))
  (get-component-class-for-dsl-type (first dsl-type)))


(defmethod get-component-class-for-dsl-type ((dsl-type symbol))
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
          (error (format nil "No component class registered for DSL type: ~S" keyword-dsl-type))))))

(defun register-dsl-component-type (dsl-type class-name)
  "Registers a component class for a given DSL type keyword."
  (declare (type (or symbol keyword) dsl-type) (type symbol class-name))
  (setf (gethash (intern (symbol-name dsl-type) :keyword) *dsl-type-to-component-class*) class-name)
  (log-info "Registered DSL type ~S with class ~S." dsl-type class-name))

(defun registered-dsl-component-p (dsl-type)
  "Check if a component class is registered for the given DSL type."
  (declare (type (or symbol keyword) dsl-type))
  (let ((keyword-dsl-type (intern (symbol-name dsl-type) :keyword)))
    (if (gethash keyword-dsl-type *dsl-type-to-component-class*)
        (progn
          (log-debug "Component class found for DSL type: ~S" keyword-dsl-type)
          t)
        (progn
          (log-debug "No component class registered for DSL type: ~S" keyword-dsl-type)))))

(defun clear-dsl-component-registry ()
  "Clears the DSL component registry. Useful for testing."
  (clrhash *dsl-type-to-component-class*))

(defmacro with-temporary-dsl-component-registry (&body body)
  "Executes BODY with a temporary DSL component registry.
   This is useful for testing purposes to avoid polluting the global registry."
  `(let ((*dsl-type-to-component-class* (make-hash-table :test 'equal)))
     ,@body))

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
