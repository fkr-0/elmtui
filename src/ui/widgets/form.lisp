;;;===============================================================
;;; File: src/ui/widgets/form.lisp
;;; Standardized Elm-style Form Widget
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.form
  (:use :cl :alexandria)
  (:import-from :elmtui.view.styled #:make-styled-node)
  (:import-from :elmtui.core.async #:cmd-async)
  (:import-from :elmtui.core.events #:send-message)
  (:import-from :elmtui.state.model #:application-state #:state-ref #:defmodel)
  (:import-from :elmtui.ui.widgets.utils
                #:defwidget-view
                #:with-widget-model
                #:widget-focused-p)
  (:export #:form-model ; defmodel exports the type name
           #:form-model-id #:form-model-fields #:form-model-on-submit #:form-model-on-change
           #:form-model-validation #:form-model-validation-errors
           #:init-form #:update-form #:view-form
           ;; Message types
           #:msg-form-field-update
           #:msg-form-submit
           #:msg-form-validate))
(in-package :elmtui.ui.widgets.form)

;;;---------------------------------------------------------------
;;; Model
;;;---------------------------------------------------------------
(defmodel form-model
    (:docstring "")
    (id :type T :documentation "Unique identifier for the form." :readonly t)
    (fields :type hash-table :documentation "A hash table mapping field names to their values."
            :initform (make-hash-table :test 'equal))
    (on-submit :type T :documentation "A message to dispatch when the form is submitted."
               :initform nil)
    (on-change :type T :documentation "A message to dispatch when any field changes."
               :initform nil)
    (validation :type function :documentation "Function to validate form data, returns validation-errors."
                :initform nil)
    (validation-errors :type hash-table :documentation "A hash table mapping field names to error messages."
                       :initform (make-hash-table :test 'equal)))
;; "Model for a form widget.")

;;;---------------------------------------------------------------
;;; Messages (Keywords)
;;;---------------------------------------------------------------
(defparameter msg-form-field-update :form-field-update)
(defparameter msg-form-submit :form-submit)
(defparameter msg-form-validate :form-validate)

;;;---------------------------------------------------------------
;;; Helper Functions
;;;---------------------------------------------------------------
;; (defun validate-form (model)
;;   "Validates the form model using its validation function if one is set.
;;    Returns a new model with updated validation-errors."
;;   (let ((validation-fn (form-model-validation model)))
;;     (if validation-fn
;;         (let ((new-validation-errors (funcall validation-fn (form-model-fields model))))
;;           (make-form-model :id (form-model-id model)
;;                            :fields (form-model-fields model)
;;                            :on-submit (form-model-on-submit model)
;;                            :on-change (form-model-on-change model)
;;                            :validation (form-model-validation model)
;;                            :validation-errors new-validation-errors))
;;         model)))

;; (defun form-valid-p (model)
;;   "Returns true if the form has no validation errors."
;;   (zerop (hash-table-count (form-model-validation-errors model))))

;;;---------------------------------------------------------------
;;; Init
;;;---------------------------------------------------------------
(defun init-form (id &key
                          initial-values
                          field-specs
                          on-submit
                          on-change
                          validation-fn)
  "Initializes a new form model.
   ID: The ID for the form.
   INITIAL-VALUES: A plist mapping field names to initial values.
   FIELD-SPECS: A list of plists for advanced field configuration.
   ON-SUBMIT: Message to send when the form is submitted.
   ON-CHANGE: Message to send when any field changes.
   VALIDATION-FN: Function to validate form data.

   Returns (values form-model initial-commands-list)."
  (let ((fields (make-hash-table :test 'equal))
        (validation-errors (make-hash-table :test 'equal)))

    ;; Initialize fields from initial-values if provided
    (when initial-values
      (loop for (key value) on initial-values by #'cddr
            do (setf (gethash key fields) value)))

    ;; Initialize fields from field-specs if provided
    (when field-specs
      (loop for spec in field-specs
            for field-name = (getf spec :name)
            for initial-value = (getf spec :value)
            when field-name
              do (setf (gethash field-name fields) initial-value)))

    ;; Create and return the model
    (values
     (make-form-model :id id
                      :fields fields
                      :on-submit on-submit
                      :on-change on-change
                      :validation validation-fn
                      :validation-errors validation-errors)
     nil))) ; No initial commands

;;;---------------------------------------------------------------
;;; Update
;;;---------------------------------------------------------------
