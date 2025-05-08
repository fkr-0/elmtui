;;;===============================================================
;;; File: src/runtime.lisp
;;; Runtime Assembly & Entrypoint
;;;===============================================================
(uiop:define-package :elmtui.runtime
  (:use :cl :alexandria :log4cl)
  ;; State Management
  (:import-from :elmtui.state #:application-state #:make-application-state #:*app-state* #:state-ref)
  (:import-from :ut.state.state #:set-state) ; Internal set-state for initialization
  ;; Core Systems
  (:import-from :elmtui.core.globals #:*app-sender*)
  (:import-from :elmtui.core.loop #:start-loop #:stop-loop #:event-loop-active-p #:enqueue-event #:*event-loop*)
  (:import-from :elmtui.core.async #:interpret-cmd)
  (:import-from :elmtui.core.events #:cmd #:make-message)
  (:import-from :elmtui.state.msg #:make-update-focusable-ids-app-msg) ; Constructor for the message
  ;; Platform Abstraction
  (:import-from :elmtui.platform.driver #:init-platform #:shutdown-platform #:render-frame #:process-platform-events)
  ;; UI Utilities
  (:import-from :elmtui.ui.widgets.utils #:collect-focusable-ids)
  (:export :def-elm-app
           :run-app))
(in-package :elmtui.runtime)

(defvar *current-app-name* nil "Holds the name of the currently defined Elm app.")
(defvar *current-app-runner* nil "Holds the main run function of the defined Elm app.")

(defmacro def-elm-app (name &key init update view subscriptions)
  "Defines an ElmTUI application.

   Args:
     NAME: Symbol naming the application.
     INIT: A function designator (#'my-init) that takes no arguments and returns
           (values initial-model initial-commands-list).
     UPDATE: A function designator (#'my-update) that takes (app-state message)
             and returns commands-list. It uses set-state! internally.
     VIEW: A function designator (#'my-view) that takes (app-state) and returns
           a UI-NODE tree.
     SUBSCRIPTIONS: (Optional) A function designator (#'my-subscriptions) that takes (app-state)
                    and returns a list of subscriptions (e.g., for timers, external events). (Not fully implemented yet)

   Generates:
     - A `run-<NAME>` function to start and manage the application lifecycle.
     - Sets `*current-app-name*` and `*current-app-runner*` for the default `run-app`.
   "
  (let ((run-func-name (symbolicate "RUN-" name))
        (init-func (gensym "INIT"))
        (update-func (gensym "UPDATE"))
        (view-func (gensym "VIEW"))
        (subs-func (gensym "SUBS")))
    `(progn
       ;; Store function designators
       (defparameter ,init-func ,init)
       (defparameter ,update-func ,update)
       (defparameter ,view-func ,view)
       (defparameter ,subs-func ,subscriptions)

       (defun ,run-func-name (&key (platform :terminal) platform-options)
         (log:info "Starting ElmTUI application: ~A (Platform: ~A)" ',name platform)
         ;; 1. Initialize State
         (multiple-value-bind (initial-model initial-commands)
             (funcall ,init-func)
           ;; Ensure *app-state* exists
           (unless (typep *app-state* 'application-state)
             (setf *app-state* (make-application-state)))

           ;; Merge the initial model returned by the :init function into the state.
           ;; Assumes initial-model is a plist or another application-state.
           ;; merge-state handles merging plists into application-state.
           (when initial-model
             (log:debug "Merging initial model into app state: ~S" initial-model)
             (merge-state *app-state* initial-model :overwrite t)) ; Overwrite existing keys if any conflict

           ;; Initialize global keys like focus state if not provided by initial-model
           (unless (state-ref *app-state* :focused-widget-id)
             (set-state *app-state* :focused-widget-id nil)) ; Use internal set-state before loop
           (unless (state-ref *app-state* :focusable-widget-ids)
             (set-state *app-state* :focusable-widget-ids nil)) ; Use internal set-state

           ;; 2. Initialize Platform
           (init-platform platform platform-options)

           ;; 3. Setup App Sender
           ;; Bind *app-sender* to enqueue events into the loop's input queue
           (let ((*app-sender* (lambda (msg)
                                 (when *event-loop*
                                   (enqueue-event *event-loop* (make-message :type (if (listp msg) (first msg) msg)
                                                                             :data (if (listp msg) (rest msg) nil)))))))
             ;; Process initial commands *after* setting up sender
             (when initial-commands
               (log:info "Processing initial commands: ~S" initial-commands)
               (dolist (cmd initial-commands)
                 (interpret-cmd cmd)))

             ;; 4. Start Event Loop (using clevelib's loop)
             (unwind-protect
                  (start-loop :fps 60 :wait nil ; Run in background thread
                              :loop-fun (lambda (event-queue) ; Custom loop function
                                          (let ((commands nil)
                                                (view-tree nil)
                                                (focusable-ids nil))
                                            ;; a. Process Platform Events (Input) -> Enqueue Messages
                                            (process-platform-events event-queue) ; Platform pushes events/messages

                                            ;; b. Process Queued Events/Messages
                                            (loop for event = (elmtui.core.loop::dequeue-event event-queue)
                                                  while event
                                                  do
                                               (log:debug "Processing event: ~S" event)
                                               ;; Call the main update function
                                               (let ((update-commands (funcall ,update-func *app-state* event)))
                                                 (when update-commands
                                                   (setf commands (append update-commands commands)))))

                                            ;; c. Process Commands generated by update
                                            (when commands
                                              (log:debug "Processing commands: ~S" commands)
                                              (dolist (cmd commands)
                                                (interpret-cmd cmd)))

                                            ;; d. Generate View
                                            (setf view-tree (funcall ,view-func *app-state*))

                                            ;; e. Collect Focusable IDs & Dispatch Update Message
                                            (setf focusable-ids (collect-focusable-ids view-tree))
                                            (enqueue-event event-queue
                                                           (make-message :type :update-focusable-ids
                                                                         :data (list :ids focusable-ids)))

                                            ;; f. Render View
                                            (render-frame view-tree)

                                            ;; g. Handle Subscriptions (TODO)
                                            ;; (when ,subs-func
                                            ;;   (let ((subs (funcall ,subs-func *app-state*)))
                                            ;;     ;; Process subscriptions...
                                            ;;     ))

                                            ;; h. Check for Exit Condition (e.g., state flag)
                                            (when (eq (state-ref *app-state* :app-lifecycle) :quit)
                                              (return-from ,run-func-name))))) ; Exit the run function
               ;; 5. Cleanup
               (progn
                 (log:info "Shutting down application ~A..." ',name)
                 (stop-loop)
                 (shutdown-platform)
                 (log:info "Application ~A stopped." ',name)))))))

       ;; Set this app as the default runnable one
       (setf *current-app-name* ',name)
       (setf *current-app-runner* #',run-func-name)
       ',name))) ; Return the app name

(defun run-app (&rest args &key (app-name *current-app-name*) &allow-other-keys)
  "Runs the defined ElmTUI application.
   Defaults to the most recently defined app via def-elm-app.
   Passes keyword arguments (like :platform) to the specific run-<app-name> function."
  (let ((runner (or (when app-name (symbol-function (symbolicate "RUN-" app-name)))
                    *current-app-runner*)))
    (if runner
        (apply runner (remove-from-plist args :app-name))
        (error "No ElmTUI application defined or specified to run."))))
