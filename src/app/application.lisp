;;;; DEFAPPLICATION —== elmtui/app/defapplication.lisp ==
;;;; DEFAPPLICATION — robust, zero-runtime-deps version
;;;; Place this file somewhere ASDF can find it (e.g. src/app/).

(uiop:define-package
  #:elmtui.app
  (:use #:cl)
  (:import-from #:log4cl
    #:log-info #:log-warn)
  (:import-from #:elmtui.app.system-events
    #:make-app-shutdown-system-event
    #:make-terminal-resized-system-event)
  (:import-from #:elmtui.core.globals          :*applications*)
  (:import-from #:elmtui.utils                 #:ensure-keyword
    #:coerce-fn)
  (:import-from #:cl-events.channel #:make-channel)
  (:import-from #:cleve-elm.core.event-channels #:make-message-channel )
  (:import-from #:elmtui.core.event-types #:key-event #:key-event-key #:key-event-char)
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
    #:get-component-instance)
  (:import-from #:elmtui.state.api                 #:merge-patches
    #:update-result
    #:ur-handled
    #:ur-patches
    #:ur-commands
    #:make-state)
  (:import-from #:elmtui.state.transactions
    #:apply-patches)
  (:import-from #:elmtui.ui.api                #:init #:view #:initialize-components-from-dsl
    #:instantiate-component-from-dsl)
  (:import-from #:elmtui.ui.widgets.root-viewport #:root-viewport)
  (:import-from #:elmtui.keymaps
    #:add-keybinding
    #:define-keymap
    #:register-keymap
    #:define-keymap-context
    #:process-key-event)
  (:export #:defapplication #:make-app-config #:get-component-instance
    #:register-message-binding #:define-widget-keymap))

(in-package #:elmtui.app)

;;; ---------------------------------------------------------------------------
;;; Helper utilities (compile-time)
;;; ---------------------------------------------------------------------------

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun dispatch-to-root (msg state root-id)
    "Deliver MSG to the component tree rooted at ROOT-ID.
   Returns two values: PATCHES and COMMANDS."

    (let* ((id-path (list :components root-id))
            (root    (elmtui.app.api:get-component-instance id-path state)))
      (log-info "Dispatching message ~S to root component ~A with id-path ~S"
        msg root-id id-path)
      (if (null root)
        (progn
          (log-warn "Root component ~A not found – message dropped: ~S"
            root-id msg)
          (values nil nil))
        (let ((raw-result (multiple-value-list
                            (elmtui.ui.api:update root msg state :id-path id-path))))
          (cond
            ((and raw-result
                  (= (length raw-result) 1)
                  (typep (first raw-result) 'update-result))
             (values (ur-patches (first raw-result))
                     (ur-commands (first raw-result))))
            ((>= (length raw-result) 2)
             (values (first raw-result) (second raw-result)))
            (t
             (log-warn "Component ~A returned unexpected update result: ~S"
               root-id raw-result)
             (values nil nil)))))))




  (defun maybe-wrap-with-root-viewport (dsl
                                         &key (root-id :root-viewport)
                                         ;; (term-size  '(1 1))
                                         ;; (cursor-pos '(1 1))
                                         )
    "Return DSL guaranteed to contain a :ROOT-VIEWPORT node even if DSL
   arrives quoted (i.e. (QUOTE …) or '…).

DSL cases handled:

  ┌───────────────────────────┬────────────────────────────┐
  │ Input (car DSL)           │ Result                     │
  ├───────────────────────────┼────────────────────────────┤
  │ :ROOT-VIEWPORT            │ DSL (unchanged)            │
  │ :VIEWPORT                 │ tag promoted to root       │
  │ any other keyword         │ wrapped in root viewport   │
  │ QUOTE                     │ quote preserved, inner DSL │
  │                           │ processed as above         │
  │ not a keyword list        │ DSL (unchanged)            │
  └───────────────────────────┴────────────────────────────┘"
    ;; Local helper that builds a fresh :root-viewport node
    (labels ((%wrap (inner)
               `(:root-viewport
                  :id ,root-id
                  ;; :initial-terminal-dimensions ,term-size
                  ;; :initial-cursor-pos          ,cursor-pos
                  :children                    ,inner)))
      (cond
        ((null dsl) nil)
        ;; ───────────────────────────────────────────────────────────────
        ;; ❶  Quoted input – unwrap, process, then re‑quote
        ;; ───────────────────────────────────────────────────────────────
        ((and (consp dsl) (eq (first dsl) 'quote))
          (let* ((inner   (second dsl))
                  (rewrote (maybe-wrap-with-root-viewport inner
                             :root-id root-id)))
                                        ;:term-size term-size
                                        ;:cursor-pos cursor-pos
            `(quote ,rewrote)))

        ;; ───────────────────────────────────────────────────────────────
        ;; ❷  Non‑component data – leave untouched
        ;; ───────────────────────────────────────────────────────────────
        ((not (and (consp dsl) (keywordp (first dsl))))
          dsl)

        ;; ───────────────────────────────────────────────────────────────
        ;; ❸  Already a root viewport
        ;; ───────────────────────────────────────────────────────────────
        ((eq (first dsl) :root-viewport)
          dsl)

        ;; ───────────────────────────────────────────────────────────────
        ;; ❹  Plain viewport – promote to root
        ;; ───────────────────────────────────────────────────────────────
        ((eq (first dsl) :viewport)
          (cons :root-viewport (rest dsl)))

        ;; ───────────────────────────────────────────────────────────────
        ;; ❺  Any other component – wrap
        ;; ───────────────────────────────────────────────────────────────
        (t (%wrap dsl)))))
  ;; (defun maybe-wrap-with-root-viewport (dsl &key (root-id :root-viewport)
  ;;                                             (term-size '(1 1))
  ;;                                             (cursor-pos '(1 1)))
  ;;   (log-info "maybe-wrap-with-root-viewport called with term-size: ~A, cursor-pos: ~A if? ~A 2 ~A 3 ~A 4 ~A"
  ;;             dsl root-id
  ;;             (consp dsl)
  ;;             `(first ,dsl)
  ;;             (keywordp `(first ,dsl))
  ;;             (and (consp dsl) (keywordp (first dsl))))
  ;;   (let ((w `(list :root-viewport :id ,root-id
  ;;                                  :initial-terminal-dimensions ,'term-size
  ;;                                  :initial-cursor-pos ,'cursor-pos
  ;;                                  :children ,dsl))
  ;;         (type `(first ,dsl))
  ;;         (props `(rest ,dsl)))
  ;;     (log-info "Type ~A Props ~A"
  ;;               type props)
  ;;     (if (and (consp dsl) (keywordp (first dsl)))

  ;;         (cond ((eq type :root-viewport) dsl)
  ;;               ((eq type :viewport)
  ;;                `(:root-viewport ,@props))
  ;;               (t
  ;;                w
  ;;                ;; `(list :root-viewport :id ,root-id
  ;;                ;;                       :initial-terminal-dimensions ,,'term-size
  ;;                ;;                       :initial-cursor-pos ,,'cursor-pos
  ;;                ;;                       :children ,dsl)
  ;;                ))
  ;;         dsl)))
  ;;dsl
  ;; `(list :root-viewport :id ,root-id
  ;;                       :initial-terminal-dimensions ',term-size
  ;;                       :initial-cursor-pos ',cursor-pos
  ;;                       :children ,dsl)))
  ;; dsl))
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
  Returns a function object or lambda as-is.
For a symbol/quoted symbol, returns the symbol for later resolution."
    (cond
      ((and (consp val) (eq (car val) 'lambda))
        val) ;;
      ((functionp val)
        val) ;;
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

;; (defun initialize-components-from-dsl (dsl)
;;   "Recursively traverses a component DSL, instantiates components,
;;    and returns the accumulated patches and commands."
;;   (let ((patches nil)
;;         (commands nil))
;;     (labels ((process-node (node parent-id-path)
;;                (when (and (consp node) (keywordp (car node)))
;;                  (destructuring-bind (component-type &rest component-props) node
;;                    (declare (ignore component-type))
;;                    (let ((component-id (getf component-props :id)))
;;                      (when component-id
;;                        (let* ((current-id-path (append parent-id-path (list component-id)))
;;                               (full-id-path `(:components ,@current-id-path))
;;                               (component-instance (instantiate-component-from-dsl node full-id-path)))
;;                          (multiple-value-bind (instance init-patches init-commands)
;;                              (apply #'init component-instance :id-path full-id-path component-props)
;;                            (declare (ignore instance))
;;                            (setf patches (nconc patches init-patches))
;;                            (setf commands (nconc commands init-commands)))
;;                          (dolist (child (getf component-props :children))
;;                            (process-node child current-id-path)))))))))
;;       (process-node dsl '()))
;;     (values patches commands)))

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
                                        ; Should be the DSL form itself
              (root-vp-id (%kw (%required kw-plist :root-viewport-id name)))
              (root-dsl   `,(maybe-wrap-with-root-viewport
                              (%required kw-plist :root-component-dsl name)
                              :root-id root-vp-id))
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
              (wrapped-view-fn-sym (intern (format nil "WRAPPED-VIEW-~A" name)))
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
           ;; Generated WRAPPED VIEW function
           ;; --------------------------------------------------------------
           (defun ,wrapped-view-fn-sym (model)
             (maybe-wrap-with-root-viewport
               (funcall ',view-fn* model)
               :root-id ',root-vp-id))

           ;; --------------------------------------------------------------
           ;; Register config object
           ;; --------------------------------------------------------------
           (setf (gethash ',name *applications*)
             (make-app-config
               :name ',name
               :root-component-dsl ,root-dsl
               :initial-state-plist ,state
               :update-fn-sym ',update-fn*
               :view-fn-sym   ',wrapped-view-fn-sym
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
            (let* ((app-state (make-state :initial (alexandria:plist-hash-table ,initial-state-plist))))
               (multiple-value-bind (patches commands)
                 (initialize-components-from-dsl
                   ;; (maybe-wrap-with-root-viewport
                   ,root-dsl)
                 ;; :root-id ,root-vp-id
                 ;; :term-size initial-terminal-dimensions
                 ;; :cursor-pos initial-cursor-position))
                 ;; (format t "~A ~A~%" app-state patches)
                 (apply-patches app-state patches)
                 (values app-state commands))))


           ;; --------------------------------------------------------------
           ;; ❸ Generated MESSAGE PROCESSOR
           ;; Name: PROCESS-MESSAGE-<app-name>
           ;; --------------------------------------------------------------
           ;; (defun ,proc-fn-sym (state msg)
           ;;   (let* ((update-result
           ;;            (funcall (symbol-function ',update-fn*) msg state)))
           ;;     (unless (typep update-result 'update-result)
           ;;       (error "~A update function (~S) must return UPDATE-RESULT, got: ~S"
           ;;              ',name ',update-fn* update-result))
           ;;     (unless (ur-handled update-result)
           ;;       (let* ((root-component
           ;;               (instantiate-component-from-dsl
           ;;              ,root-dsl
           ;;              :id-path '(:components ,(elmtui.ui.api:root-viewport-id ,root-vp-id))))
           ;;              (root-component-response ())
           ;;         (log-info "Root component response: ~S" root-component-response)
           ;;               (merge-patches (ur-patches update-result)
           ;;                               (dispatch-to-root msg (merge-patches model app-patches)))
           ;;       )
           ;;     (elmtui.state.transactions:apply-patches state (ur-patches update-result))
           ;;     (values state (ur-commands update-result))))
           (defun ,proc-fn-sym (msg state)
             (let ((cfg (gethash ',name *applications*)))
               (cond
                 ;; -------------------------------------------------------------
                 ;; Handle raw key events by dispatching to the keymap system
                 ;; -------------------------------------------------------------
                 ((typep msg 'key-event)
                   (flet ((dispatch (new-msg)
                            (elmtui.core.event-channels:send-event
                              (app-config-message-queue cfg) new-msg)))
                     (let ((handled (process-key-event msg
                                      nil ; focus-manager placeholder
                                      :app-state state
                                      :dispatch-fn #'dispatch)))
                       (if handled
                         (values state nil) ; Event consumed by keymap system
                         ;; If not handled, fall through to the component tree
                         (multiple-value-bind (comp-patches comp-cmds)
                           (dispatch-to-root msg state ',root-vp-id)
                           (apply-patches state comp-patches)
                           (values state comp-cmds))))))

                 ;; -------------------------------------------------------------
                 ;; Handle all other messages via the app's update function
                 ;; -------------------------------------------------------------
                 (t
                   (let* ((ur (elmtui.state.api:invoke-update
                                (%normalize-fn ',update-fn* nil nil)
                                msg
                                state)))
                     (unless (typep ur 'update-result)
                       (error "~A update function (~S) must return UPDATE-RESULT, got: ~S"
                         ',name ',update-fn* ur))

                     (multiple-value-bind (comp-patches comp-cmds)
                       (if (ur-handled ur)
                         (values nil nil)
                         (dispatch-to-root msg state ',root-vp-id))

                       (let* ((all-patches (nconc (ur-patches ur) comp-patches))
                               (all-cmds    (nconc (ur-commands ur) comp-cmds)))
                        (apply-patches state all-patches)
                         (values state all-cmds))))))))
           ;; --------------------------------------------------------------
           ;; RUN-<app>
           ;; --------------------------------------------------------------
           (defun ,run-fn-sym (&key (platform :tty) platform-options
                                &allow-other-keys)
             (let* ((cfg (gethash ',name *applications*))
                     (app-spec-for-driver
                       (list :name ',name
                         :init-fn #',init-fn-sym
                         :update-fn #',proc-fn-sym
                         :view-fn (symbol-function (app-config-view-fn-sym cfg))
                         :subscriptions-fn (app-config-subscriptions-fn-form cfg)
                         :command-processor-fn (app-config-command-processor-fn cfg)
                         :message-queue (app-config-message-queue cfg)
                         :root-viewport-id ,root-vp-id)))
               (elmtui.app.api:run-application
                 app-spec-for-driver
                 :backend-type platform
                 :platform-options (append platform-options ,other-keys))))
           ',name)))))

;;; ---------------------------------------------------------------------------
;;; Keymap glue helpers
;;; ---------------------------------------------------------------------------

(defun register-message-binding (km key-string msg &key description)
  "Sugar: add a :message binding that emits MSG list."
  (add-keybinding km key-string :target msg
    :description description))

(defmacro define-widget-keymap (name &body bindings)
  "DSL = DEFINE-KEYMAP + automatic registration + context."
  `(progn
     (define-keymap ,name ,@bindings)
     (register-keymap ',name ,name)
     (define-keymap-context ,(intern (format nil "~A-CTX" (symbol-name name)))
       () ,name)))
;;; ---------------------------------------------------------------------------
;;; Quick manual demo & FiveAM tests unchanged … (omitted for brevity)
;;; ---------------------------------------------------------------------------
;;; ---------------------------------------------------------------------------
;;; Quick manual demo & FiveAM tests unchanged … (omitted for brevity)
;;; ---------------------------------------------------------------------------



;;; Inline demo definitions removed to reduce load time.

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
;;   (test state-initialization
;;     (eval '(defapplication my-state-test-app
;;              :root-component-dsl `(:container :id :main)
;;              :root-viewport-id :my-root
;;              :initial-state-plist '(:foo "bar")))
;;     (multiple-value-bind (state commands)
;;         (initialize-app-state-my-state-test-app)
;;       (declare (ignore commands))
;;       (is (typep state 'elmtui.state:application-state))
;;       (is (string= "bar" (elmtui.state:get-path '(:foo) state)))
;;       (is (not (null (elmtui.state:get-path '(:components :my-root) state))))
;;       (is (eq :container (elmtui.state:get-path '(:components :my-root :main :type) state)))
;;       (is (eq :main (elmtui.state:get-path '(:components :my-root :main :id) state)))))
;;   (defun run-tests () (run! 'sanity)))
