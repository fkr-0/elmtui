;;;===============================================================
;;; File: src/ui/widgets/label.lisp
;;; Elm-style Label Widget
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.label
  (:use :cl)
  (:import-from :elmtui.view.core #:make-ui-node #:ui-node)
  (:export #:label-model #:make-label-model ; Struct and its constructor
           #:label-model-id #:label-model-text ; Accessors
           #:init-label #:update-label #:view-label)) ; Core TEA functions
(in-package :elmtui.ui.widgets.label)

;;;---------------------------------------------------------------
;;; Model
;;;---------------------------------------------------------------
(defstruct (label-model (:constructor %make-label-model))
  "Model for a label widget.
   ID: Unique identifier.
   TEXT: Text content of the label."
  (id (error "ID must be provided.") :type T :read-only t)
  (text "" :type string :read-only nil))

;;;---------------------------------------------------------------
;;; Init
;;;---------------------------------------------------------------
(defun init-label (id &key (text ""))
  "Initializes a new label model.
   Returns (values label-model initial-command)."
  (values (%make-label-model :id id :text text)
          nil)) ; No initial commands for a simple label

;;;---------------------------------------------------------------
;;; Update
;;;---------------------------------------------------------------
(defun update-label (msg model)
  "Updates the label model. Labels are typically static, so this usually does nothing.
   MSG: The message to process.
   MODEL: The current label-model instance.
   Returns (values new-label-model command)."
  (check-type model label-model)
  (declare (ignore msg)) ; Labels generally don't react to messages
  (values model nil))    ; Return model unchanged, no command

;;;---------------------------------------------------------------
;;; View
;;;---------------------------------------------------------------
(defun view-label (model dispatch-fn)
  "Creates a UI-NODE representation of the label.
   MODEL: The current label-model instance.
   DISPATCH-FN: A function to call to dispatch messages (not typically used by label).
   Returns a UI-NODE."
  (check-type model label-model)
  (declare (ignore dispatch-fn)) ; Labels typically don't dispatch messages
  (make-ui-node
   :type :text
   :props (list :widget-id (label-model-id model)
                :value (label-model-text model)
                :class "label" ; For styling
                :focusable nil) ; Labels are not usually focusable
   :children nil))
