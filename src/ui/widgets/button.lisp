;;;===============================================================
;;; File: src/ui/widgets/button.lisp
;;; Elm-style Button Widget
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.button
  (:use :cl)
  (:import-from :elmtui.view.core #:make-ui-node #:ui-node)
  (:import-from :elmtui.core.async #:cmd-async)
  (:import-from :elmtui.core.events #:send-message) ; Assuming send-message is the target for cmd-async
  (:export #:button-model #:make-button-model ; Struct and its constructor
           #:button-model-id #:button-model-label #:button-model-on-click-msg #:button-model-disabled ; Accessors
           #:init-button #:update-button #:view-button)) ; Core TEA functions
(in-package :elmtui.ui.widgets.button)

;;;---------------------------------------------------------------
;;; Model
;;;---------------------------------------------------------------
(defstruct (button-model (:constructor %make-button-model))
  "Model for a button widget.
   ID: Unique identifier.
   LABEL: Text displayed on the button.
   ON-CLICK-MSG: Message to dispatch when clicked (if not disabled).
   DISABLED: Boolean indicating if the button is interactive."
  (id (error "ID must be provided.") :type T :read-only t)
  (label "Button" :type string :read-only nil)
  (on-click-msg nil :type T :read-only nil)
  (disabled nil :type boolean :read-only nil))

;;;---------------------------------------------------------------
;;; Init
;;;---------------------------------------------------------------
(defun init-button (id &key (label "Button") on-click-msg (disabled nil))
  "Initializes a new button model.
   Returns (values button-model initial-command)."
  (values (%make-button-model :id id
                              :label label
                              :on-click-msg on-click-msg
                              :disabled disabled)
          nil)) ; No initial commands for a simple button

;;;---------------------------------------------------------------
;;; Update
;;;---------------------------------------------------------------
(defun update-button (msg model)
  "Updates the button model based on a message.
   MSG: The message to process. Expected to be :CLICK for a button interaction.
   MODEL: The current button-model instance.
   Returns (values new-button-model command)."
  (check-type model button-model)
  (case msg
    (:click
     (if (and (button-model-on-click-msg model) (not (button-model-disabled model)))
         (values model (list (cmd-async #'send-message (button-model-on-click-msg model))))
         (values model nil))) ; No action if no on-click-msg or button is disabled
    (otherwise
     (values model nil)))) ; Ignore other messages

;;;---------------------------------------------------------------
;;; View
;;;---------------------------------------------------------------
(defun view-button (model is-focused dispatch-fn)
  "Creates a UI-NODE representation of the button.
   MODEL: The current button-model instance.
   IS-FOCUSED: Boolean indicating if this widget currently has focus.
   DISPATCH-FN: A function to call to dispatch messages, e.g., (lambda (msg) (funcall dispatch-fn msg)).
                The generated message should be handled by the parent component's update function,
                which then calls this button's `update-button` with a simplified message like :CLICK.
   Returns a UI-NODE."
  (check-type model button-model)
  (let ((base-class "button")
        (disabled-class (when (button-model-disabled model) "button-disabled"))
        (focused-class (when is-focused "button-focused")))
    (make-ui-node
     :type :container ; Buttons are often containers for text and styling
     :props (list :widget-id (button-model-id model)
                  :class (format nil "~A~@[ ~A~]~@[ ~A~]" ; Combine classes cleanly
                                 base-class disabled-class focused-class)
                  :focusable (not (button-model-disabled model)) ; Only focusable if not disabled
                  ;; The :events property is a list of (event-type handler-lambda).
                  ;; The handler-lambda calls dispatch-fn with a message.
                  ;; This message should be specific enough for the parent to route it.
                  :events (list (list :click ; Raw input event type (e.g., from platform)
                                      (lambda ()
                                        (unless (button-model-disabled model) ; Don't dispatch if disabled
                                          (funcall dispatch-fn
                                                   ;; Message payload for the parent to interpret:
                                                   (list :button-interaction ; Generic type for widget interactions
                                                         :id (button-model-id model)
                                                         :interaction-type :click)))))))
     :children (list (make-ui-node
                      :type :text
                      :props (list :value (button-model-label model))
                      :children nil)))))
