(uiop:define-package :elmtui.examples.dirli
  (:use :cl :elmtui.app) ; Use :elmtui.app for defapplication
  (:import-from :elmtui.ui.widgets.listbox
                #:init-listbox #:update-listbox #:view-listbox
                #:listbox-model-height #:listbox-model-items
                #:listbox-model-selected-index #:listbox-model-on-select
                #:listbox-model-id)
  (:import-from :elmtui.core.focus #:handle-focus-message)
  (:import-from :elmtui.state #:state-ref)
  (:import-from :elmtui.style.presets #:dark-theme)
  (:import-from :elmtui.core.event-compat #:normalize-event)
  (:import-from :elmtui.core.events #:key-event #:key-event-key)
  (:import-from :elmtui.view.dsl #:vbox #:text) ; Corrected import for view.dsl
  (:import-from :log4cl)
  (:export :main :run-dirli))

(in-package :elmtui.examples.dirli)

(defun list-directory-contents (path)
  (handler-case
      (loop for entry in (append (uiop:subdirectories path)
                                 (uiop:directory-files path))
            collect (let ((name (enough-namestring entry path)))
                      (if (uiop:directory-exists-p entry)
                          (concatenate 'string name "/")
                          name)))
    (error (e)
      (log4cl:log-error "Error listing directory ~A: ~A" path e)
      (list (format nil "Error listing ~A" path)))))

(defapplication dirli-app
  :initial-state-fn
  (lambda ()
    (let* ((current-path (uiop:getcwd))
           (items (list-directory-contents current-path))
           (listbox-state (init-listbox
                           :main-listbox ; ID for focus and state
                           :items items
                           :height 10
                           :selected-index (when items 0)
                           :on-select '(:listbox-item-selected))))
      (list :listbox-state listbox-state
            :current-path current-path
            :status-message "Welcome to Dirli!"
            :terminal-width 80
            :terminal-height 24
            :output-to-print nil
            :current-focus-id :main-listbox
            :prev-focus-id nil
            :focusable-elements '(:main-listbox) ; Only listbox is focusable initially
            :current-stylesheet dark-theme)))
  :update-fn
  (lambda (app-state message)
    (let* ((focus-state-patch (handle-focus-message app-state message))
           (app-patch nil)
           (commands nil)
           (current-message-patch nil)
           (listbox-id :main-listbox)
           (current-focus (or (getf focus-state-patch :current-focus-id) (state-ref app-state :current-focus-id)))
           (prev-focus (or (getf focus-state-patch :prev-focus-id) (state-ref app-state :prev-focus-id)))
           (listbox-state (state-ref app-state :listbox-state))
           (normalized-message (normalize-event message)))

      ;; --- Focus sync logic for listbox (if it were a separate component needing explicit focus messages) ---
      ;; With listbox state integrated, direct key handling when focused is more common.
      ;; However, if listbox had its own :listbox-focus / :listbox-blur messages, this would be relevant.
      (when (and focus-state-patch (not (equal current-focus prev-focus)))
        (cond
          ((equal current-focus listbox-id)
           (log4cl:log-debug "DIRLI-UPDATE: Listbox ~A gained focus." listbox-id)
           ;; If listbox had its own focus message:
           ;; (multiple-value-bind (new-lb-state lb-cmds) (update-listbox '(:listbox-focus) listbox-state) ... )
           )
          ((equal prev-focus listbox-id)
           (log4cl:log-debug "DIRLI-UPDATE: Listbox ~A lost focus." listbox-id)
           ;; (multiple-value-bind (new-lb-state lb-cmds) (update-listbox '(:listbox-blur) listbox-state) ... )
           )))

      (if focus-state-patch
          (setf app-patch (append focus-state-patch app-patch))
          ;; Handle application-specific messages only if focus didn't change things
          (cond
            ;; Key events when listbox is focused
            ((and normalized-message (typep normalized-message 'key-event) (equal current-focus listbox-id))
             (log4cl:log-debug "DIRLI-UPDATE: Processing key event for listbox: ~S" normalized-message)
             (let ((key (key-event-key normalized-message)))
               (cond
                 ((and (string= key "q") (member :control (elmtui.core.event-types:key-event-modifiers normalized-message)))
                  (setf current-message-patch (list :should-quit t))
                  (log4cl:log-info "App quit requested (C-q), setting should-quit flag."))
                 (t
                  (multiple-value-bind (new-listbox-state listbox-commands)
                      (update-listbox `(:listbox-key-press :key ,key) listbox-state)
                    (setf current-message-patch (list :listbox-state new-listbox-state))
                    (setf commands (append listbox-commands commands)))))))

            ;; Handle list-based messages (custom messages)
            ((listp message)
             (let ((msg-type (first message))
                   (msg-data (rest message)))
               (case msg-type
                 (:listbox-item-selected
                  (let* ((selected-item-name (getf msg-data :item))
                         (current-path (state-ref app-state :current-path))
                         (new-path-attempt (uiop:resolve-location
                                            (merge-pathnames selected-item-name current-path))))
                    (log4cl:log-debug "Listbox item selected: ~S, current-path: ~S, new-path-attempt: ~S"
                                      selected-item-name current-path new-path-attempt)
                    (cond
                      ((uiop:directory-exists-p new-path-attempt)
                       (let* ((new-items (list-directory-contents new-path-attempt))
                              (new-listbox-state (init-listbox
                                                  (listbox-model-id listbox-state) ; Preserve ID
                                                  :items new-items
                                                  :height (listbox-model-height listbox-state)
                                                  :selected-index (when new-items 0)
                                                  :on-select (listbox-model-on-select listbox-state))))
                         (setf current-message-patch
                               (list :listbox-state new-listbox-state
                                     :current-path new-path-attempt
                                     :status-message (format nil "Entered ~A"
                                                             (enough-namestring new-path-attempt
                                                                                (uiop:pathname-parent-directory-pathname new-path-attempt)))))))
                      ((uiop:file-exists-p new-path-attempt)
                       (setf current-message-patch (list :status-message (format nil "Selected file: ~A" selected-item-name))))
                      (t
                       (setf current-message-patch (list :status-message (format nil "Cannot access: ~A" selected-item-name)))))))

                 (:terminal-resized
                  (let* ((new-height (max 5 (- (getf msg-data :height) 5))) ; Adjusted height for listbox
                         (base-patch (list :terminal-width (getf msg-data :width)
                                           :terminal-height (getf msg-data :height))))
                    (if (and listbox-state ;; Ensure listbox-state exists
                             (not (= (listbox-model-height listbox-state) new-height)))
                        (let ((resized-lb-state (init-listbox
                                                 (listbox-model-id listbox-state)
                                                 :items (listbox-model-items listbox-state)
                                                 :selected-index (or (listbox-model-selected-index listbox-state) 0)
                                                 :height new-height
                                                 :on-select (listbox-model-on-select listbox-state))))
                          (setf current-message-patch
                                (append base-patch (list :listbox-state resized-lb-state))))
                        (setf current-message-patch base-patch))))

                 ((:request-focus :focus-next :focus-previous :update-focusable-ids)
                  (log4cl:log-debug "Focus message ~S (already handled by handle-focus-message)" msg-type))

                 (otherwise
                  (unless (typep message 'key-event) ; Already handled above
                    (log4cl:log-warn "Unhandled list-based message type in dirli-update: ~A" msg-type))))))

            ;; Catch-all for other unhandled messages
            (t (unless (or (null message) focus-state-patch) ; Don't warn for nil or already handled focus
                 (log4cl:log-warn "Unhandled message in dirli-update: ~S" message))))

          (when current-message-patch
            (setf app-patch (append current-message-patch app-patch)))

          (values app-patch commands))))
  :view-fn
  (lambda (app-state)
    (let* ((status-message (state-ref app-state :status-message))
           (current-path (state-ref app-state :current-path))
           (terminal-width (state-ref app-state :terminal-width))
           (terminal-height (state-ref app-state :terminal-height))
           (output-to-print (state-ref app-state :output-to-print)))
      (vbox :id :dirli-app-root :style '(:width (:percent 100) :height (:percent 100))
            (text :value (format nil "Current Path: ~A" current-path))
            ;; Pass the entire app-state to view-listbox, as it might need other parts of the state
            ;; or its own sub-state which is part of app-state.
            ;; The :widget-id for view-listbox should match the ID used in init-listbox and update-listbox.
            (view-listbox app-state :widget-id :main-listbox)
            (text :value (or status-message ""))
            (text :value (format nil "Terminal Size: ~A x ~A" terminal-width terminal-height))
            (text :value (or output-to-print ""))
            (text :value "Press C-q to quit."))))
  :root-component-dsl
  '(vbox :id :dirli-app-root
    :style '(:width (:percent 100) :height (:percent 100))
    (text :value "Dirli - Directory Listing Application")
    (view-listbox :widget-id :main-listbox)
    (text :value "Press C-q to quit."))
  :command-processor-fn nil ; No external command processor needed for this example
  :event-translator-fn nil ; Use default event translation
  :root-viewport-id :dirli-app-root
  :quit-flag-path '(:should-quit)
  :style-sheet-path '(:current-stylesheet))

;;; Main function to run the application
(defun run-dirli (&rest args)
  (apply #'elmtui.app.api:run-application 'dirli-app args))

;;; Alias for convenience
(defun main ()
  (run-dirli))

;; To run from REPL:
;; (ql:quickload :elmtui.examples.dirli)
;; (elmtui.examples.dirli:run-dirli)
