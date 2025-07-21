(uiop:define-package :elmtui.ui.widgets.layout
  (:use :cl :alexandria :elmtui.ui.defcomponent)
  (:import-from #:log4cl :log-info :log-debug :log-warn)
  (:import-from #:elmtui.utils :ensure-keyword)
  (:import-from :elmtui.ui.api
                #:component-id
                #:id-from-path
                #:init
                #:update
                #:view
                #:destroy
                #:make-state-patch
                #:get-path)
  (:import-from :elmtui.state.api
                #:ur-patches
                #:ur-commands
                #:make-update-result
                #:update-result-patches
                #:update-result-commands)
  (:export #:layout))

(in-package :elmtui.ui.widgets.layout)

(defcomponent layout ()
  (:state
   (display :flex
            :type keyword
            :documentation
            "Display mode: :flex, :grid, :block, :none. Default :flex." :initarg :display)
   (flex-direction :column
                   :type keyword
                   :documentation
                   "Flex direction: :row, :column, etc." :initarg :flex-direction)
   (grid-template-columns '("1fr")
                          :type list
                          :documentation
                          "Grid columns."
                          :initarg :grid-template-columns)
   (grid-template-rows '("auto")
                       :type list :documentation "Grid rows."
                       :initarg :grid-template-rows)
   (grid-template-areas nil :type (or null list)
                            :documentation "Grid areas." :initarg :grid-template-areas)
   (grid-auto-flow "row" :type string :documentation "Grid auto-flow."
                         :initarg :grid-auto-flow)
   (gap 0 :type (or integer string)
          :documentation "Gap between items." :initarg :gap)
   (row-gap nil :type (or null integer string)
                :documentation "Row gap." :initarg :row-gap)
   (column-gap nil :type (or null integer string)
                   :documentation "Column gap." :initarg :column-gap)
   (justify-content "start" :type string
                            :documentation "Justify content." :initarg :justify-content)
   (align-items "stretch" :type string :documentation "Align items." :initarg :align-items)
   (align-content "start" :type string :documentation "Align content." :initarg :align-content)
   (justify-items "stretch"
                  :type string :documentation "Justify items." :initarg :justify-items)
   (children-ids '() :type list :documentation "Child component IDs.")
   (width nil :type (or null integer string) :documentation "Width." :initarg :width)
   (height nil :type (or null integer string) :documentation "Height." :initarg :height)
   (min-width nil :type (or null integer string) :documentation "Min width." :initarg :min-width)
   (min-height nil :type (or null integer string) :documentation "Min height." :initarg :min-height)
   (max-width nil :type (or null integer string) :documentation "Max width." :initarg :max-width)
   (max-height nil :type (or null integer string) :documentation "Max height." :initarg :max-height)
   (padding nil :type (or null integer string list) :documentation "Padding." :initarg :padding)
   (margin nil :type (or null integer string list) :documentation "Margin." :initarg :margin)
   (background-color nil
                     :type (or null string keyword)
                     :documentation "Background color." :initarg :background-color)
   (color nil :type (or null string keyword)
              :documentation "Foreground color."
              :initarg :color)
   (border nil :type (or null string)
               :documentation "Border style."
               :initarg :border)
   (border-radius nil :type (or null string integer)
                      :documentation "Border radius."
                      :initarg :border-radius)
   (overflow nil :type (or null keyword)
                 :documentation "Overflow."
                 :initarg :overflow)
   (other-style-props (list)
                      :type list
                      :documentation "Other style props."))

  (:documentation "Unified layout component for Elmtui. Arranges children using flexbox or grid, depending
on :display. Supports all major layout and style props.")

  (:on-unhandled-message :log)

  (:init (props self-id-path)
         (let ((collected-child-effects nil)
               (collected-child-id-segments nil)
               (layout-state-settings nil)
               (known-props '(:children :display :layout-type
                              :flex-direction :grid-template-columns :grid-template-rows
                              :grid-template-areas :grid-auto-flow
                              :gap :spacing
                              :row-gap :column-gap
                              :justify-content :align-items :align-content :justify-items
                              :width :height :min-width :min-height :max-width :max-height
                              :padding :margin :background-color :color :border :border-radius :overflow)))
           ;; Children
           (loop for child-spec in (getf props :children)
                 for child-type = (first child-spec)
                 for raw-child-id = (second child-spec)
                 for child-id-segment = (ensure-keyword raw-child-id)
                 for child-initargs = (cddr child-spec)
                 for child-full-id-path = (append self-id-path (list child-id-segment))
                 do
                    (push child-id-segment collected-child-id-segments)
                    (let ((child-instance (make-instance child-type)))
                      (multiple-value-bind (_child-instance child-patches child-commands)
                          (apply #'elmtui.ui.api:init child-instance :id-path child-full-id-path child-initargs)
                        (declare (ignore _child-instance))
                        (setf collected-child-effects (append child-patches child-commands collected-child-effects)))))
           (setf (getf layout-state-settings :children-ids) (nreverse collected-child-id-segments))
           ;; Display mode/backward compat
           (let* ((explicit-display (getf props :display))
                  (old-layout-type (getf props :layout-type))
                  (final-display (or explicit-display
                                     (case old-layout-type
                                       ((:column :row) :flex)
                                       (:grid :grid)
                                       (otherwise (or old-layout-type :flex))))))
             (setf (getf layout-state-settings :display) final-display)
             (when (eq final-display :flex)
               (setf (getf layout-state-settings :flex-direction)
                     (or (getf props :flex-direction)
                         (case old-layout-type
                           (:column :column)
                           (:row :row)
                           (otherwise :column))))))
           ;; Gap/spacing
           (let* ((explicit-gap (getf props :gap))
                  (old-spacing (getf props :spacing))
                  (base-gap-value (or explicit-gap old-spacing 0)))
             (setf (getf layout-state-settings :gap) base-gap-value)
             (setf (getf layout-state-settings :row-gap) (or (getf props :row-gap) base-gap-value))
             (setf (getf layout-state-settings :column-gap) (or (getf props :column-gap) base-gap-value)))
           ;; Other direct props
           (dolist (prop-key '(:grid-template-columns :grid-template-rows :grid-template-areas :grid-auto-flow
                               :justify-content :align-items :align-content :justify-items
                               :width :height :min-width :min-height :max-width :max-height
                               :padding :margin :background-color :color :border :border-radius :overflow))
             (let ((val (getf props prop-key)))
               (when val (setf (getf layout-state-settings prop-key) val))))
           ;; Other style props
           (let ((other-props nil))
             (loop for (key val) on props by #'cddr
                   unless (member key known-props)
                     do (setf other-props (list* key val other-props)))
             (setf (getf layout-state-settings :other-style-props) (nreverse other-props)))
           (values layout-state-settings (nreverse collected-child-effects))))
  (:update
   (message local-state app-state self-id-path)
   (:add-child (child-id-segment child-type child-initargs)
               (let* ((child-id-key (ensure-keyword child-id-segment))
                      (child-full-id-path (append self-id-path (list child-id-key)))
                      (child-instance (make-instance child-type))
                      (new-children-ids (cons child-id-key (getf local-state :children-ids))))
                 (multiple-value-bind (_instance child-patches child-commands)
                     (apply #'elmtui.ui.api:init
                            child-instance
                            :id-path child-full-id-path
                            child-initargs)
                   (declare (ignore _instance))
                   `(values
                     (:children-ids ,(remove-duplicates new-children-ids :test #'equal))
                     ,(append child-patches child-commands)))))
   (:remove-child (child-id-segment)
                  (let* ((child-id-key (ensure-keyword child-id-segment))
                         (child-full-id-path (append self-id-path (list child-id-key)))
                         (new-children-ids (remove child-id-key (getf local-state :children-ids) :test #'equal)))
                    (values `(:children-ids ,new-children-ids)
                            (list :destroy-component-recursive child-full-id-path))))
   (:set-property (prop-keyword new-value)
                  (let ((state-changes-plist nil)
                        (known-direct-props '(:display :flex-direction
                                              :grid-template-columns :grid-template-rows
                                              :grid-template-areas :grid-auto-flow
                                              :row-gap :column-gap
                                              :justify-content :align-items
                                              :align-content :justify-items
                                              :width :height
                                              :min-width :min-height
                                              :max-width :max-height
                                              :padding :margin
                                              :background-color :color
                                              :border :border-radius :overflow
                                              :children-ids)))
                    (cond
                      ((eq prop-keyword :gap)
                       (progn
                         (setf (getf state-changes-plist :gap) new-value)
                         (when (or (null (getf local-state :row-gap))
                                   (equal (getf local-state :row-gap) (getf local-state :gap)))
                           (setf (getf state-changes-plist :row-gap) new-value))
                         (when (or (null (getf local-state :column-gap))
                                   (equal (getf local-state :column-gap) (getf local-state :gap)))
                           (setf (getf state-changes-plist :column-gap) new-value))))
                      ((member prop-keyword known-direct-props)
                       (progn
                         (setf (getf state-changes-plist prop-keyword) new-value)
                         ;; Update other-style-props to include this direct prop
                         (let ((osp (copy-list (getf local-state :other-style-props))))
                           (setf (getf osp prop-keyword) new-value)
                           (setf (getf state-changes-plist :other-style-props) osp))))
                      (t
                       (setf (getf state-changes-plist :other-style-props)
                             (append (list prop-keyword new-value) (getf local-state :other-style-props)))))
                    (values state-changes-plist nil)))
   (:message-to (target-child-id-segment child-message)
                (let* ((target-child-id (ensure-keyword target-child-id-segment))
                       (child-full-id-path (append self-id-path (list target-child-id)))
                       (child-type (get-path child-full-id-path app-state :type)))
                  (if (and child-type (find target-child-id (getf local-state :children-ids) :test #'equal))
                      (let* ((child-instance (make-instance child-type))
                             (child-update-result (apply #'elmtui.ui.api:update child-instance app-state child-message :id-path child-full-id-path)))
                        (values nil
                                (append (ur-patches child-update-result)
                                        (ur-commands child-update-result))))
                      (values nil nil)))))

  (:view (local-state app-state self-id-path)
         (let* ((component-id (id-from-path self-id-path))
                (children-ids (getf local-state :children-ids))
                (display-mode (getf local-state :display :flex))
                (style-properties nil))
           (setf (getf style-properties :display) display-mode)
           (case display-mode
             (:flex
              (setf (getf style-properties :flex-direction) (getf local-state :flex-direction :column))
              (setf (getf style-properties :gap) (or (getf local-state :column-gap) (getf local-state :row-gap) (getf local-state :gap 0)))
              (setf (getf style-properties :justify-content) (getf local-state :justify-content "start"))
              (setf (getf style-properties :align-items) (getf local-state :align-items "stretch"))
              (setf (getf style-properties :align-content) (getf local-state :align-content "start")))
             (:grid
              (setf (getf style-properties :grid-template-columns) (getf local-state :grid-template-columns '("1fr")))
              (setf (getf style-properties :grid-template-rows) (getf local-state :grid-template-rows '("auto")))
              (when (getf local-state :grid-template-areas)
                (setf (getf style-properties :grid-template-areas) (getf local-state :grid-template-areas)))
              (setf (getf style-properties :grid-auto-flow) (getf local-state :grid-auto-flow "row"))
              (setf (getf style-properties :gap) (getf local-state :gap 0))
              (setf (getf style-properties :row-gap) (or (getf local-state :row-gap) (getf local-state :gap 0)))
              (setf (getf style-properties :column-gap) (or (getf local-state :column-gap) (getf local-state :gap 0)))
              (setf (getf style-properties :justify-content) (getf local-state :justify-content "start"))
              (setf (getf style-properties :align-content) (getf local-state :align-content "start"))
              (setf (getf style-properties :justify-items) (getf local-state :justify-items "stretch"))
              (setf (getf style-properties :align-items) (getf local-state :align-items "stretch"))))
           (dolist (prop '(:width :height :min-width :min-height :max-width :max-height
                           :padding :margin :background-color :color :border :border-radius :overflow))
             (let ((value (getf local-state prop)))
               (when value (setf (getf style-properties prop) value))))
           (loop for (key val) on (getf local-state :other-style-props) by #'cddr
                 do (setf (getf style-properties key) val))
           (list :ui-element
                 :id component-id
                 :type :layout
                 :style style-properties
                 :children (mapcar
                            (lambda (child-id-segment)
                              (let* ((child-full-id-path (append self-id-path (list child-id-segment)))
                                     (child-type (get-path child-full-id-path app-state :type)))
                                (if child-type
                                    (let ((child-instance (make-instance child-type)))
                                      (elmtui.ui.api:view child-instance app-state :id-path child-full-id-path))
                                    (list :error "Child component type not found for ID: ~a in layout ~a"
                                          child-id-segment component-id))))
                            children-ids)))))
