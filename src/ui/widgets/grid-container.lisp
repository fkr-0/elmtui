;;;===============================================================
;;; File: src/ui/widgets/grid-container.lisp
;;; Standardized Grid Container Widget
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.grid-container
  (:use :cl :alexandria :elmtui.ui.defcomponent)
  (:import-from :elmtui.ui.api
                #:component #:id-from-path #:app-state #:get-component-property
                #:init #:update #:view #:destroy #:make-state-patch)
  (:import-from :elmtui.state.api #:make-update-result #:get-path #:state-ref
                #:update-result-patches #:update-result-commands)
  (:export #:grid-container))

(in-package :elmtui.ui.widgets.grid-container)

;; (defcomponent grid-container ()
;;   () ;; No direct CLOS slots
;;   (:state
;;    ;; Grid-specific properties
;;    (template-rows '("auto") :type list :documentation "Defines the track sizing functions and line names of the grid rows."
;;                             :initarg :template-rows :accessor grid-template-rows)
;;    (template-columns '("1fr") :type list :documentation "Defines the track sizing functions and line names of the grid columns."
;;                               :initarg :template-columns :accessor grid-template-columns)
;;    (template-areas nil :type (or null list) :documentation "Specifies named grid areas."
;;                        :initarg :template-areas :accessor grid-template-areas)
;;    (auto-flow "row" :type string :documentation "Controls how auto-placed items get flowed into the grid."
;;                     :initarg :auto-flow :accessor grid-auto-flow)
;;    (gap 0 :type (or integer string) :documentation "A shorthand property for row-gap and column-gap. Sets both if they are not explicitly set."
;;           :initarg :gap :accessor grid-gap)
;;    (row-gap 0 :type (or integer string) :documentation "Specifies the size of the gap between rows. Defaults to 'gap' if not set."
;;               :initarg :row-gap :accessor grid-row-gap)
;;    (column-gap 0 :type (or integer string) :documentation "Specifies the size of the gap between columns. Defaults to 'gap' if not set."
;;                  :initarg :column-gap :accessor grid-column-gap)
;;    (justify-content "start" :type string :documentation "Aligns grid items along the inline (row) axis."
;;                             :initarg :justify-content :accessor grid-justify-content)
;;    (align-content "start" :type string :documentation "Aligns the grid within the grid container along the block (column) axis."
;;                           :initarg :align-content :accessor grid-align-content)
;;    (justify-items "stretch" :type string :documentation "Aligns grid items along their inline (row) axis."
;;                             :initarg :justify-items :accessor grid-justify-items)
;;    (align-items "stretch" :type string :documentation "Aligns grid items along their block (column) axis."
;;                           :initarg :align-items :accessor grid-align-items)

;;    ;; Common container properties
;;    (children-ids nil :type list :documentation "List of keyword IDs for child components.")
;;    (width nil :type (or null integer string) :documentation "Width of the grid container."
;;               :initarg :width :accessor grid-width)
;;    (height nil :type (or null integer string) :documentation "Height of the grid container."
;;                :initarg :height :accessor grid-height)
;;    (margin nil :type (or null integer string list) :documentation "Margin around the grid container."
;;                :initarg :margin :accessor grid-margin)
;;    (padding nil :type (or null integer string list) :documentation "Padding within the grid container."
;;                 :initarg :padding :accessor grid-padding)
;;    (background-color nil :type (or null string keyword) :documentation "Background color."
;;                          :initarg :background-color :accessor grid-background-color)
;;    (color nil :type (or null string keyword) :documentation "Foreground color."
;;               :initarg :color :accessor grid-color)
;;    (border nil :type (or null string) :documentation "Explicit border string."
;;                :initarg :border :accessor grid-border)
;;    (border-radius nil :type (or null string integer) :documentation "Border radius."
;;                       :initarg :border-radius :accessor grid-border-radius)
;;    (overflow nil :type (or null keyword) :documentation "Overflow behavior."
;;                  :initarg :overflow :accessor grid-overflow)
;;    (other-style-props nil :type list :documentation "Plist of other style properties passed during init."))
;;   (:documentation "A container that arranges its children in a grid using CSS Grid-like properties.")
;;   (:on-unhandled-message :log)

;;   (:init (props self-id-path)
;;          (let ((collected-child-effects nil)
;;                (collected-child-id-segments nil)
;;                (other-props-for-state nil)
;;                (grid-handled-initargs '(:template-rows :template-columns :template-areas :auto-flow
;;                                         :gap :row-gap :column-gap
;;                                         :justify-content :align-content :justify-items :align-items
;;                                         :width :height :margin :padding :background-color :color
;;                                         :border :border-radius :overflow)))

;;            ;; Initialize children
;;            (loop for child-spec in (getf props :children)
;;                  for child-type = (first child-spec)
;;                  for child-id-segment = (second child-spec)
;;                  for child-initargs = (cddr child-spec)
;;                  for child-full-id-path = (append self-id-path (list child-id-segment))
;;                  do
;;                     (push child-id-segment collected-child-id-segments)
;;                     (let ((child-instance (make-instance child-type)))
;;                       (multiple-value-bind (_child-instance child-patches child-commands)
;;                           (apply #'elmtui.ui.api:init child-instance :id-path child-full-id-path child-initargs)
;;                         (declare (ignore _child-instance))
;;                         (setf collected-child-effects (append child-patches child-commands collected-child-effects)))))

;;            ;; Collect other props
;;            (loop for (key val) on props by #'cddr
;;                  unless (or (eq key :children) (member key grid-handled-initargs))
;;                    do (setf other-props-for-state (list* key val other-props-for-state)))

;;            (values `(:children-ids ,(nreverse collected-child-id-segments)
;;                      :other-style-props ,(nreverse other-props-for-state)
;;                      ;; Ensure row-gap and column-gap default to gap value if not explicitly provided in props.
;;                      ;; defcomponent will set :gap from props if present.
;;                      :row-gap ,(or (getf props :row-gap) (getf props :gap 0))
;;                      :column-gap ,(or (getf props :column-gap) (getf props :gap 0)))
;;                    (nreverse collected-child-effects))))
;;   (:update (message local-state app-state self-id-path)
;;            (let ((component-id (id-from-path self-id-path)))
;;              (list :set-property (prop-keyword new-value)
;;                    (let ((known-grid-props '(:template-rows :template-columns :template-areas :auto-flow
;;                                              :gap :row-gap :column-gap
;;                                              :justify-content :align-content :justify-items :align-items))
;;                          (known-style-props '(:width :height :margin :padding :background-color :color
;;                                               :border :border-radius :overflow))
;;                          (state-changes-plist nil))
;;                      (cond
;;                        ((eq prop-keyword :gap)
;;                         (setf (getf state-changes-plist :gap) new-value)
;;                         ;; If row-gap was tracking the old gap value (or was not set and thus implicitly tracking), update it.
;;                         (when (or (not (getf local-state :row-gap)) ; if row-gap was nil, it was using gap
;;                                   (equal (getf local-state :row-gap) (getf local-state :gap)))
;;                           (setf (getf state-changes-plist :row-gap) new-value))
;;                         ;; If column-gap was tracking the old gap value (or was not set), update it.
;;                         (when (or (not (getf local-state :column-gap))
;;                                   (equal (getf local-state :column-gap) (getf local-state :gap)))
;;                           (setf (getf state-changes-plist :column-gap) new-value))
;;                         (values state-changes-plist nil))
;;                        ((member prop-keyword known-grid-props)
;;                         (values (list prop-keyword new-value) nil))
;;                        ((member prop-keyword known-style-props)
;;                         (values (list prop-keyword new-value) nil))
;;                        ((getf (getf local-state :other-style-props) prop-keyword) ; Check if it's an existing "other" style
;;                         (values `(:other-style-props ,(let ((osp (copy-list (getf local-state :other-style-props))))
;;                                                         (setf (getf osp prop-keyword) new-value)
;;                                                         osp))
;;                                 nil))
;;                        (t
;;                         (warn "Grid-container ~A: Attempt to set unknown property ~S via :set-property." component-id prop-keyword)
;;                         (values nil nil)))))

;;              (:add-child (child-id-segment child-type &rest child-initargs)
;;                          (let* ((child-full-id-path (append self-id-path (list child-id-segment)))
;;                                 (child-instance (make-instance child-type))
;;                                 (new-children-ids (cons child-id-segment (getf local-state :children-ids))))
;;                            (multiple-value-bind (_instance child-patches child-commands)
;;                                (apply #'elmtui.ui.api:init child-instance :id-path child-full-id-path child-initargs)
;;                              (declare (ignore _instance))
;;                              (values `(:children-ids ,(remove-duplicates new-children-ids :test #'equal))
;;                                      (append child-patches child-commands)))))

;;              (:remove-child (child-id-segment)
;;                             (let* ((child-full-id-path (append self-id-path (list child-id-segment)))
;;                                    (new-children-ids (remove child-id-segment (getf local-state :children-ids) :test #'equal))
;;                                    (destroy-command `(:destroy-component-recursive ,child-full-id-path)))
;;                               (values `(:children-ids ,new-children-ids) (list destroy-command))))

;;              (:message-to (target-child-id-segment &rest child-message)
;;                           (let* ((child-full-id-path (append self-id-path (list target-child-id-segment)))
;;                                  (child-type (elmtui.state.api:get-path app-state child-full-id-path :type)))
;;                             (if (and child-type (find target-child-id-segment (getf local-state :children-ids) :test #'equal))
;;                                 (let* ((child-instance (make-instance child-type))
;;                                        (child-update-result (elmtui.ui.api:update child-instance app-state child-message :id-path child-full-id-path)))
;;                                   (values nil
;;                                           (append (update-result-patches child-update-result)
;;                                                   (update-result-commands child-update-result))))
;;                                 (progn
;;                                   (warn "Grid-container ~A: Message ~S targeted non-child or unknown-type child ~A."
;;                                         component-id child-message target-child-id-segment)
;;                                   (values nil nil)))))))
;;   (:view (local-state app-state self-id-path)
;;          (let* ((component-id (id-from-path self-id-path))
;;                 (children-ids (getf local-state :children-ids))
;;                 (style-properties `(:display :grid)))

;;            ;; Populate style-properties from local-state's direct state fields
;;            (loop for style-key in '(:template-rows :template-columns :template-areas :auto-flow
;;                                     :gap :row-gap :column-gap
;;                                     :justify-content :align-content :justify-items :align-items
;;                                     :width :height :margin :padding :background-color :color
;;                                     :border :border-radius :overflow)
;;                  for value = (getf local-state style-key)
;;                  when value ;; Only add if value is not nil (or use default if appropriate for CSS)
;;                    do
;;                       (case style-key
;;                         (:template-rows (setf (getf style-properties :grid-template-rows) value))
;;                         (:template-columns (setf (getf style-properties :grid-template-columns) value))
;;                         (:template-areas (when value (setf (getf style-properties :grid-template-areas) value)))
;;                         (:auto-flow (setf (getf style-properties :grid-auto-flow) value))
;;                         ;; gap, row-gap, column-gap are taken directly as they are correctly maintained in local-state
;;                         (otherwise (setf (getf style-properties style-key) value)))))

;;          ;; Merge properties from :other-style-props
;;          (loop for (key val) on (getf local-state :other-style-props) by #'cddr
;;                do (setf (getf style-properties key) val))

;;          `(:ui-element
;;            :id ,component-id
;;            :type :grid-container
;;            :style ,style-properties
;;            :children ,(mapcar (lambda (child-id-segment)
;;                                 (let* ((child-full-id-path (append self-id-path (list child-id-segment)))
;;                                        (child-type (elmtui.state.api:get-path app-state child-full-id-path :type)))
;;                                   (if child-type
;;                                       (let ((child-instance (make-instance child-type)))
;;                                         (elmtui.ui.api:view child-instance app-state :id-path child-full-id-path))
;;                                       `(:error "Child component type not found for ID: ~a in grid ~a"
;;                                         ,child-id-segment component-id))))
;;                               children-ids))))




