;;;===============================================================
;;; File: src/ui/widgets/form.lisp
;;; Elm-style Form Widget
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.form
  (:use :cl :alexandria)
  (:import-from :elmtui.view.core #:make-ui-node #:ui-node)
  ;; We need to know about the child widget types to call their update/view functions
  ;; This creates a dependency. Ideally, child update/view functions could be passed in.
  (:import-from :elmtui.ui.widgets.textinput #:init-textinput #:update-textinput #:view-textinput #:textinput-model)
  (:import-from :elmtui.ui.widgets.button #:init-button #:update-button #:view-button #:button-model)
  (:import-from :elmtui.core.events #:cmd)
  (:export #:form-model #:make-form-model
           #:form-model-id #:form-model-children-models #:form-model-on-submit
           #:init-form #:update-form #:view-form
           ;; Message types
           #:msg-form-child-update
           #:msg-form-submit))
(in-package :elmtui.ui.widgets.form)

;;;---------------------------------------------------------------
;;; Model
;;;---------------------------------------------------------------
(defstruct (form-model (:constructor %make-form-model))
  "Model for a form widget.
   ID: Unique identifier for the form itself.
   CHILDREN-MODELS: A hash table mapping child widget IDs to their respective models.
   ON-SUBMIT: A message to dispatch when the form is submitted (e.g., by a submit button)."
  (id (error "ID must be provided.") :type T :read-only t)
  (children-models (make-hash-table :test 'equal) :type hash-table)
  (on-submit nil :type T))

;;;---------------------------------------------------------------
;;; Messages
;;;---------------------------------------------------------------
;; (:form-child-update :child-id <id> :child-msg <original-msg>) - Wraps messages from children
;; (:form-submit) - Typically triggered by a submit button within the form

(defparameter msg-form-child-update :form-child-update)
(defparameter msg-form-submit :form-submit)

;;;---------------------------------------------------------------
;;; Init
;;;---------------------------------------------------------------
(defun init-form (id &key child-specs (on-submit nil))
  "Initializes a new form model and its children.
   ID: The ID for the form.
   CHILD-SPECS: A list of plists, each specifying a child:
                  '(:id <child-id> :type <:button|:textinput|...> :init-args (...))
                  Example: '((:id :name-input :type :textinput :init-args (:placeholder \"Enter name\"))
                             (:id :submit-btn :type :button :init-args (:label \"Submit\" :on-click-msg '(:form-submit))))
   ON-SUBMIT: Message to send when the form's submit action is triggered.
   Returns (values form-model initial-commands-list)."
  (let ((form-model (%make-form-model :id id :on-submit on-submit))
        (all-initial-commands nil))
    (loop for spec in child-specs
          for child-id = (getf spec :id)
          for child-type = (getf spec :type)
          for init-args = (getf spec :init-args)
          do
       (multiple-value-bind (child-model initial-commands)
           (case child-type
             (:textinput (apply #'init-textinput child-id init-args))
             (:button
              ;; If button's on-click is meant to submit the form,
              ;; its :on-click-msg should be something the form's update can recognize,
              ;; or it could be a direct msg-form-submit.
              ;; For this example, let's assume :on-click-msg for a submit button
              ;; would be '(:form-child-update :child-id <btn-id> :child-msg :form-submit-request)
              ;; or simply '(:form-submit) if the button is tightly coupled.
              ;; Here, we assume init-args for button includes its specific on-click.
              (apply #'init-button child-id init-args))
             ;; TODO: Add other child types like :label, etc.
             (t (error "Unsupported child type for form: ~S" child-type)))
         (setf (gethash child-id (form-model-children-models form-model)) child-model)
         (when initial-commands
           (setf all-initial-commands (append initial-commands all-initial-commands)))))
    (values form-model (nreverse all-initial-commands))))

;;;---------------------------------------------------------------
;;; Update
;;;---------------------------------------------------------------
(defun update-form (msg model)
  "Updates the form model, potentially delegating to child components.
   Returns (values new-form-model command-list)."
  (check-type model form-model)
  (let ((new-model (copy-structure model))
        (commands nil)
        ;; Make a deep copy of the children-models hash-table for modification
        (new-children-models (alexandria:copy-hash-table (form-model-children-models model) :test 'equal)))
    (setf (form-model-children-models new-model) new-children-models)

    (etypecase msg
      ;; Message from a child: '(:form-child-update :child-id <id> :child-msg <original-msg>)
      ((cons (eql msg-form-child-update))
       (let* ((child-id (getf (rest msg) :child-id))
              (child-msg (getf (rest msg) :child-msg))
              (child-model (gethash child-id new-children-models)))
         (when child-model
           (multiple-value-bind (updated-child-model child-commands)
               (etypecase child-model
                 (textinput-model (update-textinput child-msg child-model))
                 (button-model (update-button child-msg child-model))
                 ;; TODO: Add other child model types
                 )
             (setf (gethash child-id new-children-models) updated-child-model)
             (when child-commands
               (setf commands (append child-commands commands)))

             ;; Special handling if a button inside the form signals a submit action
             ;; This is a common pattern: a button's click results in a message
             ;; that the form interprets as its own submission.
             (when (and (typep child-model 'button-model)
                        (equal child-msg :click) ; Assuming button's update returns :click if it was clicked
                        (equal (button-model-on-click-msg child-model) msg-form-submit)) ; Check if this button is the submit button
               (when (form-model-on-submit new-model)
                 (push (form-model-on-submit new-model) commands)))))))

      ;; Form-level submit action (e.g., triggered by a button or Enter key in a field)
      ((eql msg msg-form-submit)
       (when (form-model-on-submit new-model)
         (push (form-model-on-submit new-model) commands))))

    (values new-model (nreverse commands))))

;;;---------------------------------------------------------------
;;; View
;;;---------------------------------------------------------------
(defun view-form (model app-state dispatch-fn) ; Added app-state argument
  "Creates a UI-NODE representation of the form and its children.
   MODEL: The current form-model instance.
   APP-STATE: The global application state (needed to check focus).
   DISPATCH-FN: A function to call to dispatch messages. Child messages will be wrapped.
   Returns a UI-NODE."
  (check-type model form-model)
  ;; It's generally better practice in TEA for the parent view to pass down
  ;; specific relevant state (like is-focused) rather than the whole app-state.
  ;; However, for simplicity here, we pass app-state to get the focused ID.
  ;; A better approach might involve the main view function calculating focus
  ;; for each child and passing it explicitly.
  (let ((child-ui-nodes nil)
        (focused-widget-id (state-ref app-state :focused-widget-id))) ; Get current focus ID
    (maphash (lambda (child-id child-model)
               (let ((is-child-focused (equal child-id focused-widget-id)) ; Check if this child is focused
                     (child-dispatch-fn (lambda (child-msg)
                                          (funcall dispatch-fn
                                                   (list msg-form-child-update
                                                         :child-id child-id
                                                         :child-msg child-msg)))))
                 (push (etypecase child-model
                         (textinput-model (view-textinput child-model child-dispatch-fn)) ; textinput view uses internal focus state
                         (button-model (view-button child-model is-child-focused child-dispatch-fn)) ; Pass focus state to button
                         ;; TODO: Add other child model types (e.g., label doesn't need focus)
                         ;; (label-model (view-label child-model child-dispatch-fn))
                         )
                       child-ui-nodes)))
             (form-model-children-models model))

    (make-ui-node
     :type :container ; Forms are containers
     :props (list :widget-id (form-model-id model)
                  :class "form"
                  :focusable nil) ; Forms themselves aren't usually focusable, their children are
     :children (nreverse child-ui-nodes))))