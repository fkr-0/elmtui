;;;===============================================================
;;; File: src/platform/driver.lisp
;;; Platform Driver
;;;===============================================================
(uiop:define-package :elmtui.platform.driver
  (:use :cl
   :elmtui.core.loop
        :elmtui.platform.input
   :elmtui.platform.output)
  (:export :run-application))
(in-package :elmtui.platform.driver)

(defun setup-resize (resize-fun)
  "Sets up a handler for SIGWINCH that calls RESIZE-FUN.
  Argument: RESIZE-FUN - the function to call when SIGWINCH is signaled.
  Returns: NIL.

  Examples:
    (setup-resize #'handle-resize)
     => NIL
    (setup-resize #'handle-resize)
     => NIL"
  (sb-sys:enable-interrupt sb-unix:sigwinch
                           (lambda (signal code scp)
                             (declare (ignore signal code scp))
                             (funcall resize-fun))))

(defun setup-interrupt (interrupt-fun)
  "Sets up a handler for SIGINT that calls INTERRUPT-FUN.
  Argument: INTERRUPT-FUN - the function to call when SIGINT is signaled.
  Returns: NIL.

  Examples:
    (setup-interrupt #'handle-interrupt)
     => NIL
    (setup-interrupt #'handle-interrupt)
     => NIL"
  (sb-sys:enable-interrupt sb-unix:sigint
                           (lambda (signal code scp)
                             (declare (ignore signal code scp))
                             (funcall interrupt-fun))))
(defun run-application (app-spec &key (backend-type :terminal) (tty-path "/dev/tty"))
  "Main entry point for running an elmtui application."
  (let ((backend-instance (elmtui.backend.terminal:initialize-backend backend-type :tty-path tty-path))
        (input-thread nil)
        (stop-input-fn nil))
    (unwind-protect
         (progn
           ;; Setup signal handlers
           (setup-resize
            (lambda ()
              (multiple-value-bind (width height)
                  (elmtui.platform.api:get-screen-dimensions backend-instance)
                (setf (elmtui.platform.api:term-w backend-instance) width
                      (elmtui.platform.api:term-h backend-instance) height)
                (elmtui.core.loop:publish (list :terminal-resized :width width :height height)))))
           (setup-interrupt
            (lambda ()
              (elmtui.core.loop:publish '(:app-quit-requested (:source :sigint)))))

           ;; Start input reader
           (multiple-value-bind (thread stop-fn)
               (start-reader backend-instance)
             (setf input-thread thread
                   stop-input-fn stop-fn))

           ;; Initialize application (init-fn was already called by def-elm-app to populate *app-state*)
           (let* ((update-fn (getf app-spec :update-fn))
                  (view-fn (getf app-spec :view-fn))
                  (subscriptions-fn (getf app-spec :subscriptions-fn))
                  ;; Initial commands are also handled by def-elm-app's setup
                  ;; Get the application state object.
                  ;; Renamed to avoid style warning about lexical binding of a special-looking variable.
                  (app-state-obj elmtui.state:*app-state*))

             ;; The update function (e.g., dirlister-update-fn) already expects (app-state-obj message)
             ;; and uses set-state! to modify the state object.
             ;; It returns commands.
             (let ((app-update-handler
                     (lambda (message)
                       (let ((commands (funcall update-fn app-state-obj message)))
                         ;; Process any new commands returned by the update function
                         (dolist (cmd commands)
                           ;; Assuming commands are messages to be published
                           (elmtui.core.loop:publish cmd))
                         ;; Re-render after update. view-fn expects app-state-obj and a dispatch function.
                         ;; The dispatch function for views is typically elmtui.core.loop:publish
                         (render-frame (funcall view-fn app-state-obj #'elmtui.core.loop:publish) backend-instance)))))

               ;; Subscribe with the app-update-handler
               (when subscriptions-fn
                 (dolist (event-type (funcall subscriptions-fn app-state-obj)) ; Pass app-state-obj to subscriptions
                   (elmtui.core.loop:subscribe event-type app-update-handler)))
               (elmtui.core.loop:subscribe :app-quit-requested app-update-handler)
               (elmtui.core.loop:subscribe :terminal-resized app-update-handler)
               ;; Potentially subscribe to other system events if update-fn handles them directly
               )

             ;; Start event loop - elmtui.core.loop:start-loop is the main loop.
             ;; It uses :loop-fun #'dispatch-event by default (from elmtui.core.loop itself).
             ;; dispatch-event calls publish, which calls our subscribed app-update-handler.
             (elmtui.core.loop:start-loop :wait nil) ; This starts the loop that will call app-update-handler via publish

             ;; Initial commands were already processed by def-elm-app.
             ;; Perform initial render
             (render-frame (funcall view-fn app-state-obj #'elmtui.core.loop:publish) backend-instance)

             ;; The main thread needs to wait for the event loop to finish or app to quit.
             ;; This loop effectively makes run-application blocking until the app quits.
             (loop while (elmtui.core.loop:event-loop-active-p) do (sleep 0.1))
             ))

      ;; Cleanup
      (when stop-input-fn
        (stop-reader stop-input-fn input-thread))
      (elmtui.platform.api:shutdown-backend backend-instance))))
