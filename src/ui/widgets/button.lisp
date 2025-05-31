;;;===============================================================
;;; File: src/ui/widgets/button.lisp
;;; Elm-style Button Widget with Standardized Interface
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.button
  (:use :cl)
  (:import-from :elmtui.view.core #:make-ui-node #:ui-node)
  (:import-from :elmtui.view.styled #:make-styled-node #:styled-ui-node)
  (:import-from :elmtui.core.async #:cmd-async)
  (:import-from :elmtui.core.events #:send-message)
  (:import-from :elmtui.ui.widgets.utils
   :defwidget-view
                :with-widget-model
   :widget-focused-p)
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
         (values model (list (cmd-async #'send-message :args (button-model-on-click-msg model))))
         (values model nil))) ; No action if no on-click-msg or button is disabled
    (otherwise
     (values model nil)))) ; Ignore other messages

;;;---------------------------------------------------------------
;;; View (NEW STANDARDIZED FORMAT)
;;;---------------------------------------------------------------
(defwidget-view view-button (app-state
                             :widget-id-var widget-id :model-var model
                             :add-args (label on-click disabled
                                              tooltip aria-label class)
                             :documentation
                             "Creates a UI-NODE representation of a button.
   APP-STATE: The application state.
   WIDGET-ID: The unique ID for this button (required).
   LABEL: Text to display on the button. Defaults to model's label if not provided.
   ON-CLICK: Message to send when clicked. Defaults to model's on-click-msg if not provided.
   DISABLED: Whether the button is disabled. Defaults to model's disabled property if not provided.
   TOOLTIP: Optional tooltip text to display on hover.
   ARIA-LABEL: Accessibility label for screen readers.
   CLASS: Additional CSS classes to apply.")

  ;; Determine effective values from model and/or provided props
  (let* ((effective-label (or label
                              (when model (button-model-label model))
                              "Button"))
         (effective-on-click (or on-click
                                 (when model (button-model-on-click-msg model))
                                 nil))
         (effective-disabled (or disabled
                                 (when model (button-model-disabled model))
                                 nil))
         (is-focused (widget-focused-p app-state widget-id))
         ;; Build CSS classes
         (base-class "button")
         (disabled-class (when effective-disabled "button-disabled"))
         (focused-class (when is-focused "button-focused"))
         (custom-class class)
         (all-classes (remove nil (list base-class disabled-class focused-class custom-class))))

    ;; Create the styled node representing the button
    (make-styled-node
     :type :button
     :props (list* :id widget-id
                   :focusable t
                   :value effective-label    ; Value can be used by renderers
                   :label effective-label    ; Label is the visible text
                   :disabled effective-disabled
                   :on-click (unless effective-disabled effective-on-click)
                   :class (format nil "~{~A~^ ~}" all-classes) ; Join classes with spaces
                   :aria-role "button"
                   :aria-disabled (if effective-disabled "true" "false")
                   ;; Include optional properties only if provided
                   (append
                    (when tooltip (list :title tooltip))
                    (when aria-label (list :aria-label aria-label))))
     :children nil)))

;;;---------------------------------------------------------------
;;; Backward Compatibility Wrapper
;;;---------------------------------------------------------------
;; This is a temporary function to maintain backward compatibility
;; during transition to the new widget pattern
;; (defun view-button (model &key is-focused dispatch-fn)
;;   "DEPRECATED: Use view-button instead."
;;   (warn "view-button is deprecated. Use view-button with app-state and :widget-id instead.")
;;   (make-styled-node
;;    :type :button
;;    :props (list :id (button-model-id model)
;;                 :label (button-model-label model)
;;                 :disabled (button-model-disabled model)
;;                 :on-click (when (and dispatch-fn (button-model-on-click-msg model))
;;                             (lambda (_)
;;                               (funcall dispatch-fn (button-model-on-click-msg model))))
;;                 :focusable t
;;                 :class (format nil "button~@[ button-disabled~*~]~@[ button-focused~*~]"
;;                                (button-model-disabled model)
;;                                is-focused)
;;                 :aria-role "button"
;;                 :aria-disabled (if (button-model-disabled model) "true" "false"))
;;    :children nil))
