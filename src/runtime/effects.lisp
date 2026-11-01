;;;===============================================================
;;; File: src/runtime/effects.lisp
;;; Runtime Effect Manager
;;;===============================================================

(uiop:define-package :elmtui.runtime.effects
  (:use :cl)
  (:import-from :log4cl
                #:log-debug
                #:log-info
                #:log-warn)
  (:import-from :elmtui.core.async
                #:interpret-cmd
                #:cmd-recurring
                #:cancel-cmd)
  (:import-from :elmtui.core.globals
                #:*app-sender*)
  (:import-from :elmtui.contracts
                #:subscription)
  (:import-from :cl-state.core
                #:*state-mutation-policy*
                #:state-mutation-forbidden)
  (:export
   #:split-render-commands
   #:run-commands-with-policy
   #:apply-update-effects
   #:normalize-subscriptions
   #:reconcile-model-subscriptions
   #:clear-subscription-registry))

(in-package :elmtui.runtime.effects)

;;; ---------------------------------------------------------------
;;; Descriptor validation and normalization
;;; ---------------------------------------------------------------

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

;;; ---------------------------------------------------------------
;;; Subscription identity (keying for reconciliation)
;;; ---------------------------------------------------------------

(defun %subscription-key (sub)
  "Compute a canonical hash key for SUB.
Keys are compared with EQUAL. Two descriptors with the same key are
considered the same subscription for reconciliation purposes."
  (cond
    ((typep sub 'subscription)
     (list :subscription
           (elmtui.contracts::subscription-type sub)
           (elmtui.contracts::subscription-config sub)))
    ;; :file-watch is keyed by type + path (not the whole descriptor, so
    ;; changing the message does not restart the watcher).
    ((and (consp sub) (eq (first sub) :file-watch))
     (let ((cfg (%unwrap-descriptor-config sub)))
       (list :file-watch (getf cfg :path))))
    ;; :process is keyed by the command list.
    ((and (consp sub) (eq (first sub) :process))
     (let ((cfg (%unwrap-descriptor-config sub)))
       (list :process (getf cfg :command))))
    ;; :window-resize is a singleton — at most one active.
    ((and (consp sub) (eq (first sub) :window-resize))
     '(:window-resize))
    (t sub)))

;;; ---------------------------------------------------------------
;;; Descriptor config extraction helpers
;;; ---------------------------------------------------------------

(defun %unwrap-descriptor-config (sub)
  "Return the config plist from a raw plist-style descriptor (:TYPE (CONFIG...)) or (:TYPE :KEY VAL ...)."
  (let ((rest (rest sub)))
    (cond
      ((null rest) nil)
      ((and (= (length rest) 1) (listp (first rest)))
       (first rest))
      (t rest))))

(defun %timer-subscription-config (sub)
  "Extract timer config plist from supported subscription shapes."
  (cond
    ((typep sub 'subscription)
     (when (eq (elmtui.contracts::subscription-type sub) :timer)
       (copy-list (or (elmtui.contracts::subscription-config sub) '()))))
    ((and (consp sub) (eq (first sub) :timer))
     (copy-list (%unwrap-descriptor-config sub)))
    (t nil)))

(defun %every-subscription-config (sub)
  "Extract :every config plist. Returns NIL for non-:every descriptors."
  (when (and (consp sub) (eq (first sub) :every))
    (copy-list (%unwrap-descriptor-config sub))))

(defun %window-resize-subscription-config (sub)
  "Extract :window-resize config plist. Returns NIL for non-:window-resize descriptors."
  (when (and (consp sub) (eq (first sub) :window-resize))
    (copy-list (%unwrap-descriptor-config sub))))

(defun %file-watch-subscription-config (sub)
  "Extract :file-watch config plist. Returns NIL for non-:file-watch descriptors."
  (when (and (consp sub) (eq (first sub) :file-watch))
    (copy-list (%unwrap-descriptor-config sub))))

(defun %process-subscription-config (sub)
  "Extract :process config plist. Returns NIL for non-:process descriptors."
  (when (and (consp sub) (eq (first sub) :process))
    (copy-list (%unwrap-descriptor-config sub))))

(defun %timer-subscription-message-fn (sub)
  (when (typep sub 'subscription)
    (elmtui.contracts::subscription-message-fn sub)))

;;; ---------------------------------------------------------------
;;; :every — resolve interval from :seconds or :ms
;;; ---------------------------------------------------------------

(defun %resolve-every-interval (cfg)
  "Return interval in seconds from an :every config plist.
Accepts :seconds or :ms (milliseconds). Returns NIL on invalid input."
  (let ((seconds (getf cfg :seconds))
        (ms (getf cfg :ms)))
    (cond
      ((and (numberp seconds) (> seconds 0)) seconds)
      ((and (numberp ms) (> ms 0)) (/ ms 1000.0))
      (t nil))))

;;; ---------------------------------------------------------------
;;; :window-resize — SIGWINCH hook management
;;; ---------------------------------------------------------------

(defvar *window-resize-subscription-active* nil
  "When non-NIL, a plist (:message MSG :sender SENDER-FN) for the active
window-resize subscription. Only one can be active at a time.")

(defvar *original-sigwinch-handler* nil
  "Saved previous SIGWINCH handler to restore on unsubscribe.")

(defun %query-terminal-size-via-ioctl ()
  "Read terminal dimensions via TIOCGWINSZ ioctl on fd 0.
Returns (values width height) or (values 80 24) on failure."
  #+linux
  (handler-case
      (sb-alien:with-alien
          ((size (sb-alien:struct %sub-winsize
                   (rows sb-alien:unsigned-short)
                   (cols sb-alien:unsigned-short)
                   (x sb-alien:unsigned-short)
                   (y sb-alien:unsigned-short))))
        (if (zerop
             (sb-alien:alien-funcall
              (sb-alien:extern-alien
               "ioctl"
               (sb-alien:function sb-alien:int sb-alien:int
                                  sb-alien:unsigned-long sb-alien:system-area-pointer))
              0  ;; stdin fd
              #x5413 ;; TIOCGWINSZ on Linux
              (sb-alien:alien-sap (sb-alien:addr size))))
            (values (sb-alien:slot size 'cols) (sb-alien:slot size 'rows))
            (values 80 24)))
    (error () (values 80 24)))
  #-linux
  (values 80 24))

(defun %install-window-resize-handler (message)
  "Install a SIGWINCH handler that delivers MESSAGE with :width/:height."
  (setf *original-sigwinch-handler*
        (sb-sys:enable-interrupt sb-unix:sigwinch
          (lambda (signal code scp)
            (declare (ignore signal code scp))
            (let ((sender *app-sender*))
              (when sender
                (multiple-value-bind (width height)
                    (%query-terminal-size-via-ioctl)
                  (let ((enriched (append message (list :width width :height height))))
                    (funcall sender enriched)))))))))

(defun %teardown-window-resize-handler ()
  "Remove the subscription SIGWINCH handler, restoring the previous one."
  (sb-sys:enable-interrupt sb-unix:sigwinch :default)
  (setf *window-resize-subscription-active* nil
        *original-sigwinch-handler* nil))

;;; ---------------------------------------------------------------
;;; :file-watch — polling-based file watcher
;;; ---------------------------------------------------------------

(defun %file-watch-thread-fn (path message sender poll-interval stop-flag)
  "Poll PATH for mtime changes, delivering MESSAGE via SENDER.
STOP-FLAG is a cons whose car is checked each iteration."
  (let ((last-mtime nil)
        (last-exists nil))
    (loop
      (when (car stop-flag) (return))
      (handler-case
          (let* ((exists (probe-file path))
                 (mtime (when exists
                          (file-write-date (truename exists)))))
            (cond
              ;; File appeared
              ((and exists (not last-exists))
               (setf last-exists t last-mtime mtime)
               (when sender
                 (funcall sender (append message (list :path (namestring path)
                                                       :event :created)))))
              ;; File modified
              ((and exists last-exists mtime last-mtime
                    (not (eql mtime last-mtime)))
               (setf last-mtime mtime)
               (when sender
                 (funcall sender (append message (list :path (namestring path)
                                                       :event :modified)))))
              ;; File disappeared
              ((and (not exists) last-exists)
               (setf last-exists nil last-mtime nil)
               (when sender
                 (funcall sender (append message (list :path (namestring path)
                                                       :event :deleted)))))
              ;; First poll — record baseline
              ((and exists (null last-mtime))
               (setf last-exists t last-mtime mtime))
              ((and (not exists) (null last-exists))
               (setf last-exists nil))))
        (error (e)
          (log-warn "RUNTIME-EFFECTS: file-watch poll error for ~S: ~A" path e)))
      (sleep poll-interval))))

;;; ---------------------------------------------------------------
;;; :process — external process subscription
;;; ---------------------------------------------------------------

(defun %process-reader-thread-fn (process command on-output on-exit sender stop-flag)
  "Read stdout from PROCESS line by line, deliver ON-OUTPUT messages.
When the process exits, deliver ON-EXIT with the exit code."
  (let ((pid (handler-case
                 (#+sbcl sb-ext:process-pid #-sbcl (lambda (p) (declare (ignore p)) nil)
                  process)
               (error () nil)))
        (stream (handler-case
                    (#+sbcl sb-ext:process-output #-sbcl (lambda (p) (declare (ignore p)) nil)
                     process)
                  (error () nil))))
    (unwind-protect
         (when stream
           (handler-case
               (loop
                 (when (car stop-flag) (return))
                 (let ((line (read-line stream nil :eof)))
                   (cond
                     ((eq line :eof) (return))
                     (t (when (and sender on-output)
                          (funcall sender
                                   (append on-output
                                           (list :line line :pid pid))))))))
             (error (e)
               (log-warn "RUNTIME-EFFECTS: process reader error for ~S: ~A" command e))))
      ;; Clean up: ensure process is waited on
      (handler-case
          (progn
            #+sbcl (sb-ext:process-wait process)
            (let ((code #+sbcl (sb-ext:process-exit-code process)
                        #-sbcl nil))
              (when (and sender on-exit)
                (funcall sender
                         (append on-exit
                                 (list :code (or code -1) :pid pid))))))
        (error (e)
          (log-warn "RUNTIME-EFFECTS: process cleanup error for ~S: ~A" command e)
          (when (and sender on-exit)
            (funcall sender
                     (append on-exit
                             (list :code -1 :pid pid
                                   :error (princ-to-string e))))))))))

(defun %launch-process (command)
  "Launch COMMAND (list of strings) as an external process with :output :stream.
Returns the process object or NIL on failure."
  (handler-case
      (let ((program (first command))
            (args (rest command)))
        #+sbcl
        (sb-ext:run-program program args
                            :output :stream
                            :error nil
                            :wait nil
                            :search t)
        #-sbcl
        (progn
          (log-warn "RUNTIME-EFFECTS: :process subscription requires SBCL")
          nil))
    (error (e)
      (log-warn "RUNTIME-EFFECTS: Failed to launch process ~S: ~A" command e)
      nil)))

;;; ---------------------------------------------------------------
;;; Subscription lifecycle: cancel
;;; ---------------------------------------------------------------

(defun %cancel-subscription-handle (handle command-canceller)
  "Cancel installed HANDLE using COMMAND-CANCELLER or type-specific cleanup."
  (let ((handle-type (getf handle :type))
        (cmd (getf handle :cmd)))
    (case handle-type
      ;; Timer-based subscriptions (:timer, :every) use cmd-recurring
      ((:timer :every)
       (when cmd
         (handler-case
             (funcall command-canceller cmd)
           (error (condition)
             (log-warn "RUNTIME-EFFECTS: subscription cancellation failed for ~S: ~A"
                       cmd condition)))))
      ;; Window-resize: teardown signal handler
      (:window-resize
       (%teardown-window-resize-handler))
      ;; File-watch: signal stop flag and optionally join thread
      (:file-watch
       (let ((stop-flag (getf handle :stop-flag))
             (thread (getf handle :thread)))
         (when stop-flag
           (setf (car stop-flag) t))
         (when (and thread (bt:thread-alive-p thread))
           (handler-case
               (bt:join-thread thread)
             (error (e)
               (log-warn "RUNTIME-EFFECTS: file-watch thread join failed: ~A" e))))))
      ;; Process: signal stop, kill process, join thread
      (:process
       (let ((stop-flag (getf handle :stop-flag))
             (thread (getf handle :thread))
             (process (getf handle :process)))
         (when stop-flag
           (setf (car stop-flag) t))
         (when process
           (handler-case
               (progn
                 #+sbcl
                 (when (sb-ext:process-alive-p process)
                   (sb-ext:process-kill process sb-unix:sigterm)
                   ;; Give it a moment, then force-kill
                   (sleep 0.05)
                   (when (sb-ext:process-alive-p process)
                     (sb-ext:process-kill process sb-unix:sigkill)))
                 #-sbcl nil)
             (error (e)
               (log-warn "RUNTIME-EFFECTS: process kill failed: ~A" e))))
         (when (and thread (bt:thread-alive-p thread))
           (handler-case
               (bt:join-thread thread)
             (error (e)
               (log-warn "RUNTIME-EFFECTS: process thread join failed: ~A" e))))))
      ;; Fallback for unknown handle types or legacy handles without :type
      (otherwise
       (when cmd
         (handler-case
             (funcall command-canceller cmd)
           (error (condition)
             (log-warn "RUNTIME-EFFECTS: subscription cancellation failed for ~S: ~A"
                       cmd condition))))))))

;;; ---------------------------------------------------------------
;;; Subscription lifecycle: install
;;; ---------------------------------------------------------------

(defun %install-timer-subscription (sub command-interpreter)
  "Install a :timer subscription. Returns handle plist or NIL."
  (let* ((timer-cfg (%timer-subscription-config sub))
         (interval (getf timer-cfg :interval))
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
          nil))))

(defun %install-every-subscription (sub command-interpreter)
  "Install an :every subscription. Returns handle plist or NIL."
  (let* ((cfg (%every-subscription-config sub))
         (interval (%resolve-every-interval cfg))
         (message (getf cfg :message)))
    (if interval
        (let ((cmd (cmd-recurring
                    interval
                    (lambda () nil)
                    :on-message (lambda (_)
                                  (declare (ignore _))
                                  message))))
          (funcall command-interpreter cmd)
          (list :type :every :cmd cmd))
        (progn
          (log-warn "RUNTIME-EFFECTS: Ignoring :every subscription with invalid interval: ~S" sub)
          nil))))

(defun %install-window-resize-subscription (sub)
  "Install a :window-resize subscription. Returns handle plist or NIL."
  (let* ((cfg (%window-resize-subscription-config sub))
         (message (getf cfg :message)))
    (unless message
      (log-warn "RUNTIME-EFFECTS: Ignoring :window-resize subscription with no :message: ~S" sub)
      (return-from %install-window-resize-subscription nil))
    ;; Only one resize subscription at a time
    (when *window-resize-subscription-active*
      (%teardown-window-resize-handler))
    (%install-window-resize-handler message)
    (setf *window-resize-subscription-active*
          (list :message message :sender *app-sender*))
    (list :type :window-resize)))

(defun %install-file-watch-subscription (sub)
  "Install a :file-watch subscription. Returns handle plist or NIL."
  (let* ((cfg (%file-watch-subscription-config sub))
         (path (getf cfg :path))
         (message (getf cfg :message))
         (poll-interval (or (getf cfg :interval) 0.5)))
    (unless (and path message)
      (log-warn "RUNTIME-EFFECTS: Ignoring :file-watch subscription with missing :path or :message: ~S" sub)
      (return-from %install-file-watch-subscription nil))
    (let* ((stop-flag (list nil))
           (sender *app-sender*)
           (thread (bt:make-thread
                    (lambda ()
                      (%file-watch-thread-fn path message sender poll-interval stop-flag))
                    :name (format nil "elmtui-file-watch-~A" path))))
      (list :type :file-watch :thread thread :stop-flag stop-flag :path path))))

(defun %install-process-subscription (sub)
  "Install a :process subscription. Returns handle plist or NIL."
  (let* ((cfg (%process-subscription-config sub))
         (command (getf cfg :command))
         (on-output (getf cfg :on-output))
         (on-exit (getf cfg :on-exit)))
    (unless (and command (listp command) (plusp (length command)))
      (log-warn "RUNTIME-EFFECTS: Ignoring :process subscription with missing/invalid :command: ~S" sub)
      (return-from %install-process-subscription nil))
    (unless (or on-output on-exit)
      (log-warn "RUNTIME-EFFECTS: Ignoring :process subscription with no message handlers: ~S" sub)
      (return-from %install-process-subscription nil))
    (let ((process (%launch-process command)))
      (unless process
        ;; Deliver immediate exit-with-error if launch failed
        (when (and *app-sender* on-exit)
          (funcall *app-sender*
                   (append on-exit (list :code -1 :pid nil
                                         :error "failed to launch process"))))
        (return-from %install-process-subscription nil))
      (let* ((stop-flag (list nil))
             (sender *app-sender*)
             (thread (bt:make-thread
                      (lambda ()
                        (%process-reader-thread-fn
                         process command on-output on-exit sender stop-flag))
                      :name (format nil "elmtui-process-~{~A~^ ~}" command))))
        (list :type :process :thread thread :stop-flag stop-flag
              :process process :command command)))))

(defun %install-subscription (sub command-interpreter)
  "Install one subscription descriptor. Returns handle plist or NIL."
  (cond
    ;; :timer — legacy timer subscription
    ((%timer-subscription-config sub)
     (%install-timer-subscription sub command-interpreter))
    ;; :every — cleaner timer alias
    ((%every-subscription-config sub)
     (%install-every-subscription sub command-interpreter))
    ;; :window-resize — SIGWINCH subscription
    ((%window-resize-subscription-config sub)
     (%install-window-resize-subscription sub))
    ;; :file-watch — polling file watcher
    ((%file-watch-subscription-config sub)
     (%install-file-watch-subscription sub))
    ;; :process — external process
    ((%process-subscription-config sub)
     (%install-process-subscription sub))
    (t
     (log-warn "RUNTIME-EFFECTS: Unsupported subscription ignored: ~S" sub)
     nil)))

;;; ---------------------------------------------------------------
;;; Registry management
;;; ---------------------------------------------------------------

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
  (let* ((desired-raw (funcall subscriptions-fn model))
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
      (state-mutation-policy :allow)
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
        (let ((*state-mutation-policy* state-mutation-policy))
          (dolist (cmd other-cmds)
            (funcall command-processor-fn cmd message-queue model app-config)))
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
     (state-mutation-policy :allow)
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
   :state-mutation-policy state-mutation-policy
   :fallback-command-interpreter (or fallback-command-interpreter #'interpret-cmd))
  (when subscriptions-reconciler
    (funcall subscriptions-reconciler model))
  (log-debug "RUNTIME-EFFECTS: Applied commands and subscriptions for model ~S" model)
  t)
