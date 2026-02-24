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
           #:get-component-instance
           #:process-command-default #:render-view-default #:read-event-default
           #:app-config #:app-config-message-queue #:app-config-command-processor-fn #:app-config-renderer-fn
           #:app-config-name #:app-config-root-component-dsl #:app-config-initial-state-plist
           #:app-config-update-fn-sym #:app-config-view-fn-sym #:app-config-subscriptions-fn-form
           #:app-config-binary-options #:app-config-cli-options #:app-config-configure-fn
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
  (update-fn-sym nil :type (or symbol function list) :read-only t)
  (view-fn-sym nil :type (or symbol function list )
                   :read-only t)
  (subscriptions-fn-form nil :type (or symbol list) :read-only t)
  (command-processor-fn nil :type (or symbol function) :read-only t)
  (message-queue (error "Message queue must be provided.") :type event-channel :read-only t)
  (renderer-fn nil :type (or symbol function) :read-only t)
  (binary-options nil :type (or null list) :read-only t)
  (cli-options nil :type list :read-only t)
  (configure-fn nil :type (or null symbol function) :read-only t))

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
