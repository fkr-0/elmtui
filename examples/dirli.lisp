(uiop:define-package :elmtui.examples.dirli
  (:use :cl :elmtui.core.loop :elmtui.ui.widgets.listbox
   :log4cl)
  (:import-from :elmtui.state.update #:defupdate)
  (:import-from :elmtui.core.focus #:handle-focus-message) ; For focus management
  (:import-from :elmtui.state #:state-ref) ; For reading state
  (:import-from :elmtui.ui.widgets.utils :defwidget-view)
  (:import-from :elmtui.style.presets #:dark-theme) ; Import the theme
  (:import-from :elmtui.core.event-compat #:normalize-event) ; Import event normalizer
  (:import-from :elmtui.core.events #:key-event #:key-event-key) ; Canonical event types
  (:import-from :elmtui.view.core #:vbox #:text) ; Import vbox and text (for labels)
  (:import-from :elmtui.ui.widgets.listbox #:view-listbox) ; Import listbox view
  (:export :main
   :run-dirli))

(in-package :elmtui.examples.dirli)
;;; Model Definition
;; (defstruct dirli-model ...) ; Not strictly needed with defupdate

;;; Init Function
(defun dirli-init-fn ()
  (let* ((current-path (uiop:getcwd))
         (items (handler-case
                    (loop for entry in (append (uiop:subdirectories current-path)
                                               (uiop:directory-files current-path))
                          collect (let ((name (enough-namestring entry current-path)))
                                    (if (uiop:directory-exists-p entry)
                                        (concatenate 'string name "/")
                                        name)))
                  (error (e)
                    (log4cl:log-error "Error listing directory ~A: ~A" current-path e)
                    (list (format nil "Error listing ~A" current-path)))))
         (listbox-model (elmtui.ui.widgets.listbox:init-listbox
                         :main-listbox ; Give it an ID for focus
                         :items items
                         :height 10
                         :selected-index (when items 0) ; Select first item if items exist
                         :on-select '(:listbox-item-selected)))) ; Enable selection callback
    ;; (when items (setf (listbox-model-is-focused listbox-model) t))
                                        ; Focus listbox if items exist
    (log4cl:log-debug "Initial items: ~S, Initial listbox model: ~S" items listbox-model)
    (values
     (list :listbox-state listbox-model
           :current-path current-path
           :status-message nil
           :terminal-width 80
           :terminal-height 24
           :output-to-print nil
           :should-quit nil
           :current-focus-id :main-listbox ; Start with listbox focused
           :prev-focus-id nil ; No previous focus initially
           :focusable-elements (list :main-listbox)
           :current-stylesheet dark-theme)
     nil))) ; No initial commands

;;; Update Function
(defupdate dirli-update-fn (app-state message)
  (let* ((focus-state-patch (handle-focus-message app-state message))
         (app-patch nil) ; State update patch to return
         (commands nil)  ; Commands to execute
         (current-message-patch nil) ; Message-specific patch
         (listbox-id :main-listbox)
         ;; Get potentially updated focus state from focus-state-patch or original app-state
         (current-focus (or (getf focus-state-patch :current-focus-id) (state-ref app-state :current-focus-id)))
         (prev-focus (or (getf focus-state-patch :prev-focus-id) (state-ref app-state :prev-focus-id)))
         (listbox-state (state-ref app-state :listbox-state))
         ;; Normalize the event to canonical format if it's an event structure
         (normalized-message (normalize-event message)))

    ;; --- Focus sync logic for listbox ---
    ;; This logic uses current-focus and prev-focus which might have been updated by handle-focus-message
    (when (not (equal current-focus prev-focus)) ; Only act if focus actually changed
      (cond
        ((and (equal current-focus listbox-id)
              ;; (not (listbox-model-is-focused listbox-state))
              )
         ;; Listbox gained focus
         (log4cl:log-debug "DIRLISTER-UPDATE-FN: Listbox ~A gained focus." listbox-id)
         (multiple-value-bind (new-listbox-state listbox-commands)
             (update-listbox '(:listbox-focus) listbox-state)
           (setf app-patch (append app-patch (list :listbox-state new-listbox-state)))
           (setf commands (append commands listbox-commands))))
        ((and (equal prev-focus listbox-id) ; Check if previous focus was this listbox
              (not (equal current-focus listbox-id))
              ;; (listbox-model-is-focused listbox-state)
              )
         ;; Listbox lost focus
         (log4cl:log-debug "DIRLISTER-UPDATE-FN: Listbox ~A lost focus." listbox-id)
         (multiple-value-bind (new-listbox-state listbox-commands)
             (update-listbox '(:listbox-blur) listbox-state)
           (setf app-patch (append app-patch (list :listbox-state new-listbox-state)))
           (setf commands (append commands listbox-commands))))))

    (if focus-state-patch
        ;; If handle-focus-message produced changes, merge them
        (setf app-patch (append focus-state-patch app-patch))
        ;; Else, handle application-specific messages
        (cond
          ;; Handle key events (now using normalized canonical format)
          ((and normalized-message (typep normalized-message 'key-event)
                (equal current-focus listbox-id))
           (log4cl:log-debug "DIRLISTER-UPDATE-FN: Processing normalized key event: ~S" normalized-message)
           (let ((listbox-msg `(:listbox-key-press :key ,(key-event-key normalized-message))))
             (multiple-value-bind (new-listbox-state listbox-commands)
                 (update-listbox listbox-msg listbox-state)
               (setf current-message-patch (list :listbox-state new-listbox-state))
               (setf commands (append listbox-commands commands)))))

          ;; Handle list-based messages
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
                     (let* ((new-items (handler-case
                                           (loop for entry in (append (uiop:subdirectories new-path-attempt)
                                                                      (uiop:directory-files new-path-attempt))
                                                 collect (let ((name (enough-namestring entry new-path-attempt)))
                                                           (if (uiop:directory-exists-p entry)
                                                               (concatenate 'string name "/")
                                                               name)))
                                         (error (e)
                                           (log4cl:log-error "Error listing directory ~A: ~A" new-path-attempt e)
                                           (list (format nil "Error listing ~A" new-path-attempt)))))
                            (new-listbox-model (elmtui.ui.widgets.listbox:init-listbox
                                                :main-listbox
                                                :items new-items
                                                :height (listbox-model-height listbox-state)
                                                :selected-index (when new-items 0) ; Select first on new dir
                                                :on-select (listbox-model-on-select listbox-state))))
                       ;; (setf (listbox-model-is-focused new-listbox-model) t) ; Focus new listbox
                       (setf current-message-patch (list :listbox-state new-listbox-model
                                                         :current-path new-path-attempt
                                                         :status-message nil))))
                    ((uiop:file-exists-p new-path-attempt)
                     (setf current-message-patch (list :status-message (format nil "Selected file: ~A" selected-item-name))))
                    (t
                     (setf current-message-patch (list :status-message (format nil "Cannot access: ~A" selected-item-name)))))))

               (:terminal-resized
                (let* ((new-height (max 5 (- (getf msg-data :height) 5)))
                       (base-patch (list :terminal-width (getf msg-data :width)
                                         :terminal-height (getf msg-data :height))))
                  (if (and (slot-exists-p listbox-state 'height)
                           (not (= (listbox-model-height listbox-state) new-height)))
                      (let ((resized-lb-model (elmtui.ui.widgets.listbox:init-listbox
                                               (listbox-model-id listbox-state)
                                               :items (listbox-model-items listbox-state)
                                               :selected-index (or (listbox-model-selected-index listbox-state) 0)
                                               :height new-height
                                               :on-select (listbox-model-on-select listbox-state))))
                        ;; (setf (listbox-model-is-focused resized-lb-model) (listbox-model-is-focused listbox-state))
                        (setf current-message-patch
                              (append base-patch (list :listbox-state resized-lb-model))))
                      (setf current-message-patch base-patch))))

               (:app-quit-requested
                (setf current-message-patch (list :should-quit t))
                (log4cl:log-info "App quit requested, setting should-quit flag."))

               ((:request-focus :focus-next :focus-previous :update-focusable-ids)
                (log4cl:log-debug "Focus message ~S (already handled by handle-focus-message)" msg-type))
               (otherwise
                (unless (typep message 'elmtui.core.event-types:key-event)
                  (log4cl:log-warn "Unhandled list-based message type in dirli-update-fn: ~A" msg-type))))))))
    ;; Apply the patch from the current message handling
    (when current-message-patch
      (setf app-patch (append current-message-patch app-patch)))

    ;; Return the state update patch and commands to execute


    (values app-patch commands)))

;;; View Function (defined using define-view macro)
(defwidget-view dirli-main-view (app-state :widget-id-var widget-id :model-var _unused_model_)
  (declare (ignore _unused_model_)) ;; Explicitly ignore the model parameter since we're not using it
  (let* (;(listbox-state (state-ref app-state :listbox-state))
         (status-message (state-ref app-state :status-message))
         (current-path (state-ref app-state :current-path))
         (terminal-width (state-ref app-state :terminal-width))
         (terminal-height (state-ref app-state :terminal-height))
         (output-to-print (state-ref app-state :output-to-print)))
    ;; Create the main view structure
    (vbox :id :dirli-app-root
          (text :value (format nil "Current Path: ~A" current-path))
          (view-listbox app-state :widget-id :main-listbox) ; Render the listbox
          (text :value (or status-message ""))
          (text :value (format nil "Terminal Size: ~A x ~A" terminal-width terminal-height))
          (text :value (or output-to-print ""))
          (text :value "Press C-q to quit."))))

;;; Subscriptions Function (Example)
(defun dirli-subscriptions-fn (app-state)
  (declare (ignore app-state))
  '()) ; No special subscriptions for now

;;; Entry Point
(defun main ()
  (elmtui.runtime:def-elm-app dirli-app
    :init #'dirli-init-fn
    :update #'dirli-update-fn
    :view #'dirli-main-view
    :subscriptions #'dirli-subscriptions-fn)
  (elmtui.runtime:run-app :app-name 'dirli-app))
