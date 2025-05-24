;;;===============================================================
;;; File: examples/keymap-app.lisp
;;; Example application demonstrating keymap usage
;;;===============================================================
(uiop:define-package :elmtui.examples.keymap-app
  (:use :cl :alexandria)
  (:import-from :elmtui.runtime #:def-elm-app #:run-app)
  (:import-from :elmtui.view.core #:ui-node #:make-ui-node)
  (:import-from :elmtui.state #:state-ref #:make-application-state)
  (:import-from :elmtui.state.update #:defupdate)
  (:import-from :elmtui.ui.widgets.counter
    #:init :update :view #:counter-widget-id)
  (:export #:main))

(in-package :elmtui.examples.keymap-app)

(defparameter *counter-a-id* :counter-a)

;;;--------------------------------------------------------------
;;; Application Definition
;;;--------------------------------------------------------------

(defun app-init ()
  "Initializes the application model."
  (let ((counter-a-model (elmtui.ui.widgets.counter:init :initial-value 10 :id *counter-a-id*)))
    ;; Initial model plist for the whole app
    (values
      (list
        :widgets (list (cons *counter-a-id* counter-a-model)) ; Store widget models here
        :current-focus-id *counter-a-id* ; Focus the counter initially
        :focusable-elements (list *counter-a-id*)
        :should-quit nil)
      nil))) ; No initial commands

(defupdate app-update (app-state message)
  "Main application update function.
   Returns (values state-patch-plist commands-list)."
  (let ((current-widgets (state-ref app-state :widgets))
         (patch-list nil)
         (commands-list nil))

    (case (if (listp message) (first message) nil)
      (:dispatch-to-widget
        (let* ((target-widget-id (second message))
                (widget-message (third message))
                ;; (original-binding (fourth message)) ; Available if needed
                (widget-model (assoc-value current-widgets target-widget-id)))

          (if widget-model
            (multiple-value-bind (widget-model-patch widget-commands)
              (elmtui.ui.widgets.counter:update widget-model widget-message) ; Assuming all widgets have compatible update signature for now

              ;; Create an updated widget model by merging the patch
              (let ((updated-widget-model (copy-list widget-model))) ; Start with a copy
                (loop for (key value) on widget-model-patch by #'cddr
                  do (setf (getf updated-widget-model key) value))

                ;; Update the list of widgets
                (let ((new-widgets (mapcar (lambda (pair)
                                             (if (eq (car pair) target-widget-id)
                                               (cons target-widget-id updated-widget-model)
                                               pair))
                                     current-widgets)))
                  (push :widgets patch-list)
                  (push new-widgets patch-list)))
              (setf commands-list (append widget-commands commands-list)))
            (log:warn "KEYMAP-APP: No model found for widget ~S to dispatch message ~S" target-widget-id widget-message))))

      (:app-quit-requested
        (push :should-quit patch-list)
        (push t patch-list)
        (log:info "KEYMAP-APP: Quit requested."))

      ;; Handle raw key events for global bindings (example)
      (:key-event
        (let ((norm-key (elmtui.core.keymap:key-event->normalized-key message)))
          (cond
            ((elmtui.core.keymap:normalized-key= norm-key (elmtui.core.keymap:parse-key-string "C-q"))
              (log:info "KEYMAP-APP: Global C-q pressed.")
              (push :should-quit patch-list)
              (push t patch-list)
              (setf commands-list (list '(:app-quit-requested (:source :global-C-q))))) ; Send quit message
            (t (log:debug "KEYMAP-APP: Unhandled global key event: ~S" message)))))

      (otherwise
        (log:debug "KEYMAP-APP: Unhandled message: ~S" message)))

    (values (nreverse patch-list) commands-list)))


(defun app-view (app-state dispatch-fn)
  "Main application view function."
  (declare (ignore dispatch-fn))
  (let* ((counter-a-model (assoc-value (state-ref app-state :widgets) *counter-a-id*))
          (counter-a-view (when counter-a-model (elmtui.ui.widgets.counter:view counter-a-model))))
    (make-ui-node :type :app-root
      :props nil
      :children (list
                  (make-ui-node :type :text :props (list :value "Keymap Demo App. Focus counter and press + or - or Enter. C-q to quit."))
                  (when counter-a-view counter-a-view)))))

(def-elm-app keymap-example-app
  :init #'app-init
  :update #'app-update
  :view #'app-view)

(defun main ()
  "Run the keymap example application."
  (elmtui.runtime:run-app :app-name 'keymap-example-app))
