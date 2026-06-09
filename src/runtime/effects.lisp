;;;===============================================================
;;; File: src/runtime/effects.lisp
;;; Runtime Effect Manager
;;;===============================================================

(uiop:define-package :elmtui.runtime.effects
  (:use :cl)
  (:import-from :log4cl
                #:log-debug
                #:log-warn)
  (:import-from :elmtui.core.async
                #:interpret-cmd
                #:cmd-recurring
                #:cancel-cmd)
  (:import-from :elmtui.contracts
                #:subscription)
  (:export
   #:split-render-commands
   #:run-commands-with-policy
   #:apply-update-effects
   #:normalize-subscriptions
   #:reconcile-model-subscriptions
   #:clear-subscription-registry))

(in-package :elmtui.runtime.effects)

(defun %subscription-descriptor-p (item)
  (or (typep item 'subscription)
      (and (consp item) (keywordp (first item)))))

(defun normalize-subscriptions (subs)
  "Normalize SUBS to a list of recognized subscription descriptors."
  (cond
    ((null subs) nil)
    ((typep subs 'subscription) (list subs))
    ((and (consp subs) (keywordp (first subs))) (list subs))
    ((and (listp subs) (every #'%subscription-descriptor-p subs)) subs)
    (t
     (log-warn "RUNTIME-EFFECTS: Ignoring invalid subscriptions payload: ~S" subs)
     nil)))

(defun %subscription-key (sub)
  "Compute a canonical hash key for SUB."
  (cond
    ((typep sub 'subscription)
     (list :subscription
           (elmtui.contracts::subscription-type sub)
           (elmtui.contracts::subscription-config sub)))
    (t sub)))

(defun %timer-subscription-config (sub)
  "Extract timer config plist from supported subscription shapes."
  (cond
    ((typep sub 'subscription)
     (when (eq (elmtui.contracts::subscription-type sub) :timer)
       (copy-list (or (elmtui.contracts::subscription-config sub) '()))))
    ((and (consp sub) (eq (first sub) :timer))
     (let ((rest (rest sub)))
       (cond
         ((and (= (length rest) 1) (listp (first rest)))
          (copy-list (first rest)))
         ((listp rest) (copy-list rest))
         (t nil))))
    (t nil)))

(defun %timer-subscription-message-fn (sub)
  (when (typep sub 'subscription)
    (elmtui.contracts::subscription-message-fn sub)))

(defun %cancel-subscription-handle (handle command-canceller)
  "Cancel installed HANDLE using COMMAND-CANCELLER."
  (let ((cmd (getf handle :cmd)))
    (when cmd
      (ignore-errors
        (funcall command-canceller cmd)))))

(defun %install-subscription (sub command-interpreter)
  "Install one subscription descriptor. Returns handle plist or NIL."
  (let ((timer-cfg (%timer-subscription-config sub)))
    (if timer-cfg
        (let* ((interval (getf timer-cfg :interval))
               (message (getf timer-cfg :message))
               (msg-fn (%timer-subscription-message-fn sub)))
          (if (and (numberp interval) (> interval 0))
              (let ((cmd (cmd-recurring
                          interval
                          (lambda () nil)
                          :on-message (lambda (_)
                                        (declare (ignore _))
                                        (if (functionp msg-fn)
                                            (funcall msg-fn nil)
                                            message)))))
                (funcall command-interpreter cmd)
                (list :type :timer :cmd cmd))
              (progn
                (log-warn "RUNTIME-EFFECTS: Ignoring :timer subscription with invalid interval: ~S" sub)
                nil)))
        (progn
          (log-warn "RUNTIME-EFFECTS: Unsupported subscription ignored: ~S" sub)
          nil))))

(defun clear-subscription-registry (active-subscriptions
                                    &key
                                      (command-canceller #'cancel-cmd))
  "Cancel and clear all active subscription handles in ACTIVE-SUBSCRIPTIONS."
  (maphash (lambda (_key handle)
             (declare (ignore _key))
             (%cancel-subscription-handle handle command-canceller))
           active-subscriptions)
  (clrhash active-subscriptions)
  t)

(defun reconcile-model-subscriptions (subscriptions-fn model active-subscriptions
                                      &key
                                        (command-interpreter #'interpret-cmd)
                                        (command-canceller #'cancel-cmd))
  "Reconcile ACTIVE-SUBSCRIPTIONS against SUBSCRIPTIONS-FN evaluated on MODEL."
  (let* ((desired-raw (ignore-errors (funcall subscriptions-fn model)))
         (desired (normalize-subscriptions desired-raw))
         (desired-keys (make-hash-table :test 'equal))
         (to-remove nil))
    (dolist (sub desired)
      (let ((key (%subscription-key sub)))
        (setf (gethash key desired-keys) t)
        (unless (gethash key active-subscriptions)
          (let ((handle (%install-subscription sub command-interpreter)))
            (when handle
              (setf (gethash key active-subscriptions) handle))))))
    (maphash (lambda (key _handle)
               (declare (ignore _handle))
               (unless (gethash key desired-keys)
                 (push key to-remove)))
             active-subscriptions)
    (dolist (key to-remove)
      (let ((handle (gethash key active-subscriptions)))
        (%cancel-subscription-handle handle command-canceller)
        (remhash key active-subscriptions)))
    t))

(defun split-render-commands (commands)
  "Split COMMANDS into two values: render commands and non-render commands."
  (let ((render-cmds (remove-if-not (lambda (c) (and (consp c) (eq (car c) :render)))
                                    commands))
        (other-cmds  (remove-if (lambda (c) (and (consp c) (eq (car c) :render)))
                                commands)))
    (values render-cmds other-cmds)))

(defun run-commands-with-policy
    (commands
      &key
      render-command-fn
      command-processor-fn
      message-queue
      model
      app-config
      (fallback-command-interpreter #'interpret-cmd))
  "Execute COMMANDS using runtime policy callbacks.

Render commands run synchronously through RENDER-COMMAND-FN before all
other commands. Non-render commands are executed through
COMMAND-PROCESSOR-FN when provided, otherwise through
FALLBACK-COMMAND-INTERPRETER."
  (multiple-value-bind (render-cmds other-cmds)
      (split-render-commands commands)
    (dolist (cmd render-cmds)
      (when render-command-fn
        (funcall render-command-fn cmd)))
    (if command-processor-fn
        (dolist (cmd other-cmds)
          (funcall command-processor-fn cmd message-queue model app-config))
        (dolist (cmd other-cmds)
          (funcall fallback-command-interpreter cmd)))))

(defun apply-update-effects
    (&key
     commands
     render-command-fn
     command-processor-fn
     message-queue
     model
     app-config
     fallback-command-interpreter
     subscriptions-reconciler)
  "Apply command execution and subscription reconciliation for one update.

This function is the runtime effect-manager boundary used by the driver."
  (run-commands-with-policy
   commands
   :render-command-fn render-command-fn
   :command-processor-fn command-processor-fn
   :message-queue message-queue
   :model model
   :app-config app-config
   :fallback-command-interpreter (or fallback-command-interpreter #'interpret-cmd))
  (when subscriptions-reconciler
    (funcall subscriptions-reconciler model))
  (log-debug "RUNTIME-EFFECTS: Applied commands and subscriptions for model ~S" model)
  t)
