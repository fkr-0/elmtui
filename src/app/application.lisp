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
  (let ((patches nil)
        (commands nil))
    (labels ((process-node (node parent-path)
               (when (and (consp node) (symbolp (car node)))
                 (let* ((component-type (car node))
                        (component-props (cdr node))
                        (component-id (getf component-props :id))
                        (component-id-path `(:components ,component-id)))
                   (when component-id
                     ;; Instantiate the component using the API function
                     (let ((component-instance (elmtui.app.api:instantiate-component-from-dsl
                                                 node component-id-path)))
                       (when component-instance
                         (multiple-value-bind (instance init-patches init-commands)
                             (elmtui.ui.api:init component-instance
                                                 :id-path component-id-path
                                                 ;; Pass through any initial-* properties as initargs
                                                 :initial-state (getf component-props :initial-state)
                                                 :initial-text (getf component-props :initial-text)
                                                 :initial-count (getf component-props :initial-count)
                                                 :initial-title (getf component-props :initial-title)
                                                 :initial-data (getf component-props :initial-data)
                                                 :initial-child-specs (getf component-props :initial-child-specs)
                                                 :child-initial-state (getf component-props :child-initial-state))
                           (declare (ignore instance))
                           (setf patches (nconc patches init-patches))
                           (setf commands (nconc commands init-commands))))))
                   
                   ;; Process any nested components
                   (dolist (child (remove-if-not #'consp component-props))
                     (when (and (consp child) (consp (car child)))
                       (process-node (car child) component-id-path))))))
             
             (process-dsl-list (dsl-list)
               (when (consp dsl-list)
                 (if (keywordp (car dsl-list))
                     ;; Single component
                     (process-node dsl-list nil)
                     ;; List of components
                     (dolist (node dsl-list)
                       (when (consp node)
                         (process-node node nil)))))))
      
      (process-dsl-list dsl)
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
             (declare (ignorable initial-terminal-dimensions initial-cursor-position)) ; May not be used if root-dsl is complex
             (let ((state ,state) ; Initialize state from macro parameter
                   (patches nil)
                   (commands nil)
                   (rv-id ,root-vp-id) ; Use the required root-viewport-id
                   (rv-path (list :components ,root-vp-id)))

               ;; Instantiate the root-viewport component
               ;; The DSL for the root-viewport itself, including its initial child.
               (let* ((current-root-dsl ,root-dsl) ; root-dsl is from the outer let*
                      (rv-dsl-spec
                        `(root-viewport ; This is a literal symbol
                          :id ,rv-id
                          ;; Pass explicit initargs that root-viewport's init method expects
                          ;; :initial-terminal-dimensions ,initial-terminal-dimensions
                          ;; :initial-cursor-pos ,initial-cursor-position
                          ;; :initial-child-spec ,current-root-dsl
                          ;; Other props for root-viewport itself can be in its dsl if needed
                          :props (:anchor :below-cursor) ; Example: default anchor if not in platform-options
                          )))
                 (when rv-id
                   (let ((rv-inst (instantiate-component-from-dsl rv-dsl-spec rv-path)))
                     (when rv-inst
                       (log4cl:log-info "Initialized root viewport instance: ~A for app ~A" rv-inst ',name)
                       (log4cl:log-info "With DSL spec: ~A" rv-dsl-spec)
                       (multiple-value-bind (init-patches init-commands)
                           (elmtui.ui.api:init rv-inst
                                               :id-path rv-path
                                               :dsl ;; TODO use the actual dsl without root viewport, because
                                               ;; that makes it no valid plist
                                               (cdr rv-dsl-spec) ; Pass the dsl for the root-viewport
                                               ;; Pass options needed by root-viewport's init
                                               :initial-terminal-dimensions initial-terminal-dimensions
                                               :initial-cursor-pos initial-cursor-position
                                               :initial-child-spec current-root-dsl)
                         (setf patches (nconc patches init-patches))
                         (setf commands (nconc commands init-commands))
                         (log4cl:log-info "Root viewport initialized with patches: ~A and commands: ~A"
                                          patches commands)))
                     ;; Store the root viewport instance itself if needed (e.g., for direct access, though usually via get-component-instance)
                     ;; (setf state (merge-patches state (list (list rv-path rv-inst)))) ; Storing instance might be redundant if state is pure data
                     ))

                 ;; Initialize components from the root DSL
                 (multiple-value-bind (component-patches component-commands)
                     (initialize-components-from-dsl current-root-dsl state)
                   (setf patches (nconc patches component-patches))
                   (setf commands (nconc commands component-commands)))

                 ;; Merge initial state with patches from root viewport and component init
                 (setf state (merge-patches state patches))
                 (log4cl:log-info "Initial state after root viewport and component init: ~A" state)
                 (values state commands))))


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
;;     (eval '(elmtui.app:defapplication my-test-app
;;             :root-component-dsl *dummy-root-dsl*
;;             :root-viewport-id   :rv))
;;     (is (fboundp 'initialize-app-state-my-test-app))
;;     (is (fboundp 'process-message-my-test-app))
;;     (is (fboundp 'run-my-test-app)))

;;   (test missing-arg
;;     (is-error (macroexpand
;;                '(elmtui.app:defapplication bad-app
;;                  :root-component-dsl *dummy-root-dsl*))))

;;   (defun run-tests () (run! 'sanity)))
