;;;; DEFAPPLICATION —== elmtui/app/defapplication.lisp ==
;;;; DEFAPPLICATION — robust, zero-runtime-deps version
;;;; Place this file somewhere ASDF can find it (e.g. src/app/).

(uiop:define-package
    #:elmtui.app
  (:use #:cl)
  (:import-from #:elmtui.core.globals          :*applications*)
  (:import-from #:elmtui.utils                 :ensure-keyword)
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
  (:export #:defapplication))

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

  ;; Normalise “maybe-quoted” symbol designators.
  (defun %->symbol (val what app)
    "Return a *symbol* extracted from VAL or signal error.
WHAT is a human label (:update-fn etc.) for diagnostics."
    (cond
      ((symbolp val) val)
      ((and (consp val)                           ; (quote sym)
            (eq (car val) 'quote)
            (symbolp (cadr val)))
       (cadr val))
      ((and (consp val)                           ; (function sym)
            (eq (car val) 'function)
            (symbolp (cadr val)))
       (cadr val))
      ((and (consp val)                           ; inline lambda
            (eq (car val) 'lambda))
       ;; leave lambda form as-is – caller will compile it.
       val)
      (t (error "DEFAPPLICATION ~S: ~A must be a symbol, quoted symbol, FUNCTION form, or lambda – got: ~S"
                app what val)))))

;;; ---------------------------------------------------------------------------
;;; The macro itself
;;; ---------------------------------------------------------------------------

(defmacro defapplication (name &rest args)
  "Define an ElmTUI application called NAME."
  (let ((known '(:root-component-dsl :initial-state-plist
                 :update-fn :view-fn :command-processor-fn
                 :subscriptions-fn :root-viewport-id)))
    (multiple-value-bind (kw-plist other-keys) (%split-known-keys args known)
      (let* (;; Required
             (root-dsl   (%required kw-plist :root-component-dsl name))
             (root-vp-id (%kw (%required kw-plist :root-viewport-id name)))
             ;; Optional
             (initial-state  (getf kw-plist :initial-state-plist '()))
             ;; Normalise FN designators to symbols
             (update-fn* (%->symbol (getf kw-plist :update-fn)
                                    ":update-fn" name))
             (view-fn*   (%->symbol (getf kw-plist :view-fn)
                                    ":view-fn" name))
             (cmd-proc-fn (%->symbol (getf kw-plist :command-processor-fn)
                                     ":command-processor-fn" name))
             ;; Subscriptions: keep symbol | lambda | NIL
             (subs-fn-form
               (let ((v (getf kw-plist :subscriptions-fn)))
                 (cond ((or (symbolp v)
                            (and (consp v) (eq (car v) 'lambda))) v)
                       ((null v)
                        '(lambda (model) (declare (ignore model)) nil))
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
                  :initial-state-plist ,initial-state
                  :update-fn-sym ',update-fn*
                  :view-fn-sym   ',view-fn*
                  :command-processor-fn ,cmd-proc-fn
                  :subscriptions-fn-form ,subs-fn-form))

           ;; --------------------------------------------------------------
           ;; INITIALISE-APP-STATE
           ;; --------------------------------------------------------------
           (defun ,init-fn-sym (&key initial-terminal-dimensions
                                  initial-cursor-position)
             (let* ((state   (copy-tree ,initial-state))
                    (patches nil)
                    (cmds    nil)
                    (rv-id   ,root-vp-id) ; root-vp-id is from the outer let*
                    (rv-path (list :components rv-id))
                    (current-root-dsl ,root-dsl) ; root-dsl is from the outer let*
                    (rv-dsl-spec
                      `(root-viewport ; This is a literal symbol
                        :id ,rv-id    ; Splice in the value of lexical variable rv-id
                        :initial-terminal-dimensions
                        ,initial-terminal-dimensions ; Splice in the value of the function argument
                        :initial-cursor-pos ,initial-cursor-position ; Splice in the value of the function argument
                        :initial-child-spec  ,current-root-dsl)) ; Splice in the value of lexical variable current-root-dsl
                    (rv-inst (instantiate-component-from-dsl rv-dsl-spec rv-path)))
               (when rv-inst
                 (push (list (append rv-path '(:component-instance)) rv-inst)
                       patches)
                 (multiple-value-bind (_ init-patches init-commands)
                     (init rv-inst
                           :id-path rv-path
                           :initial-terminal-dimensions initial-terminal-dimensions
                           :initial-cursor-pos initial-cursor-position
                           :initial-child-spec ,root-dsl)
                   (declare (ignore _))
                   (setf patches (nconc patches init-patches))
                   (setf cmds    (nconc cmds    init-commands))))
               (values (merge-patches state patches) cmds)))

           ;; --------------------------------------------------------------
           ;; PROCESS-MESSAGE
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
                    (state-cell    (list nil))
                    (msg-queue     (app-config-message-queue cfg))
                    (init-fn       #',init-fn-sym)
                    (proc-fn       #',proc-fn-sym)
                    (app-view-fn   (symbol-function
                                    (app-config-view-fn-sym cfg)))
                    (cmd-proc-fn   (app-config-command-processor-fn cfg))
                    (app-subs-form (app-config-subscriptions-fn-form cfg)))
               (labels
                   ((pinit ()
                      (multiple-value-bind (st init-cmds)
                          (apply init-fn
                                 (append (list :initial-terminal-dimensions
                                               (getf platform-options
                                                     :initial-terminal-dimensions))
                                         (list :initial-cursor-position
                                               (getf platform-options
                                                     :initial-cursor-position))))
                        (setf (car state-cell) st)
                        (when cmd-proc-fn
                          (dolist (c init-cmds)
                            (funcall cmd-proc-fn c msg-queue st cfg)))
                        st))
                    (pupdate (model pmsg)
                      (multiple-value-bind (nst new-cmds)
                          (funcall proc-fn model pmsg)
                        (setf (car state-cell) nst)
                        (when cmd-proc-fn
                          (dolist (c new-cmds)
                            (funcall cmd-proc-fn c msg-queue nst cfg)))
                        nst))
                    (pview  (model) (funcall app-view-fn model))
                    (psubs  (model) (funcall (compile nil app-subs-form) model)))
                 (elmtui.app.api:run-application
                  (list :name ',name
                        :init-fn #'pinit
                        :update-fn #'pupdate
                        :view-fn   #'pview
                        :subscriptions-fn #'psubs
                        :message-queue msg-queue
                        :root-viewport-id ,root-vp-id)
                  :backend-type platform
                  :platform-options platform-options))))
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
