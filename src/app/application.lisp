;;;; DEFAPPLICATION —== elmtui/app/defapplication.lisp ==
;;;; DEFAPPLICATION — robust, zero-runtime-deps version
;;;; Place this file somewhere ASDF can find it (e.g. src/app/).

(uiop:define-package
    #:elmtui.app
  (:use #:cl)
  (:import-from #:elmtui.core.globals          :*applications*)
  (:import-from #:elmtui.utils                 #:ensure-keyword
                #:coerce-fn)
  (:import-from #:cleve-elm.channel #:make-channel )
  (:import-from #:cleve-elm.core.event-channels #:make-message-channel )
  (:import-from #:elmtui.app.api
                #:app-config
                #:make-app-config
                #:app-config-name
                #:app-config-message-queue
                #:app-config-command-processor-fn
                #:app-config-update-fn-sym
                #:app-config-view-fn-sym
                #:app-config-renderer-fn
                #:app-config-subscriptions-fn-form     ; <— newly imported
                #:instantiate-component-from-dsl
                #:get-component-instance)
  (:import-from #:elmtui.state                 #:merge-patches
                #:update-result
                #:ur-patches
                #:ur-commands)
  (:import-from #:elmtui.ui.api                #:init #:view)
  (:import-from #:elmtui.ui.widgets.root-viewport #:root-viewport)
  (:export #:defapplication #:make-app-config #:get-component-instance))

(in-package #:elmtui.app)

;;; ---------------------------------------------------------------------------
;;; Helper utilities (compile-time)
;;; ---------------------------------------------------------------------------

(eval-when (:compile-toplevel :load-toplevel :execute)
  ;; Coerce X → keyword, return NIL on NIL.
  (defun %kw (x)
    (etypecase x
      (null     nil)
      (keyword  x)
      (symbol   (intern (string-upcase x) "KEYWORD"))
      (string   (intern (string-upcase x) "KEYWORD"))))

  ;; Mandatory keyword fetch w/ compile-time error.
  (defun %required (plist key &optional (who 'defapplication))
    (or (getf plist key)
        (error (format nil "~A – missing required keyword argument ~S." who key))))

  ;; Split PLIST into KNOWN/REST portions.
  (defun %split-known-keys (plist known)
    (let ((kplist '())
          (rplist '()))
      (loop for (k v) on plist by #'cddr do
        (if (member k known)
            (progn (push k kplist) (push v kplist))
            (progn (push k rplist) (push v rplist))))
      (values (nreverse kplist) (nreverse rplist))))

  ;; Normalize function designators for macro keyword args.
  (defun %normalize-fn (val what app)
    "Accepts a symbol, quoted symbol, (function sym), lambda, or function object.
  Returns a function object or lambda as-is. For a symbol/quoted symbol, returns the symbol for later resolution."
    (cond
      ((and (consp val) (eq (car val) 'lambda))
       val)
      ((functionp val)
       val)
      ((symbolp val)
       val)
      ((and (consp val) (eq (car val) 'quote) (symbolp (cadr val)))
       (cadr val))
      ((and (consp val) (eq (car val) 'function) (symbolp (cadr val)))
       (cadr val))
      (t (error "DEFAPPLICATION ~S: ~A must be a symbol, quoted symbol, FUNCTION form, lambda, or function object – got: ~S"
                app what val)))))

                                        ; Default lambda if NIL is allowed

;;; ---------------------------------------------------------------------------
;;; Helper functions
;;; ---------------------------------------------------------------------------

(defun generate-child-id (parent-id child-suffix)
  "Generate a unique child ID based on parent ID and suffix."
  (intern (format nil "~A-~A" parent-id child-suffix) :keyword))

;;; ---------------------------------------------------------------------------
;;; Helper function to initialize components from DSL
;;; ---------------------------------------------------------------------------

(defun initialize-components-from-dsl (dsl app-state)
  "Recursively traverses a component DSL, instantiates components,
   and returns the accumulated patches and commands."
  (declare (ignorable app-state))
  (let ((patches nil)
        (commands nil))
    (labels ((process-node (node)
               (when (and (consp node) (keywordp (car node)))
                 (let* ((component-type (car node))
                        (component-props (cdr node))
                        (component-id (getf component-props :id)))
                   (declare (ignorable component-type))
                   (when component-id
                     (let* ((component-id-path `(:components ,component-id))
                            (component-instance (instantiate-component-from-dsl node component-id-path)))
                       (when component-instance
                         (multiple-value-bind (instance init-patches init-commands)
                             (apply #'init component-instance :id-path component-id-path component-props)
                           (declare (ignore instance))
                           (setf patches (nconc patches init-patches))
                           (setf commands (nconc commands init-commands))))))
                   (let ((children (getf component-props :children)))
                     (dolist (child children)
                       (process-node child)))))))
      (process-node dsl)
      (values patches commands))))

;;; ---------------------------------------------------------------------------
;;; The macro itself
;;; ---------------------------------------------------------------------------

(defmacro defapplication (name &rest args)
  "Define an ElmTUI application called NAME."
  (let ((known '(:root-component-dsl :initial-state-plist :initial-state-fn
                 :update-fn :view-fn :command-processor-fn
                 :subscriptions-fn :root-viewport-id :platform-options)))
    (multiple-value-bind (kw-plist other-keys) (%split-known-keys args known)
      (let* (;; Required
             (root-dsl   (%required kw-plist :root-component-dsl name)) ; Should be the DSL form itself
             (root-vp-id (%kw (%required kw-plist :root-viewport-id name)))
             ;; Optional
             (initial-state-plist (getf kw-plist :initial-state-plist '()))
             (initial-state-fn (getf kw-plist :initial-state-fn nil))
             ;; Normalise FN designators to symbols
             (state (if initial-state-fn
                        `(funcall ,initial-state-fn)
                        initial-state-plist))
             (update-fn* (%normalize-fn (getf kw-plist :update-fn)
                                        ":update-fn" name))
             (view-fn*   (%normalize-fn (getf kw-plist :view-fn)
                                        ":view-fn" name))
             (cmd-proc-fn (%normalize-fn (coerce-fn (getf kw-plist :command-processor-fn))
                                         ":command-processor-fn" name))
             ;; Subscriptions: keep symbol | lambda | NIL, but handle lambda evaluation properly
             (subs-fn-form
               (let ((v (getf kw-plist :subscriptions-fn)))
                 (cond ((symbolp v) `',v) ; Quote symbol for later evaluation
                       ((and (consp v) (eq (car v) 'lambda)) `',v) ; Quote lambda form to store as cons
                       ;; ((null v)
                       ;;  ''(lambda (model) (declare (ignore model)) nil))
                       (t (error "DEFAPPLICATION ~S: :subscriptions-fn must be symbol or lambda – got: ~S"
                                 name v)))))
             ;; Auto-generated helper names
             (init-fn-sym (intern (format nil "INITIALIZE-APP-STATE-~A" name)))
             (proc-fn-sym (intern (format nil "PROCESS-MESSAGE-~A" name)))
             (run-fn-sym  (intern (format nil "RUN-~A" name)))
             ;; Warn about stray keywords
             (warn-list (loop for (k) on other-keys by #'cddr collect k)))
        `(progn
           ,@(when warn-list
               `((warn "DEFAPPLICATION ~S – unknown keyword(s): ~{~S~^, ~}"
                  ',name ',warn-list)))

           ;; --------------------------------------------------------------
           ;; Register config object
           ;; --------------------------------------------------------------
           (setf (gethash ',name *applications*)
                 (make-app-config
                  :name ',name
                  :root-component-dsl ,root-dsl
                  :initial-state-plist ,state
                  :update-fn-sym ',update-fn*
                  :view-fn-sym   ',view-fn*
                  :command-processor-fn ,cmd-proc-fn
                  :subscriptions-fn-form ,subs-fn-form
                  :message-queue (make-message-channel :capacity 20) ; Create proper event-channel
                  ))

           ;; --------------------------------------------------------------
           ;; ❷ Generated APP STATE INITIALIZER
           ;; Name: INITIALIZE-APP-STATE-<app-name>
           ;; Args: &key initial-terminal-dimensions initial-cursor-position &allow-other-keys
           ;; --------------------------------------------------------------
           (defun ,init-fn-sym (&key (initial-terminal-dimensions '(80 24))
                                  (initial-cursor-position '(0 0))
                                &allow-other-keys) ; Allow other platform-options
             (declare (ignorable initial-terminal-dimensions initial-cursor-position))
             (let* ((app-state (elmtui.state.api:make-application-state :data (elmtui.state.api:plist-to-app-state ,state))))
               (multiple-value-bind (patches commands)
                   (initialize-components-from-dsl ,root-dsl app-state)
                 (let ((final-state (elmtui.state.api:merge-patches app-state patches)))
                   (values final-state commands)))))


           ;; --------------------------------------------------------------
           ;; ❸ Generated MESSAGE PROCESSOR
           ;; Name: PROCESS-MESSAGE-<app-name>
           ;; --------------------------------------------------------------
           (defun ,proc-fn-sym (state msg)
             (let* ((update-result
                      (funcall (symbol-function ',update-fn*) msg state)))
               (unless (typep update-result 'update-result)
                 (error "~A update function (~S) must return UPDATE-RESULT, got: ~S"
                        ',name ',update-fn* update-result))
               (values (merge-patches state (ur-patches update-result))
                       (ur-commands update-result))))

           ;; --------------------------------------------------------------
           ;; RUN-<app>
           ;; --------------------------------------------------------------
           (defun ,run-fn-sym (&key (platform :terminal) platform-options
                               &allow-other-keys)
             (let* ((cfg           (gethash ',name *applications*))
                    (state-cell    (list nil)) ; Holds the current state
                    (msg-queue     (app-config-message-queue cfg)) ; Get the mailbox from app-config
                    (init-fn       #',init-fn-sym)
                    (proc-fn       #',proc-fn-sym)
                    (app-view-fn   (symbol-function
                                    (app-config-view-fn-sym cfg)))
                    (cmd-proc-fn   (app-config-command-processor-fn cfg))
                    (app-subs-form (app-config-subscriptions-fn-form cfg)))
               (declare (ignorable proc-fn))
               (labels
                   ((pinit ()
                      ;; Validate platform-options before initialization
                      (elmtui.app.api:validate-platform-options platform platform-options)
                      (multiple-value-bind (st init-cmds)
                          ;; Apply platform-options plist as keyword args to init-fn
                          (apply init-fn platform-options)
                        (setf (car state-cell) st)
                        (when cmd-proc-fn
                          (dolist (c init-cmds)
                            (funcall cmd-proc-fn c msg-queue st cfg)))
                        st)))
                 (pinit)
                 (let ((app-spec-for-driver
                         (list :name ',name
                               :init-fn #',init-fn-sym ; Pass the actual function
                               :update-fn #',proc-fn-sym ; Pass the actual function
                               :view-fn app-view-fn ; Pass the actual function
                               :subscriptions-fn app-subs-form ; Pass the form/lambda/symbol
                               :command-processor-fn cmd-proc-fn ; Pass the function/symbol
                               :message-queue msg-queue
                               :root-viewport-id ,root-vp-id)))
                   (elmtui.app.api:run-application
                    app-spec-for-driver ; 1st arg: the app configuration plist
                    :backend-type platform ; keyword arg
                    :platform-options platform-options))))) ; keyword arg
           ',name)))))
;;; ---------------------------------------------------------------------------
;;; Quick manual demo & FiveAM tests unchanged … (omitted for brevity)
;;; ---------------------------------------------------------------------------
;;; ---------------------------------------------------------------------------
;;; Quick manual demo & FiveAM tests unchanged … (omitted for brevity)
;;; ---------------------------------------------------------------------------



;;; ---------------------------------------------------------------------------
;;; ❼ Convenience runner – quick manual demo
;;; ---------------------------------------------------------------------------

(defparameter *dummy-root-dsl*
  '(elmtui.ui.widgets.label:label :id :root-label :text "Hello"))

(defun my-update-fn (msg state)
  (declare (ignore state))
  (format t "Update called with message: ~A~%" msg)
  (make-instance 'elmtui.state:update-result))

(defun my-view-fn (state)
  (declare (ignore state))
  (list :components
        (list :root-viewport :id :rv
                             :initial-terminal-dimensions (list 80 24)
                             :initial-cursor-position (list 0 0)
                             :initial-child-spec *dummy-root-dsl*)))

(defapplication my-test-app
  :root-component-dsl *dummy-root-dsl*
  :initial-state-plist (list :some-initial-state t)
  :update-fn 'my-update-fn
  :view-fn   'my-view-fn
  :subscriptions-fn (lambda (model)
                      (declare (ignore model))
                      (format t "Subs called~%")
                      nil)
  :root-viewport-id :rv-myid)

(defvar *application-modules* (make-hash-table :test 'eq)
  "A registry for application modules defined with defmodule.")

(defmacro defmodule (name &key state messages update view subscriptions
                            components dependencies exports)
  "Defines a reusable application module."
  `(progn
     ;; Define module messages
     ,@(when messages
         `((defmsg ,(intern (format nil "~A-MSG" name))
               (:docstring ,(format nil "Messages for ~A module" name))
               ,@messages)))

     ;; Register module
     (setf (gethash ',name *application-modules*)
           (list :state-schema ',state
                 :messages ',messages
                 :update ',update
                 :view ',view
                 :subscriptions ',subscriptions
                 :components ',components
                 :dependencies ',dependencies
                 :exports ',exports))

     ',name))

(defmacro defapplication-contracted (name &key root-dsl initial-state
                                            update view subscriptions
                                            message-schema validation-mode
                                            modules platform-options)
  "Enhanced defapplication with contract enforcement and modular architecture."
  (let ((app-msg-type (or message-schema
                          (intern (format nil "~A-MSG" name))))
        (update-fn-name (intern (format nil "~A-UPDATE" name)))
        (view-fn-name (intern (format nil "~A-VIEW" name)))
        (subs-fn-name (intern (format nil "~A-SUBSCRIPTIONS" name))))

    `(progn
       ;; Define application message schema
       ,@(when message-schema
           `((defmsg ,app-msg-type
                 (:docstring ,(format nil "Messages for ~A application" name))
                 ;; Include common application messages
                 AppInitialized
                 AppShutdown
                 (ModuleMessage :module keyword :message t)
                 (ComponentMessage :component keyword :message t)
                 ;; Custom messages from modules
                 ,@(mapcan (lambda (module)
                             (getf module :messages))
                           modules))))

       ;; Contract-enforced update function
       ,(ecase (or validation-mode :hybrid)
          (:flexible
           `(elmtui.contracts:defupdate-flexible ,update-fn-name (model message)
              ,@(if update (list update)
                    `((declare (ignore model message))
                      (values nil nil)))))
          (:typed
           `(elmtui.contracts:defupdate-typed ,update-fn-name (model message) ,app-msg-type
              ,@(if update (list update)
                    `((declare (ignore model message))
                      (values nil nil)))))
          (:hybrid
           `(elmtui.contracts:defupdate-hybrid ,update-fn-name (model message)
             :message-type ,app-msg-type
             ,@(if update (list update)
                   `((declare (ignore model message))
                     (values nil nil))))))

       ;; Contract-enforced view function
       (elmtui.contracts:defview ,view-fn-name (model)
         ,@(if view (list view)
               `(,root-dsl)))

       ;; Contract-enforced subscriptions
       (elmtui.contracts:defsubscriptions ,subs-fn-name (model)
         ,@(if subscriptions (list subscriptions)
               `((declare (ignore model)) nil)))

       ;; Standard defapplication with contract functions
       (defapplication ,name
         :root-component-dsl ,root-dsl
         :initial-state-plist ,initial-state
         :update-fn ',update-fn-name
         :view-fn ',view-fn-name
         :subscriptions-fn ',subs-fn-name
         :root-viewport-id ,(intern (format nil "~A-ROOT" name) :keyword)
         ,@platform-options)

       ;; Module integration
       ,@(mapcar (lambda (module)
                   `(integrate-module ',name ,module))
                 modules)

       ',name)))

;; (defmacro compose-application (name &key modules root-module platform-options)
;;   "Composes an application from multiple modules."
;;   (let ((combined-state (combine-module-states modules))
;;         (combined-messages (combine-module-messages modules))
;;         (combined-update (generate-module-router modules))
;;         (combined-view (generate-module-view-compositor modules root-module))
;;         (combined-subscriptions (combine-module-subscriptions modules)))

;;     `(defapplication-contracted ,name
;;        :root-dsl ,combined-view
;;        :initial-state ,combined-state
;;        :message-schema ,(intern (format nil "~A-MSG" name))
;;        :update ,combined-update
;;        :view ,combined-view
;;        :subscriptions ,combined-subscriptions
;;        :modules ,modules
;;        ,@platform-options)))

;;; ---------------------------------------------------------------------------
;;; FiveAM sanity tests
;;; ---------------------------------------------------------------------------

;; (eval-when (:load-toplevel :execute)
;;   (ql:quickload :fiveam)
;;   (defpackage #:elmtui.test.defapplication
;;     (:use #:cl #:fiveam #:elmtui.app))
;;   (in-package #:elmtui.test.defapplication)

;;   (def-suite sanity)
;;   (in-suite sanity)

;;   (test expansion
;;     (eval '(defapplication my-test-app
;;             :root-component-dsl *dummy-root-dsl*
;;             :root-viewport-id   :rv))
;;     (is (fboundp 'initialize-app-state-my-test-app))
;;     (is (fboundp 'process-message-my-test-app))
;;     (is (fboundp 'run-my-test-app)))

;;   (test missing-arg
;;     (is-error (macroexpand
;;                '(defapplication bad-app
;;                  :root-component-dsl *dummy-root-dsl*))))

;;   (defun run-tests () (run! 'sanity)))
