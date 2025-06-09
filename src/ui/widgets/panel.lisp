(uiop:define-package :elmtui.ui.widgets.panel
  (:use :cl :alexandria)
  (:import-from :elmtui.ui.api #:component #:make-state-patch #:id-from-path #:get-path)
  (:import-from :elmtui.state #:make-update-result)
  (:import-from :elmtui.view.styled #:make-styled-node)
  (:export #:panel #:make-panel ; Class name and constructor
           ;; Messages (if any specific to panel itself)
           #:msg-set-panel-property
           ))

(in-package :elmtui.ui.widgets.panel)

;;;---------------------------------------------------------------\\\n;;; Panel Component\\\n;;;---------------------------------------------------------------\\\n(defclass panel (component) ()
  (:documentation "A panel component that visually groups its children, often with a border and title.\\n   Its properties (title, border style, etc.) and children are managed in the application state."))

(defun make-panel (&key id)
  "Creates a new panel component instance."
  (make-instance 'panel :id id))

;;;---------------------------------------------------------------\\\n;;; Messages (Keywords)\\\
;;;---------------------------------------------------------------\\\n;; Example: (:set-panel-property :title \"New Title\")
(defparameter msg-set-panel-property :set-panel-property)

;;;---------------------------------------------------------------\\\n;;; Init Method\\\n;;;---------------------------------------------------------------\\\n(defmethod init ((component panel) &key id-path
                                     initial-title
                                     (initial-border-style :single) ; :none, :single, :double, :rounded
                                     (initial-padding 0)
                                     initial-child-specs ; Children managed by layout system
                                     &allow-other-keys)
  (let ((component-id (id-from-path id-path))
        (child-patches nil)
        (child-commands nil)
        (child-ids nil)) ; IDs of direct children if this panel also lays them out

    ;; Initialize children if this component is responsible for them
    (dolist (child-spec initial-child-specs)
      (let* ((child-type (first child-spec))
             (child-id (second child-spec))
             (child-initargs (cddr child-spec))
             (child-instance (make-instance child-type))
             (child-id-path-for-child-init (list :components child-id)))
        (multiple-value-bind (initialized-child-instance patches-from-child commands-from-child)
            (apply #'init child-instance :id-path child-id-path-for-child-init child-initargs)
          (declare (ignore initialized-child-instance))
          (push child-id child-ids)
          (setf child-patches (append patches-from-child child-patches))
          (setf child-commands (append commands-from-child child-commands)))))

    (values component
            (append
             (list (make-state-patch `(:components ,component-id)
                                     `(:type ,(type-of component)
                                       :id ,component-id
                                       :title ,initial-title
                                       :border-style ,initial-border-style
                                       :padding ,initial-padding
                                       :children-ids ,(nreverse child-ids) ; Store child IDs
                                       ;; Pass through common style props if provided in other-args
                                       ,@(loop for prop in '(:width :height :min-width :min-height :max-width :max-height :margin :background-color :color :border :border-radius :overflow)
                                               for value = (getf other-args prop)
                                               when value
                                                 append `(,prop ,value)))))
             child-patches)
            child-commands)))

;;;---------------------------------------------------------------\\\n;;; Update Method\\\n;;;---------------------------------------------------------------\\\n(defmethod update ((component panel) state msg &key id-path)
  (let* ((component-id (id-from-path id-path))
         (component-state-path `(:components ,component-id))
         (panel-props (getf state component-state-path))
         (patches nil)
         (commands nil))\n
    (unless panel-props
      (warn \"Panel ~A state not found at ~S\" component-id component-state-path)\n      (return-from update (make-update-result :patches nil :commands nil)))

    (typecase msg
      ((cons (eql msg-set-panel-property) t)
       (let ((prop-name (second msg))
             (prop-value (third msg)))
         (if (member prop-name '(:title :border-style :padding :width :height :min-width :min-height :max-width :max-height :margin :background-color :color :border :border-radius :overflow))
             (push (make-state-patch (append component-state-path (list prop-name)) prop-value) patches)
             (warn \"Panel ~A: Unknown property for set-panel-property: ~S\" component-id prop-name))))

      ;; Handle dynamic child addition/removal if panel manages children directly
      ((cons (eql :add-child) t)
       (let ((child-spec (cdr message)))
         (push `(:command-add-child-to-layout ,component-id ,child-spec) commands)
         (log-info \"Panel ~A: Queued command to add child with spec: ~S\" component-id child-spec)))

      ((cons (eql :remove-child) t)
       (let ((child-id-to-remove (ensure-keyword (cdr message))))
         (when (member child-id-to-remove (getf panel-props :children-ids))
           (push (make-state-patch (append component-state-path '(:children-ids))
                                   (remove child-id-to-remove (getf panel-props :children-ids)))
                 patches)
           (push `(:command-destroy-component ,child-id-to-remove) commands)
           (log-info \"Panel ~A: Patched to remove child ID ~A, queued command for its destruction.\" component-id child-id-to-remove))
         (unless (member child-id-to-remove (getf panel-props :children-ids))
           (log-warn \"Panel ~A: Attempted to remove non-existent child ID ~A.\" component-id child-id-to-remove))))

      ;; Propagate messages to children
      ((cons (eql :message-to) t)
       (let ((target-child-id (second msg))
             (actual-message (cddr msg)))
         (if (member target-child-id (getf panel-props :children-ids))
             (let* ((child-component-id-path (list :components target-child-id))
                    (child-state (get-path state child-component-id-path))
                    (child-type (getf child-state :type)))
               (if child-type
                   (let ((child-instance (make-instance child-type)))
                     (let ((child-update-result (update child-instance state actual-message :id-path child-component-id-path)))
                       (setf patches (append (getf child-update-result :patches) patches))
                       (setf commands (append (getf child-update-result :commands) commands))))
                   (log-warn \"Panel ~A: Child ~A type not found in state for message propagation.\" component-id target-child-id)))
             (log-warn \"Panel ~A: Message ~S targeted non-child ~A.\" component-id message target-child-id)))))

    (make-update-result :patches (nreverse patches) :commands (nreverse commands))))

;;;---------------------------------------------------------------\\\n;;; View Method\\\n;;;---------------------------------------------------------------\\\n(defmethod view ((component panel) state &key id-path)
  (let* ((component-id (id-from-path id-path))
         (component-state-path `(:components ,component-id))
         (panel-props (getf state component-state-path)))

    (unless panel-props
      (warn \"Panel ~A state not found at ~S. Generating error view.\" component-id component-state-path)
      (return-from view `(:error \"Panel component state not found for ID: ~a\" ,component-id)))

    (let ((children-ids (getf panel-props :children-ids))
          (title (getf panel-props :title))
          (border-style (getf panel-props :border-style :single))
          (padding (getf panel-props :padding 0))
          (style-properties 
            `(:display :block ; Panels are typically block-level containers
              :padding ,padding
              ;; Border properties are often handled by specific renderer logic for panels
              ;; or could be translated to standard CSS border properties here.
              ;; For now, we pass border-style and title as direct props for the renderer.
              ))
          )

      ;; Add other common style properties from component state
      (dolist (prop '(:width :height :min-width :min-height :max-width :max-height :margin :background-color :color :border :border-radius :overflow))
        (let ((value (getf panel-props prop)))
          (when value
            (setf style-properties (list* prop value style-properties)))))
      
      ;; If :border was explicitly set in panel-props, use it. Otherwise, derive from :border-style.
      (unless (getf panel-props :border)
        (case border-style
          (:single (setf style-properties (list* :border \"1px solid\" style-properties)))
          (:double (setf style-properties (list* :border \"3px double\" style-properties)))
          (:rounded (setf style-properties (list* :border \"1px solid\" :border-radius \"5px\" style-properties)))))

      `(:ui-element
        :id ,component-id
        :type :panel ; Specific type for renderer
        :style ,style-properties
        :properties `(,@(when title `(:title ,title)) ; Pass title for renderer to handle
                      :border-style ,border-style) ; Pass original border-style for renderer
        :children ,(mapcar (lambda (child-id-key)
                             (let* ((child-component-id-path (list :components child-id-key))
                                    (child-state (get-path state child-component-id-path))
                                    (child-type (getf child-state :type)))
                               (if child-type
                                   (let ((child-instance (make-instance child-type)))
                                     (view child-instance state :id-path child-component-id-path))
                                   `(:error \"Child component type not found for ID: ~a in panel ~a\" ,child-id-key ,component-id))))
                           children-ids)))))
