(uiop:define-package :elmtui.ui.widgets.layout
  (:use :cl :alexandria)
  (:import-from #:log4cl :log-info :log-debug :log-warn)
  (:import-from #:elmtui.utils :ensure-keyword)
  (:import-from :elmtui.ui.api :get-path :id-from-path
   :make-state-patch :get-component-instance)
  (:import-from :elmtui.ui.defcomponent :defcomponent)
  (:import-from :elmtui.state :make-update-result) ; Ensure this is imported

  (:export
   #:layout
   #:make-layout
   ))
(in-package :elmtui.ui.widgets.layout)

;;;---------------------------------------------------------------
;;; Layout Component
;;;---------------------------------------------------------------
(defclass layout (component)
  ()
  (:documentation "A component that arranges child components.
Its behavioral state (layout-type, spacing) is in app-state.
It stores IDs of its child components in app-state under :children."))

(defun make-layout (&key id)
  "Creates a new layout component instance. ID is for potential direct use, but in DSL, it's derived."
  (make-instance 'layout :id id))

;;;---------------------------------------------------------------
;;; Component API Implementation (New TEA-aligned)
;;;---------------------------------------------------------------
(defmethod init ((component layout) &rest other-args &key id-path initial-layout-type initial-spacing initial-child-specs &allow-other-keys )
  (let ((component-id (id-from-path id-path))
        (child-patches nil)
        (child-commands nil)
        ;; (child-refs nil) ; child-refs was not used, can be removed
        (child-ids nil)
        (actual-layout-type (case initial-layout-type
                              ((:column :row) :flex)
                              (t (or initial-layout-type :flex))))
        (actual-flex-direction (case initial-layout-type
                                 (:column :column)
                                 (:row :row)
                                 (t (getf other-args :flex-direction :column)))))
    (dolist (child-spec initial-child-specs)
      (let* ((child-type (first child-spec))
             (raw-child-id (second child-spec))
             (child-id (if (keywordp raw-child-id) raw-child-id (intern (string raw-child-id) :keyword)))
             (child-initargs (cddr child-spec))
             (child-instance (make-instance child-type))
             (child-id-path-for-child-init (list :components child-id)))
        (multiple-value-bind (initialized-child-instance patches-from-child commands-from-child)
            (apply #'init child-instance :id-path child-id-path-for-child-init child-initargs)
          (declare (ignore initialized-child-instance))
          ;; (push child-instance child-refs) ; Not needed
          (push child-id child-ids)
          (setf child-patches (append patches-from-child child-patches))
          (setf child-commands (append commands-from-child child-commands)))))
    (values component
            (append
             (list (make-state-patch (list :components component-id)
                                     (let ((base-state-list
                                             `(:type ,(type-of component)
                                               :id ,component-id
                                               :layout-type ,actual-layout-type
                                               ,@(when (eq actual-layout-type :flex)
                                                   `(:flex-direction ,actual-flex-direction))
                                               :spacing ,(or initial-spacing 0)
                                               :children-ids ,(nreverse child-ids)
                                               ,@(loop for prop in '(:width :height :min-width :min-height :max-width :max-height :padding :margin :align-items :justify-content :background-color :color :border :border-radius :overflow)
                                                       for value = (getf other-args prop)
                                                       when value
                                                         append `(,prop ,value)))))\n                                       (if (eq actual-layout-type :grid)
                                           (append base-state-list
                                                   `(:grid-template-columns ,(getf other-args :grid-template-columns "1fr")
                                                     :grid-template-rows    ,(getf other-args :grid-template-rows "auto")))
                                           base-state-list))))
             child-patches)
            child-commands)))

(defmethod update ((component layout) state message &key id-path )
  "Handles messages for the layout or propagates to children.
`state` is the full application state.
Returns an update-result list: (:patches patches :commands commands)."
  (let* ((component-id (id-from-path id-path))
         (component-state-path (list :components component-id))
         (layout-props (get-path state component-state-path))
         (patches nil)
         (commands nil)) ; Initialize commands

    (unless layout-props
      (log-warn "Layout component ~A state not found at ~S. No update performed." component-id component-state-path)
      (return-from update (make-update-result :patches nil :commands nil)))

    (typecase message
      ((cons (eql :add-child))
       ;; Message format: (:add-child child-type child-id . child-initargs)
       ;; e.g., (:add-child :button :new-button :label "Click Me")
       ;; The child-id within child-spec should be unique.
       (let ((child-spec (cdr message))) ; child-spec is (child-type child-id . child-initargs)
         ;; Command for the application loop to handle child instantiation, init,
         ;; and updating this layout's :children-ids state.
         (push `(:command-add-child-to-layout ,component-id ,child-spec) commands)
         (log-info "Layout ~A: Queued command to add child with spec: ~S" component-id child-spec)))

      ((cons (eql :remove-child))
       (let ((child-id-to-remove (ensure-keyword (cdr message))))
         (when (member child-id-to-remove (getf layout-props :children-ids))
           ;; Patch to update the layout's own children list
           (push (make-state-patch (append component-state-path '(:children-ids))
                                   (remove child-id-to-remove (getf layout-props :children-ids)))
                 patches)
           ;; Command to destroy the child component's state and run its cleanup (if any)
           (push `(:command-destroy-component ,child-id-to-remove) commands)
           (log-info "Layout ~A: Patched to remove child ID ~A, queued command for its destruction." component-id child-id-to-remove))
         (unless (member child-id-to-remove (getf layout-props :children-ids))
           (log-warn "Layout ~A: Attempted to remove non-existent child ID ~A." component-id child-id-to-remove))))

      ((cons (eql :set-layout-prop))
       (let ((prop-name (second message))
             (prop-value (third message)))
         (push (make-state-patch (append component-state-path (list prop-name)) prop-value) patches)
         (log-info "Layout ~A: Patched property ~A to ~S." component-id prop-name prop-value)))

      (t
       ;; Propagate to children if message is targeted
       ;; Assuming messages are targeted like (:message-to :child-id actual-message)
       (when (and (consp message) (keywordp (car message)) (eq (car message) :message-to))
         (let ((target-child-id (second message))
               (actual-message (cddr message)))
           (if (member target-child-id (getf layout-props :children-ids))
               (let* ((child-component-id-path (list :components target-child-id))
                      (child-state (get-path state child-component-id-path))
                      (child-type (getf child-state :type)))
                 (if child-type
                     (let ((child-instance (make-instance child-type))) ; Stateless instance for dispatch
                       (let ((child-update-result (update child-instance state actual-message :id-path child-component-id-path)))
                         (setf patches (append (getf child-update-result :patches) patches))
                         (setf commands (append (getf child-update-result :commands) commands))))
                     (log-warn "Layout ~A: Child ~A type not found in state for message propagation." component-id target-child-id)))
               (log-warn "Layout ~A: Message ~S targeted non-child ~A." component-id message target-child-id))))))
    (make-update-result :patches patches :commands commands)))

(defmethod view ((component layout) state &key id-path )
  "Generates a view model for the layout component based on the current app-state."
  (let* ((component-id (id-from-path id-path))
         (component-state-path (list :components component-id))
         (layout-props (get-path state component-state-path)))

    (unless layout-props
      (log-warn "Layout component ~A state not found at ~S. Generating error view." component-id component-state-path)
      (return-from view `(:error "Layout component state not found for ID: ~a" ,component-id)))

    (let ((layout-type (getf layout-props :layout-type :flex))
          (flex-direction (getf layout-props :flex-direction :column)) ; Used if layout-type is :flex
          (spacing (getf layout-props :spacing 0))
          (children-ids (getf layout-props :children-ids))
          (style-properties (list)))

      (setf style-properties
            (case layout-type
              (:flex
               `(:display :flex :flex-direction ,flex-direction :gap ,spacing))
              (:grid
               `(:display :grid
                 :grid-template-columns ,(getf layout-props :grid-template-columns "1fr")
                 :grid-template-rows    ,(getf layout-props :grid-template-rows "auto")
                 :gap ,spacing))
              (:block  `(:display :block))
              (:none   `(:display :none))
              (t       `(:display :flex :flex-direction :column :gap ,spacing))))

      (dolist (prop '(:width :height :min-width :min-height :max-width :max-height :padding :margin :align-items :justify-content :background-color :color :border :border-radius :overflow))
        (let ((value (getf layout-props prop)))
          (when value
            (setf style-properties (list* prop value style-properties)))))

      `(:ui-element
        :id ,component-id
        :style ,style-properties
        :children ,(mapcar (lambda (child-id-key)
                             (let* ((child-component-id-path (list :components child-id-key))
                                    (child-state (get-path state child-component-id-path))
                                    (child-type (getf child-state :type)))\n                               (if child-type
                                   (let ((child-instance (make-instance child-type)))
                                     (view child-instance state :id-path child-component-id-path))
                                   `(:error "Child component type not found for ID: ~a in layout ~a" ,child-id-key ,component-id))))
                           children-ids)))))
