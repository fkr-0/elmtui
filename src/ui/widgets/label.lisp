;;;===============================================================
;;; File: src/ui/widgets/label.lisp
;;; Standardized Elm-style Label Widget
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.label
  (:use :cl)
  (:import-from :elmtui.view.styled #:make-styled-node)
  (:import-from :elmtui.ui.widgets.utils
                #:defwidget-view
                #:with-widget-model
                #:widget-focused-p)
  (:export #:label-model #:make-label-model ; Struct and its constructor
           #:label-model-id #:label-model-text #:label-model-for ; Accessors
           #:init-label #:view-label)) ; Core TEA functions
(in-package :elmtui.ui.widgets.label)

;;;---------------------------------------------------------------
;;; Model
;;;---------------------------------------------------------------
(defstruct (label-model (:constructor %make-label-model))
  "Model for a label widget.
   ID: Unique identifier.
   TEXT: Text displayed in the label.
   FOR: ID of the form control this label is associated with."
  (id (error "ID must be provided.") :type T :read-only t)
  (text "Label" :type string :read-only nil)
  (for nil :type (or null string symbol) :read-only nil))

;;;---------------------------------------------------------------
;;; Init
;;;---------------------------------------------------------------
(defun init-label (id &key (text "Label") for)
  "Initializes a new label model.
   Returns (values label-model initial-command)."
  (values (%make-label-model :id id
                             :text text
                             :for for)
          nil)) ; No initial commands for a simple label

;;;---------------------------------------------------------------
;;; View (STANDARDIZED FORMAT)
;;;---------------------------------------------------------------
(defwidget-view view-label (app-state
                            :widget-id-var widget-id
                            :model-var model
                            :add-args (text for
                                            style class
                                            width height
                                            tooltip aria-label)
                            :documentation
                            "Creates a UI representation of a label.
   APP-STATE: The application state.
   WIDGET-ID: The unique ID for this label (required).
   TEXT: Text to display in the label. Defaults to model's text if not provided.
   FOR: ID of the form control this label is associated with.
   STYLE: Additional inline styles.
   CLASS: Additional CSS classes.
   WIDTH: Width in columns.
   HEIGHT: Height in rows.
   TOOLTIP: Optional tooltip text to display on hover.
   ARIA-LABEL: Accessibility label for screen readers.")

  ;; Determine effective values from model and/or provided props
  (let* ((effective-text (or text
                             (when model (label-model-text model))
                             "Label"))
         (effective-for (or for
                            (when model (label-model-for model))
                            nil)))

    ;; Create the styled node representing the label
    (make-styled-node
     :type :label
     :props (list* :id widget-id
                   :value effective-text
                   :for effective-for
                   :aria-role "label"
                   ;; Include optional properties only if provided
                   (append
                    (when class (list :class class))
                    (when style (list :style style))
                    (when width (list :width width))
                    (when height (list :height height))
                    (when tooltip (list :title tooltip))
                    (when aria-label (list :aria-label aria-label))))
     :children nil)))

;;;---------------------------------------------------------------
;;; Backward Compatibility Wrapper
;;;---------------------------------------------------------------
;; This is a temporary function to maintain backward compatibility
;; during transition to the new widget pattern
;; (defun view-label (model &key is-focused dispatch-fn)
;;   "DEPRECATED: Use view-label instead."
;;   (declare (ignore is-focused dispatch-fn))
;;   (warn "view-label is deprecated. Use view-label with app-state and :widget-id instead.")
;;   (make-styled-node
;;    :type :label
;;    :props (list :id (label-model-id model)
;;                 :value (label-model-text model)
;;                 :for (label-model-for model)
;;                 :aria-role "label")
;;    :children nil))