;; (defmethod elmtui.ui.api:destroy ((self grid-container) &key id-path)
;;   (let ((grid-local-state ;; (elmtui.state.api:get-path app-state id-path)
;;           nil
;;           )
;;         (all-patches nil)
;;         (all-commands nil))

;;     (loop for child-id-segment in (getf grid-local-state :children-ids)
;;           for child-full-id-path = (append id-path (list child-id-segment))
;;           for child-type = (elmtui.state.api:get-path app-state child-full-id-path :type)
;;           when child-type
;;             do (let ((child-instance (make-instance child-type)))
;;                  (multiple-value-bind (child-patches child-commands-from-destroy)
;;                      (elmtui.ui.api:destroy child-instance :id-path child-full-id-path)
;;                    (setf all-patches (append child-patches all-patches))
;;                    (setf all-commands (append child-commands-from-destroy all-commands))))
;;           else
;;             do (warn "Grid-container destroy: Child ~A type not found for path ~A during grid ~A destruction."
;;                      child-id-segment child-full-id-path (id-from-path id-path)))

;;     (push (elmtui.ui.api:make-state-patch id-path :elmtui-delete-path) all-patches)
;;     (values (nreverse all-patches) (nreverse all-commands))))



;;;---------------------------------------------------------------\\n;;; Standalone Grid Item Creator (Helper for DSL)\

