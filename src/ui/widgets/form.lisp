;; ;;;===============================================================
;; ;;; File: src/ui/widgets/form.lisp
;; ;;; Standardized Elm-style Form Widget
;; ;;;===============================================================
;; (uiop:define-package :elmtui.ui.widgets.form
;;   (:use :cl :alexandria)
;;   (:import-from :elmtui.ui.api #:component #:make-state-patch #:id-from-path #:get-path)
;;   (:import-from :elmtui.state #:make-update-result)
;;   (:import-from :elmtui.view.styled #:make-styled-node)
;;   ;; (:import-from :elmtui.core.async #:cmd-async) ; Not used directly
;;   ;; (:import-from :elmtui.core.events #:send-message) ; Not used directly
;;   ;; (:import-from :elmtui.state.model #:application-state #:state-ref #:defmodel) ; Using standard component model
;;   ;; (:import-from :elmtui.ui.widgets.utils ; Not using these legacy utils
;;   ;;               #:defwidget-view
;;   ;;               #:with-widget-model
;;   ;;               #:widget-focused-p)
;;   (:export #:form #:make-form ; Class name and constructor
;;            ;; Messages (keywords)
;;            #:msg-form-field-update
;;            #:msg-form-submit
;;            #:msg-form-validate
;;            #:msg-form-set-value ; For setting a field value externally
;;            ))
;; (in-package :elmtui.ui.widgets.form)

;; ;;;---------------------------------------------------------------\\\n;;; Form Component\\\n;;;---------------------------------------------------------------\\\n(defclass form (component) ()
;;   ;; (:documentation "A form component that groups child input components and manages form-level actions like submission and validation. Child components are defined in the DSL and their state is managed individually.")
;; ;; )
;; (defparameter msg-form-submit :form-submit)
;; (defparameter msg-form-validate :form-validate)
;; (defparameter msg-form-set-value :form-set-value) ; (:form-set-value :field-name <field-name> :value <new-value>)

;; (defun make-form (&key id)
;;   "Creates a new form component instance."
;;   (make-instance 'form :id id))

;; ;;;---------------------------------------------------------------\\\n;;; Messages (Keywords)\\\
;; ;;;---------------------------------------------------------------\\\n(defparameter msg-form-field-update :form-field-update)

;; ;;;---------------------------------------------------------------\\\n;;; Init Method\\\n;;;---------------------------------------------------------------\\\n(defmethod init ((component form) &key id-path
;;                                     initial-field-values ; A plist (:field1 val1 :field2 val2)
;;                                     initial-on-submit    ; Command/message for submit
;;                                     initial-on-change    ; Command/message for field change (if form tracks overall change)
;;                                     initial-validation-fn ; A symbol or lambda for validation
;;                                     initial-child-specs  ; Children are defined via DSL, passed by layout
;;                                     &allow-other-keys)
;;   (let ((component-id (id-from-path id-path))
;;         (field-values (make-hash-table :test 'equal))
;;         (child-patches nil)
;;         (child-commands nil)
;;         (child-ids nil)) ; IDs of direct children managed by this form (if any, typically layout handles children)

;;     ;; Populate initial field values if provided
;;     (loop for (key value) on initial-field-values by #'cddr
;;           do (setf (gethash key field-values) value))

;;     ;; Initialize children if form directly manages them (less common with layout components)
;;     (dolist (child-spec initial-child-specs)
;;       (let* ((child-type (first child-spec))
;;              (child-id (second child-spec))
;;              (child-initargs (cddr child-spec))
;;              (child-instance (make-instance child-type))
;;              (child-id-path-for-child-init (list :components child-id)))
;;         (multiple-value-bind (initialized-child-instance patches-from-child commands-from-child)
;;             (apply #'init child-instance :id-path child-id-path-for-child-init child-initargs)
;;           (declare (ignore initialized-child-instance))
;;           (push child-id child-ids)
;;           (setf child-patches (append patches-from-child child-patches))
;;           (setf child-commands (append commands-from-child child-commands)))))

;;     (values component
;;             (append
;;              (list (make-state-patch `(:components ,component-id)
;;                                      `(:type ,(type-of component)
;;                                        :id ,component-id
;;                                        :field-values ,field-values ; Store actual values here
;;                                        :on-submit ,initial-on-submit
;;                                        :on-change ,initial-on-change
;;                                        :validation-fn ,initial-validation-fn
;;                                        :validation-errors ,(make-hash-table :test 'equal) ; Initially no errors
;;                                        :children-ids ,(nreverse child-ids)))) ; If form has direct children
;;              child-patches)
;;             child-commands)))

;; ;;;---------------------------------------------------------------\\\n;;; Update Method\\\n;;;---------------------------------------------------------------\\\n(defmethod update ((component form) state msg &key id-path)
;;   (let* ((component-id (id-from-path id-path))
;;          (component-state-path `(:components ,component-id))
;;          (form-props (getf state component-state-path))
;;          (patches nil)
;;          (commands nil))\n
;;     (unless form-props
;;       (warn \"Form ~A state not found at ~S\" component-id component-state-path)\n      (return-from update (make-update-result :patches nil :commands nil)))

;;     (let ((current-field-values (getf form-props :field-values))
;;           (on-submit (getf form-props :on-submit))\n          (on-change (getf form-props :on-change))\n          (validation-fn (getf form-props :validation-fn)))

;;       (etypecase msg
;;         ;; (:form-field-update :field-name <field-name> :value <new-value>)
;;         ;; This message is typically sent by child input components to the form
;;         ((cons (eql msg-form-field-update) t)
;;          (let ((field-name (getf (rest msg) :field-name))
;;                (new-value (getf (rest msg) :value)))
;;            (when field-name
;;              (let ((updated-field-values (alexandria:copy-hash-table current-field-values)))
;;                (setf (gethash field-name updated-field-values) new-value)
;;                (push (make-state-patch (append component-state-path \'(:field-values)) updated-field-values) patches)
;;                (when on-change ; If an on-change handler for the whole form is defined
;;                  (push (append on-change (list :field-name field-name :value new-value)) commands))))))

;;         ;; (:form-set-value :field-name <field-name> :value <new-value>)
;;         ;; For externally setting a form field\'s value (e.g. programmatically)
;;         ((cons (eql msg-form-set-value) t)
;;          (let ((field-name (getf (rest msg) :field-name))
;;                (value (getf (rest msg) :value)))
;;            (when field-name
;;              (let ((updated-field-values (alexandria:copy-hash-table current-field-values)))
;;                (setf (gethash field-name updated-field-values) value)
;;                (push (make-state-patch (append component-state-path \'(:field-values)) updated-field-values) patches)
;;                ;; Also, we might need to inform the actual child input component to update its view/internal state
;;                ;; This assumes child components respond to a generic :set-value message or similar.
;;                ;; The child-id here would need to be known or discoverable.
;;                ;; For now, this only updates the form\'s record of the value.
;;                ;; A more robust solution might involve a command that the application runner
;;                ;; uses to find the child component by its role/name within the form and send it a message.
;;                (let ((child-component-id field-name)) ; Assuming field-name is the child component ID
;;                   (push `(:message-to ,child-component-id (:set-property :value ,value)) commands))
;;                ))))

;;         ;; :form-submit
;;         ((eql msg-form-submit)
;;          (let ((errors (if validation-fn
;;                            (funcall validation-fn current-field-values)
;;                            (make-hash-table :test 'equal))))
;;            (push (make-state-patch (append component-state-path \'(:validation-errors)) errors) patches)
;;            (if (zerop (hash-table-count errors))
;;                (when on-submit
;;                  ;; Submit command should carry the current field values
;;                  (if (listp on-submit) ; If it\'s a message template
;;                      (push (append on-submit (list :field-values current-field-values)) commands)
;;                      (push (list on-submit :field-values current-field-values) commands))) ; Simple command
;;                (warn \"Form ~A submission failed due to validation errors: ~S\" component-id errors))))

;;         ;; :form-validate
;;         ((eql msg-form-validate)
;;          (when validation-fn
;;            (let ((errors (funcall validation-fn current-field-values)))
;;              (push (make-state-patch (append component-state-path \'(:validation-errors)) errors) patches))))

;;         ;; Propagate other messages to children if the form has direct children
;;         ;; This is less common if a layout component is used within the form DSL for children
;;         ((cons (eql :message-to) t)
;;          (let ((target-child-id (second msg))
;;                (actual-message (cddr msg)))
;;            (when (member target-child-id (getf form-props :children-ids))
;;              (let* ((child-component-id-path (list :components target-child-id))
;;                     (child-state (get-path state child-component-id-path))
;;                     (child-type (getf child-state :type)))
;;                (when child-type
;;                  (let ((child-instance (make-instance child-type)))
;;                    (let ((child-update-result (update child-instance state actual-message :id-path child-component-id-path)))
;;                      (setf patches (append (getf child-update-result :patches) patches))
;;                      (setf commands (append (getf child-update-result :commands) commands))))))))))

;;     (make-update-result :patches (nreverse patches) :commands (nreverse commands))))

;; ;;;---------------------------------------------------------------\\\n;;; View Method\\\n;;;---------------------------------------------------------------\\\n(defmethod view ((component form) state &key id-path)
;;   (let* ((component-id (id-from-path id-path))
;;          (component-state-path `(:components ,component-id))
;;          (form-props (getf state component-state-path)))

;;     (unless form-props
;;       (warn \"Form ~A state not found at ~S. Generating error view.\" component-id component-state-path)
;;       (return-from view `(:error \"Form component state not found for ID: ~a\" ,component-id)))

;;     ;; The form itself is often just a logical container. Its view might be minimal,
;;     ;; or it might render form-level errors or a submit button if not handled by its children.
;;     ;; Children are rendered by the layout system based on the DSL structure.
;;     ;; This view method is for the form *element* itself, not its children directly.
;;     ;; Children are part of the :children list of its parent layout in the view tree.

;;     `(:ui-element ; Or :form if a specific renderer tag is desired
;;       :id ,component-id
;;       :type :form ; Semantic type for renderer or styling
;;       :style '(:display :block) ; Forms are typically block-level
;;       ;; :on-submit `(,msg-form-submit) ; If the renderer can map native form submit to this message
;;       :properties `(:validation-errors ,(getf form-props :validation-errors))
;;       ;; Children are handled by the parent layout that contains this form and its actual input fields.
;;       ;; If the form had its own child components *not* part of a separate layout DSL inside it,
;;       ;; they would be mapped here.
;;       :children nil ; Typically, a <form> tag itself doesn\'t render children directly in this model
;;       ))
