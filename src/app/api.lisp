(uiop:define-package #:elmtui.app.api
  (:use #:cl)
  (:import-from :log4cl #:log-debug #:log-error #:log-info)
  (:import-from #:bordeaux-threads #:mailbox)
  (:import-from #:elmtui.core.globals #:*applications*)
  (:import-from #:elmtui.ui.dsl-resolution #:resolve-dsl-type)
  (:import-from :elmtui.core.event-channels
   :event-channel)
  (:import-from :elmtui.state.api :get-path)
  (:import-from :cl-state.core :application-state)
  (:export #:defapplication
           #:run-application
           #:make-runtime-app-spec
           #:get-component-instance
           #:process-command-default #:render-view-default #:read-event-default
           #:app-config #:app-config-message-queue #:app-config-command-processor-fn #:app-config-renderer-fn
           #:app-config-name #:app-config-root-component-dsl #:app-config-initial-state-plist
           #:app-config-update-fn-sym #:app-config-view-fn-sym #:app-config-subscriptions-fn-form
           #:app-config-state-semantics
           #:app-config-binary-options #:app-config-cli-options #:app-config-configure-fn
           #:validate-platform-options
           #:get-cli-arg))

(in-package #:elmtui.app.api)

;;; ===================================================================
;;; INTERFACE SECTION - Public API declarations
;;; ===================================================================

;; Application configuration structure
(defstruct app-config
  (name nil :type symbol :read-only t)
  (root-component-dsl nil :type list :read-only t)
  (initial-state-plist nil :type list :read-only t)
  (update-fn-sym nil :type (or symbol function list) :read-only t)
  (view-fn-sym nil :type (or symbol function list )
                   :read-only t)
  (subscriptions-fn-form nil :type (or symbol list) :read-only t)
  (state-semantics :transactional
                   :type (member :transactional :strict-elm)
                   :read-only t)
  (command-processor-fn nil :type (or symbol function) :read-only t)
  (message-queue (error "Message queue must be provided.") :type event-channel :read-only t)
  (renderer-fn nil :type (or symbol function) :read-only t)
  (binary-options nil :type (or null list) :read-only t)
  (cli-options nil :type list :read-only t)
  (configure-fn nil :type (or null symbol function) :read-only t))

(setf (documentation 'app-config-state-semantics 'function)
      "Return the application's state commit semantics, either :TRANSACTIONAL or :STRICT-ELM.")

(defun make-runtime-app-spec (&key name init transition view subscriptions
                               command-processor message-queue root-viewport-id
                               (state-semantics :strict-elm) cli-args)
  "Build the canonical runtime application specification.

The normative runtime vocabulary is INIT and TRANSITION:

  INIT :: () -> (values MODEL COMMANDS)
  TRANSITION :: (MESSAGE MODEL) -> (values NEXT-MODEL COMMANDS)
  VIEW :: MODEL -> DSL
  SUBSCRIPTIONS :: MODEL -> SUBSCRIPTIONS

DEFAPPLICATION, the normative full application constructor for the next stable
major version, adapts its context/patch update callback into TRANSITION.
DEFTEA-APP remains the supported minimal direct-transition adapter for small and
pedagogical applications. Both lower through this function. The returned plist
retains the legacy internal :UPDATE-FN key because the platform driver consumes
that key, but new framework code should construct specs through this function
and speak in terms of transitions.

STATE-SEMANTICS must be :TRANSACTIONAL or :STRICT-ELM. A NIL SUBSCRIPTIONS value
is normalized to an empty subscription function."
  (unless (member state-semantics '(:transactional :strict-elm))
    (error "Invalid runtime state semantics ~S." state-semantics))
  (dolist (required `((:init ,init) (:transition ,transition) (:view ,view)))
    (unless (second required)
      (error "MAKE-RUNTIME-APP-SPEC requires ~S." (first required))))
  (let ((subscriptions* (or subscriptions
                            (lambda (model)
                              (declare (ignore model))
                              nil))))
    (list :name name
          :init-fn init
          :update-fn transition
          :view-fn view
          :subscriptions-fn subscriptions*
          :state-semantics state-semantics
          :command-processor-fn command-processor
          :message-queue message-queue
          :cli-args cli-args
          :root-viewport-id root-viewport-id)))

;; Generic function signatures with improved type declarations
;;(declaim (ftype (function (list t) t) get-component-instance))
(defun %kw (x)
  (etypecase x
    (null     nil)
    (keyword  x)
    (symbol   (intern (string-upcase x) "KEYWORD"))
    (string   (intern (string-upcase x) "KEYWORD"))))
(defgeneric get-component-instance (id-path state)
  (:method ((id-path list) (state application-state))
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
          (multiple-value-bind (component-class default-props)
              (resolve-dsl-type (gethash :type component-state))
            (declare (ignore default-props))
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

(defun get-cli-arg (state key &optional default)
  "Read CLI argument KEY from STATE at (:cli KEY), returning DEFAULT when absent."
  (let* ((k (%kw key))
         (marker (list :missing))
         (value (get-path (list :cli k) state marker)))
    (if (eq value marker) default value)))

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

(declaim (ftype (function (symbol list) t) validate-platform-options))

;;; ===================================================================
;;; IMPLEMENTATION SECTION
;;; ===================================================================

;;; NOTE: The old registry-based DSL resolution system has been replaced
;;; with a polymorphic system using CLOS generic functions (dsl-type).
;;; See src/ui/dsl-resolution.lisp for the new implementation.

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
