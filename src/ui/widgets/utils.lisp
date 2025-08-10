;;;===============================================================
;;; File: src/ui/widgets/utils.lisp
;;; Widget Utilities for Standardized Widget Pattern
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.utils
  (:use :cl )
  (:import-from :elmtui.tea-state.api #:application-state #:state-ref)
  (:import-from :elmtui.core.focus #:get-current-focus)

  (:export
   #:get-widget-model
   #:widget-focused-p
   #:with-widget-model
   #:defwidget-view))
(in-package :elmtui.ui.widgets.utils)

;;;-----------------------------------------------------------------------------
;;; Widget Helper Functions
;;;-----------------------------------------------------------------------------

(defun get-widget-model (app-state widget-id &optional model-path)
  "Retrieves the model for a widget from application state.
   APP-STATE: The application state.
   WIDGET-ID: The ID of the widget to retrieve.
   MODEL-PATH: Optional path to navigate within the app-state.

   Returns the widget model or nil if not found."
  (if model-path
      (state-ref app-state (append (if (listp model-path) model-path (list model-path))
                                   (list widget-id)))
      (state-ref app-state widget-id)))

(defun current-focus-id (app-state)
  "Retrieves the current focus ID from the application state.
   APP-STATE: The application state.

   Returns the ID of the currently focused widget."
  (state-ref app-state :current-focus-id))

(defun widget-focused-p (app-state widget-id)
  "Determines if a widget currently has focus.
   APP-STATE: The application state.
   WIDGET-ID: The ID of the widget to check.

   Returns t if the widget has focus, nil otherwise."
  (eql widget-id (get-current-focus app-state)))

(defmacro with-widget-model ((var app-state widget-id &optional model-path) &body body)
  "Binds VAR to the widget model retrieved from app-state and executes BODY.
   Also binds is-focused to whether the widget has focus.

   Example:
     (with-widget-model (button-model app-state widget-id)
       (make-styled-node :type :button :props (list :label (button-model-label button-model))))"
  (let ((app-state-sym (gensym "APP-STATE"))
        (widget-id-sym (gensym "WIDGET-ID")))
    `(let* ((,app-state-sym ,app-state)
            (,widget-id-sym ,widget-id)
            (,var (get-widget-model ,app-state-sym ,widget-id-sym ,model-path))
            (is-focused (widget-focused-p ,app-state-sym ,widget-id-sym))
            )
       (declare (ignorable is-focused))
       ,@body)))

(defmacro defwidget-view
    (name (app-state-var &key (widget-id-var 'widget-id)
                           (model-var 'model)
                           model-path
                           (add-args '())
                           documentation)
     &body body)
  "Define a standardized widget view function.

   Arguments:
   - NAME: The name of the view function to define.
   - APP-STATE-VAR: Symbol to bind to the application state.
   - WIDGET-ID-VAR: Symbol to bind to the widget ID (defaults to 'widget-id).
   - MODEL-VAR: Symbol to bind to the model (defaults to 'model).
   - MODEL-PATH: Optional path within app-state to locate the model.
   - ADD-ARGS: Additional arguments to include in the function signature.
   - DOCUMENTATION: Documentation string for the function.
   - BODY: The body of the view function.

   Example:
   (defwidget-view view-button (app-state :model-path 'buttons
                                        :add-args (&key label disabled)
                                        :documentation \"Render a button widget.\")
     (make-styled-node :type :button
                      :props (list :id widget-id
                                  :label (or label (button-model-label model))
                                  :disabled disabled
                                  :focused is-focused)))"
  `(defun ,name (,app-state-var &key ,widget-id-var ,@add-args)
     ,@(when documentation (list documentation))
     (with-widget-model (,model-var ,app-state-var ,widget-id-var ,model-path)
       ,@body)))
