;;;===============================================================
;;; File: src/ui/widgets/grid-container.lisp
;;; Standardized Grid Container Widget
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.grid-container
  (:use :cl :alexandria)
  (:import-from :elmtui.ui.api #:component #:make-state-patch #:id-from-path #:get-path)
  (:import-from :elmtui.state #:make-update-result)
  (:import-from :elmtui.view.styled #:make-styled-node)
  ;; (:import-from :elmtui.ui.widgets.utils ; Not using these legacy utils
  ;;               #:defwidget-view
  ;;               #:with-widget-model
  ;;               #:widget-focused-p)
  (:export #:grid-container #:make-grid-container ; Class name and constructor
           ;; Messages (if any specific to grid-container itself)
           #:msg-set-grid-property
           ))

(in-package :elmtui.ui.widgets.grid-container)

;;;---------------------------------------------------------------\\\n;;; Grid Container Component\\\n;;;---------------------------------------------------------------\\\n(defclass grid-container (component) ()
  (:documentation "A container that arranges its children in a grid. \\n   Its properties (template-rows, template-columns, gap, etc.) are stored in the application state.\\n   Children are typically defined via DSL and managed by a parent layout or this grid itself if it also acts as a layout."))

(defun make-grid-container (&key id)
  "Creates a new grid-container component instance."
  (make-instance 'grid-container :id id))

;;;---------------------------------------------------------------\\\n;;; Messages (Keywords)\\\
;;;---------------------------------------------------------------\\\n;; Example: (:set-grid-property :template-columns \"1fr 2fr\")
(defparameter msg-set-grid-property :set-grid-property)

;;;---------------------------------------------------------------\\\n;;; Init Method\\\n;;;---------------------------------------------------------------\\\n(defmethod init ((component grid-container) &key id-path
                                              (initial-template-rows '(\"auto\"))
                                              (initial-template-columns '(\"1fr\"))
                                              initial-template-areas
                                              (initial-auto-flow \"row\")
                                              (initial-gap 0)
                                              initial-row-gap
                                              initial-column-gap
                                              (initial-justify-content \"start\")
                                              (initial-align-content \"start\")
                                              (initial-justify-items \"stretch\")
                                              (initial-align-items \"stretch\")
                                              initial-child-specs ; Children managed by layout system
                                              &allow-other-keys)
  (let ((component-id (id-from-path id-path))
        (child-patches nil)
        (child-commands nil)
        (child-ids nil)) ; IDs of direct children if this grid also lays them out

    ;; Initialize children if this component is responsible for them
    ;; This is similar to the layout component\'s init for children
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
                                       :template-rows ,initial-template-rows
                                       :template-columns ,initial-template-columns
                                       :template-areas ,initial-template-areas
                                       :auto-flow ,initial-auto-flow
                                       :gap ,initial-gap
                                       :row-gap ,(or initial-row-gap initial-gap) ; Default row-gap to gap
                                       :column-gap ,(or initial-column-gap initial-gap) ; Default col-gap to gap
                                       :justify-content ,initial-justify-content
                                       :align-content ,initial-align-content
                                       :justify-items ,initial-justify-items
                                       :align-items ,initial-align-items
                                       :children-ids ,(nreverse child-ids) ; Store child IDs
                                       ;; Pass through common style props if provided in other-args
                                       ,@(loop for prop in '(:width :height :min-width :min-height :max-width :max-height :padding :margin :background-color :color :border :border-radius :overflow)
                                               for value = (getf other-args prop)
                                               when value
                                                 append `(,prop ,value)))))
             child-patches)
            child-commands)))

;;;---------------------------------------------------------------\\\n;;; Update Method\\\n;;;---------------------------------------------------------------\\\n(defmethod update ((component grid-container) state msg &key id-path)
  (let* ((component-id (id-from-path id-path))
         (component-state-path `(:components ,component-id))
         (grid-props (getf state component-state-path))
         (patches nil)
         (commands nil))\n
    (unless grid-props
      (warn \"Grid-container ~A state not found at ~S\" component-id component-state-path)\n      (return-from update (make-update-result :patches nil :commands nil)))

    (typecase msg
      ((cons (eql msg-set-grid-property) t)
       (let ((prop-name (second msg))
             (prop-value (third msg)))
         (if (member prop-name '(:template-rows :template-columns :template-areas :auto-flow
                                 :gap :row-gap :column-gap
                                 :justify-content :align-content :justify-items :align-items
                                 :width :height :min-width :min-height :max-width :max-height 
                                 :padding :margin :background-color :color :border :border-radius :overflow))
             (push (make-state-patch (append component-state-path (list prop-name)) prop-value) patches)
             (warn \"Grid-container ~A: Unknown property for set-grid-property: ~S\" component-id prop-name))))
      
      ;; Handle dynamic child addition/removal if grid-container manages children directly
      ;; This would be similar to the layout component\'s :add-child / :remove-child handling
      ((cons (eql :add-child) t) ; Message format: (:add-child child-type child-id . child-initargs)
       (let ((child-spec (cdr message)))
         (push `(:command-add-child-to-layout ,component-id ,child-spec) commands)
         (log-info \"Grid-container ~A: Queued command to add child with spec: ~S\" component-id child-spec)))

      ((cons (eql :remove-child) t)
       (let ((child-id-to-remove (ensure-keyword (cdr message))))
         (when (member child-id-to-remove (getf grid-props :children-ids))
           (push (make-state-patch (append component-state-path '(:children-ids))
                                   (remove child-id-to-remove (getf grid-props :children-ids)))
                 patches)
           (push `(:command-destroy-component ,child-id-to-remove) commands)
           (log-info \"Grid-container ~A: Patched to remove child ID ~A, queued command for its destruction.\" component-id child-id-to-remove))
         (unless (member child-id-to-remove (getf grid-props :children-ids))
           (log-warn \"Grid-container ~A: Attempted to remove non-existent child ID ~A.\" component-id child-id-to-remove))))

      ;; Propagate messages to children
      ((cons (eql :message-to) t)
       (let ((target-child-id (second msg))
             (actual-message (cddr msg)))
         (if (member target-child-id (getf grid-props :children-ids))
             (let* ((child-component-id-path (list :components target-child-id))
                    (child-state (get-path state child-component-id-path))
                    (child-type (getf child-state :type)))
               (if child-type
                   (let ((child-instance (make-instance child-type)))
                     (let ((child-update-result (update child-instance state actual-message :id-path child-component-id-path)))
                       (setf patches (append (getf child-update-result :patches) patches))
                       (setf commands (append (getf child-update-result :commands) commands))))
                   (log-warn \"Grid-container ~A: Child ~A type not found in state for message propagation.\" component-id target-child-id)))
             (log-warn \"Grid-container ~A: Message ~S targeted non-child ~A.\" component-id message target-child-id)))))

    (make-update-result :patches (nreverse patches) :commands (nreverse commands))))

;;;---------------------------------------------------------------\\\n;;; View Method\\\n;;;---------------------------------------------------------------\\\n(defmethod view ((component grid-container) state &key id-path)
  (let* ((component-id (id-from-path id-path))
         (component-state-path `(:components ,component-id))
         (grid-props (getf state component-state-path)))

    (unless grid-props
      (warn \"Grid-container ~A state not found at ~S. Generating error view.\" component-id component-state-path)
      (return-from view `(:error \"Grid-container component state not found for ID: ~a\" ,component-id)))

    (let ((children-ids (getf grid-props :children-ids))
          (style-properties 
            `(:display :grid
              :grid-template-rows    ,(getf grid-props :template-rows '(\"auto\"))
              :grid-template-columns ,(getf grid-props :template-columns '(\"1fr\"))
              :grid-auto-flow        ,(getf grid-props :auto-flow \"row\")
              :gap                   ,(getf grid-props :gap 0)
              :row-gap               ,(getf grid-props :row-gap (getf grid-props :gap 0)) ; Fallback to gap
              :column-gap            ,(getf grid-props :column-gap (getf grid-props :gap 0)) ; Fallback to gap
              :justify-content       ,(getf grid-props :justify-content \"start\")
              :align-content         ,(getf grid-props :align-content \"start\")
              :justify-items         ,(getf grid-props :justify-items \"stretch\")
              :align-items           ,(getf grid-props :align-items \"stretch\"))))

      (when (getf grid-props :template-areas)
        (setf style-properties (list* :grid-template-areas (getf grid-props :template-areas) style-properties)))
        
      ;; Add other common style properties from component state
      (dolist (prop '(:width :height :min-width :min-height :max-width :max-height :padding :margin :background-color :color :border :border-radius :overflow))
        (let ((value (getf grid-props prop)))
          (when value
            (setf style-properties (list* prop value style-properties)))))

      `(:ui-element
        :id ,component-id
        :style ,style-properties
        :children ,(mapcar (lambda (child-id-key)
                             (let* ((child-component-id-path (list :components child-id-key))
                                    (child-state (get-path state child-component-id-path))
                                    (child-type (getf child-state :type)))
                               (if child-type
                                   (let ((child-instance (make-instance child-type)))
                                     (view child-instance state :id-path child-component-id-path))
                                   `(:error \"Child component type not found for ID: ~a in grid-container ~a\" ,child-id-key ,component-id))))
                           children-ids)))))

;;;---------------------------------------------------------------\\\n;;; Standalone Grid Item Creator (Helper for DSL)\\\
;;; This doesn\'t define a component, but a way to style a child for grid layout.\\
;;; The actual child is some other component (e.g. button, label).\\\n;;; This function would be used in the :view part of a parent component, or by the DSL processor.\\
;;; For ElmTUI, grid item properties are typically part of the child\'s own view style or passed via layout hints.\
;;; This might be more relevant if we had a specific :grid-item view node type.\
;;; For now, these properties are usually set on the child\'s :style directly.\
;;; Example: `(:button :my-button ... :style (:grid-area \"header\" :align-self \"center\"))`\\\n;;;---------------------------------------------------------------\\\n;; (defun grid-item (&key id area row row-span col col-span align-self justify-self class children)
;;   \"Helper to construct a view node that represents a grid item with styling.\
;;    This is NOT a component, but a way to wrap children with grid positioning style.\"
;;   `(:ui-element
;;     ,@(when id `(:id ,id))
;;     :style (list* :grid-area area
;;                   ,@(when row `(:grid-row-start ,row))
;;                   ,@(when row-span `(:grid-row-end ,(if (numberp row) `(span ,row-span) row-span))) ; e.g. span 2
;;                   ,@(when col `(:grid-column-start ,col))
;;                   ,@(when col-span `(:grid-column-end ,(if (numberp col) `(span ,col-span) col-span)))
;;                   ,@(when align-self `(:align-self ,align-self))
;;                   ,@(when justify-self `(:justify-self ,justify-self))
;;                   (when class `(:class ,class)))
;;     :children ,children))