;;; This doesn't define a component, but a way to style a child for grid layout.\
;;; The actual child is some other component (e.g. button, label).\\n;;; This function would be used in the :view part of a parent component, or by the DSL processor.\
;;; For ElmTUI, grid item properties are typically part of the child's own view style or passed via layout hints.\
;;; This might be more relevant if we had a specific :grid-item view node type.\
;;; For now, these properties are usually set on the child's :style directly.\
;;; Example: (:button :my-button ... :style (:grid-area \"header\" :align-self \"center\"))\\n;;;---------------------------------------------------------------\\n;; (defun grid-item (&key id area row row-span col col-span align-self justify-self class children)
;;   "Helper to construct a view node that represents a grid item with styling.

;;    This is NOT a component, but a way to wrap children with grid positioning style."
;;   (:ui-element ;; ,@(when id (:id ,id))
;;     :style (list* :grid-area area
;;                   ,@(when row (:grid-row-start ,row)) ;; ,@(when row-span (:grid-row-end ,(if (numberp row) (span ,row-span) row-span))) ; e.g. span 2 ;; ,@(when col (:grid-column-start ,col))
;;                   ,@(when col-span (:grid-column-end ,(if (numberp col) (span ,col-span) col-span)))
;;                   ,@(when align-self (:align-self ,align-self)) ;; ,@(when justify-self (:justify-self ,justify-self))
;;                   (when class `(:class ,class)))
;;     :children ,children))
