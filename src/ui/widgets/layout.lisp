(uiop:define-package :elmtui.ui.widgets.layout
  (:use :cl :alexandria :elmtui.ui.defcomponent)
  (:import-from #:log4cl :log-info :log-debug :log-warn)
  (:import-from #:elmtui.utils :ensure-keyword)
  (:import-from :elmtui.ui.api
                #:component-id
                #:id-from-path       ; Used in user code
                #:init               ; For calling on children
                #:update             ; For calling on children
                #:view               ; For calling on children
                #:destroy            ; For defining and calling on children
                #:make-state-patch)  ; For manual patch creation (e.g. in destroy)
  (:import-from :elmtui.state.api
                #:ur-patches       ; For collecting child patches
                #:ur-commands       ; For collecting child commands
                #:get-path           ; Used in user code (e.g. for child state, or in destroy)
                #:make-update-result ; Used by defcomponent, good for reference
                #:update-result-patches
                #:update-result-commands)
  (:export #:layout))

(in-package :elmtui.ui.widgets.layout)

(defcomponent layout (elmtui.ui.api:component)
                                        ; () ;; No direct CLOS slots
  (:state
   ;; Core layout control
   (display :flex :type keyword :documentation "Display mode: :flex, :grid, :block, :none. Default :flex."
                  :initarg :display)

   ;; Flexbox specific properties
   (flex-direction :column :type keyword :documentation "Direction of flex items: :row, :column, :row-reverse, :column-reverse. Default :column."
                           :initarg :flex-direction)
   ;; (flex-wrap :nowrap :type keyword :documentation "Wrapping of flex items: :nowrap, :wrap, :wrap-reverse.") ; Future
   ;; (flex-flow ... ) ; Shorthand for direction and wrap - Future

   ;; Grid specific properties
   (grid-template-columns '("1fr") :type list :documentation "Defines grid column tracks. Default '(\"1fr\")."
                                   :initarg :grid-template-columns)
   (grid-template-rows '("auto") :type list :documentation "Defines grid row tracks. Default '(\"auto\")."
                                 :initarg :grid-template-rows)
   (grid-template-areas nil :type (or null list) :documentation "Specifies named grid areas."
                            :initarg :grid-template-areas)
   (grid-auto-flow "row" :type string :documentation "Controls auto-placement flow in grid: \"row\", \"column\", \"row dense\", \"column dense\". Default \"row\"."
                         :initarg :grid-auto-flow)
   ;; Gap properties (used by both flex and grid)
   (gap 0 :type (or integer string) :documentation "Gap between items (flex) or grid cells. Shorthand for row-gap and column-gap. Default 0."
          :initarg :gap)
   (row-gap nil :type (or null integer string) :documentation "Gap between flex lines or grid rows. Defaults to 'gap' if not set. Explicitly set to override 'gap'."
                :initarg :row-gap)
   (column-gap nil :type (or null integer string) :documentation "Gap between flex items or grid columns. Defaults to 'gap' if not set. Explicitly set to override 'gap'."
                   :initarg :column-gap)

   ;; Alignment & Justification (context-sensitive based on :display)
   (justify-content "start" :type string :documentation "Context-sensitive content justification (flex main axis, grid inline axis). Default \"start\"."
                            :initarg :justify-content)
   (align-items "stretch" :type string :documentation "Context-sensitive item alignment (flex cross axis, grid block axis for items). Default \"stretch\"."
                          :initarg :align-items)
   (align-content "start" :type string :documentation "Context-sensitive content alignment (multi-line flex, grid block axis for grid itself). Default \"start\"."
                          :initarg :align-content)
   (justify-items "stretch" :type string :documentation "Grid-specific item justification within its area. Default \"stretch\"."
                            :initarg :justify-items)

   ;; Common container properties
   (children-ids nil :type (or null list) :documentation "List of keyword IDs for child components.")
   (width nil :type (or null integer string) :documentation "Width of the layout container." :initarg :width)
   (height nil :type (or null integer string) :documentation "Height of the layout container." :initarg :height)
   (min-width nil :type (or null integer string) :documentation "Min-width of the layout." :initarg :min-width)
   (min-height nil :type (or null integer string) :documentation "Min-height of the layout." :initarg :min-height)
   (max-width nil :type (or null integer string) :documentation "Max-width of the layout." :initarg :max-width)
   (max-height nil :type (or null integer string) :documentation "Max-height of the layout." :initarg :max-height)
   (padding nil :type (or null integer string list) :documentation "Padding within the layout." :initarg :padding)
   (margin nil :type (or null integer string list) :documentation "Margin around the layout." :initarg :margin)
   (background-color nil :type (or null string keyword) :documentation "Background color." :initarg :background-color)
   (color nil :type (or null string keyword) :documentation "Foreground color." :initarg :color)
   (border nil :type (or null string) :documentation "Border style." :initarg :border)
   (border-radius nil :type (or null string integer) :documentation "Border radius." :initarg :border-radius)
   (overflow nil :type (or null keyword) :documentation "Overflow behavior." :initarg :overflow)
   (other-style-props nil :type (or null list) :documentation "Plist of other style properties passed during init."))




  (:documentation "A versatile component that arranges child components using flexbox or grid layouts, controlled by the :display property.")
  (:on-unhandled-message :log)

  (:init (props self-id-path)
         (let ((collected-child-effects nil)
               (collected-child-id-segments nil)
               (layout-state-settings nil)
               ;; Properties handled by :state + this :init logic
               (known-props '(:children :display :layout-type ; :layout-type for backward compat
                              :flex-direction :grid-template-columns :grid-template-rows
                              :grid-template-areas :grid-auto-flow
                              :gap :spacing ; :spacing for backward compat
                              :row-gap :column-gap
                              :justify-content :align-items :align-content :justify-items
                              :width :height :min-width :min-height :max-width :max-height
                              :padding :margin :background-color :color :border :border-radius :overflow)))

           ;; 1. Initialize children
           (loop for child-spec in (getf props :children) ; :children is the new standard
                 for child-type =  (elmtui.app.api:get-component-class-for-dsl-type (first child-spec))
                 for raw-child-id = (second (cdr child-spec))
                 for child-id-segment = (ensure-keyword raw-child-id)
                 for child-initargs = (cddr (cdr child-spec))
                 for child-full-id-path = (append self-id-path (list child-id-segment))
                 do
                    (push child-id-segment collected-child-id-segments)
                    (let ((child-instance (make-instance child-type :id child-id-segment)))
                      (multiple-value-bind (_child-instance child-patches child-commands)
                          (apply #'elmtui.ui.api:init child-instance :id-path child-full-id-path child-initargs)
                        (declare (ignore _child-instance))
                        (setf collected-child-effects (append child-patches child-commands collected-child-effects)))))
           (setf (getf layout-state-settings :children-ids) (nreverse collected-child-id-segments))

           ;; 2. Determine layout's own state settings
           ;; Display mode (handles old :layout-type and :column/:row for flex-direction)
           (let* ((explicit-display (getf props :display))
                  (old-layout-type (getf props :layout-type)) ; e.g. :column, :row, :grid
                  (final-display (or explicit-display
                                     (case old-layout-type
                                       ((:column :row) :flex) ; Map old :column/:row to :flex
                                       (:grid :grid)
                                       (otherwise (or old-layout-type :flex)))))) ; Default to flex
             (setf (getf layout-state-settings :display) final-display)

             (when (eq final-display :flex)
               (setf (getf layout-state-settings :flex-direction)
                     (or (getf props :flex-direction)
                         (case old-layout-type
                           (:column :column)
                           (:row :row)
                           (otherwise :column)))))) ; Default flex-direction

           ;; Gap properties (handles old :spacing)
           (let* ((explicit-gap (getf props :gap))
                  (old-spacing (getf props :spacing))
                  (base-gap-value (or explicit-gap old-spacing 0)))
             (setf (getf layout-state-settings :gap) base-gap-value)
             (setf (getf layout-state-settings :row-gap) (or (getf props :row-gap) base-gap-value))
             (setf (getf layout-state-settings :column-gap) (or (getf props :column-gap) base-gap-value)))

           ;; Other direct properties from :state (defcomponent handles merging with defaults)
           (dolist (prop-key '(:grid-template-columns :grid-template-rows :grid-template-areas :grid-auto-flow
                               :justify-content :align-items :align-content :justify-items
                               :width :height :min-width :min-height :max-width :max-height
                               :padding :margin :background-color :color :border :border-radius :overflow))
             (let ((val (getf props prop-key)))
               (when val (setf (getf layout-state-settings prop-key) val))))

           ;; Collect other unrecognized props for :other-style-props
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
                 ;; (log-info "Layout ~A: Adding child ~A (~A)." component-id child-id-key child-type)
                 (multiple-value-bind (_instance child-patches child-commands)
                     (apply #'elmtui.ui.api:init child-instance :id-path child-full-id-path child-initargs)
                   (declare (ignore _instance))
                   (values `(:children-ids ,(remove-duplicates new-children-ids :test #'equal)) ; State change for layout
                           (append child-patches child-commands))))) ; Effects from child init

   (:remove-child (child-id-segment)
                  (let* ((child-id-key (ensure-keyword child-id-segment))
                         (child-full-id-path (append self-id-path (list child-id-key)))
                         (new-children-ids (remove child-id-key (getf local-state :children-ids) :test #'equal))
                         (destroy-command `(:destroy-component-recursive ,child-full-id-path)))
                    ;; (log-info "Layout ~A: Removing child ~A." component-id child-id-key)
                    (values `(:children-ids ,new-children-ids)
                            (list destroy-command))))

   (:set-property (prop-keyword new-value)
                  (let ((state-changes-plist nil)
                        (known-direct-props '(:display :flex-direction
                                              :grid-template-columns :grid-template-rows :grid-template-areas :grid-auto-flow
                                              :row-gap :column-gap
                                              :justify-content :align-items :align-content :justify-items
                                              :width :height :min-width :min-height :max-width :max-height
                                              :padding :margin :background-color :color :border :border-radius :overflow
                                              :children-ids))); children-ids managed by add/remove
                    (cond
                      ((eq prop-keyword :gap)
                       (progn
                         (setf (getf state-changes-plist :gap) new-value)
                         ;; If row-gap was tracking the old gap or not explicitly set, update it.
                         (when (or (null (getf local-state :row-gap))
                                   (equal (getf local-state :row-gap) (getf local-state :gap)))
                           (setf (getf state-changes-plist :row-gap) new-value))
                         ;; If column-gap was tracking the old gap or not explicitly set, update it.
                         (when (or (null (getf local-state :column-gap))
                                   (equal (getf local-state :column-gap) (getf local-state :gap)))
                           (setf (getf state-changes-plist :column-gap) new-value))))
                      ((member prop-keyword known-direct-props)
                       (progn
                         (setf (getf state-changes-plist prop-keyword) new-value)
                         ;; Check if it's an existing "other" style prop
                         (let* ((otp (getf local-state :other-style-props))
                                (otp (assoc prop-keyword otp)))
                           (declare (ignorable otp))

                           (let ((osp (copy-list (getf local-state :other-style-props))))
                             (setf (getf osp prop-keyword) new-value)
                             (setf (getf state-changes-plist :other-style-props) osp)))))
                      (t ; New "other" style prop
                       ;; (log-warn "Layout ~A: Setting property ~S as a new 'other-style-prop'." component-id prop-keyword)
                       (setf (getf state-changes-plist :other-style-props)
                             (append (list prop-keyword new-value) (getf local-state :other-style-props)))))
                    ;; (when state-changes-plist
                    ;;   (log-debug "Layout ~A: Setting properties ~S" component-id state-changes-plist))
                    (values state-changes-plist nil)))

   (:message-to (target-child-id-segment child-message)
                (let* ((target-child-id (ensure-keyword target-child-id-segment))
                       (child-full-id-path (append self-id-path (list target-child-id)))
                       (child-type (elmtui.state.api:get-path child-full-id-path app-state :type)))
                  (if (and child-type (find target-child-id (getf local-state :children-ids) :test #'equal))
                      (let* ((child-instance (make-instance child-type))
                             (child-update-result (apply #'elmtui.ui.api:update child-instance app-state child-message :id-path child-full-id-path)))
                        (values nil ; No direct state change for layout
                                (append (ur-patches child-update-result)
                                        (ur-commands child-update-result))))
                      (progn
                        ;; (log-warn "Layout ~A: Message ~S targeted non-child or unknown-type child ~A."
                        ;;           component-id child-message target-child-id)
                        (values nil nil))))))





  (:view (local-state app-state self-id-path)
         (let* ((component-id (id-from-path self-id-path))
                (children-ids (getf local-state :children-ids))
                (display-mode (getf local-state :display :flex))
                (style-properties nil))

           (setf (getf style-properties :display) display-mode)

           ;; Apply layout-specific styles based on display mode
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
              (setf (getf style-properties :gap) (getf local-state :gap 0)) ; Base gap
              (setf (getf style-properties :row-gap) (or (getf local-state :row-gap) (getf local-state :gap 0)))
              (setf (getf style-properties :column-gap) (or (getf local-state :column-gap) (getf local-state :gap 0)))
              (setf (getf style-properties :justify-content) (getf local-state :justify-content "start"))
              (setf (getf style-properties :align-content) (getf local-state :align-content "start"))
              (setf (getf style-properties :justify-items) (getf local-state :justify-items "stretch"))
              (setf (getf style-properties :align-items) (getf local-state :align-items "stretch"))))
           ;; Other display modes like :block, :none don't add specific sub-properties here beyond :display itself.

           ;; Add common styling properties
           (dolist (prop '(:width :height :min-width :min-height :max-width :max-height
                           :padding :margin :background-color :color :border :border-radius :overflow))
             (let ((value (getf local-state prop)))
               (when value (setf (getf style-properties prop) value))))

           ;; Merge properties from :other-style-props
           (loop for (key val) on (getf local-state :other-style-props) by #'cddr
                 do (setf (getf style-properties key) val))

           (list :ui-element
                 :id component-id
                 :type :layout ; or (cclass-name self) if self was available, but type is good for renderer
                 :style style-properties
                 :children (mapcar
                            (lambda (child-id-segment)
                              (let* ((child-full-id-path (append self-id-path (list child-id-segment)))
                                     (child-type (elmtui.state.api:get-path child-full-id-path  app-state :type)))
                                (if child-type
                                    (let ((child-instance (make-instance child-type)))
                                      (elmtui.ui.api:view child-instance app-state :id-path child-full-id-path))
                                    (list :error "Child component type not found for ID: ~a in layout ~a"
                                          child-id-segment component-id))))
                            children-ids)))))





;; Manual destroy method for layout
;; (defmethod elmtui.ui.api:destroy ((self layout) app-state &key id-path)
;;   (let ((layout-local-state (elmtui.state.api:get-path id-path app-state ))
;;         (all-patches nil)
;;         (all-commands nil))

;;     (log-info "Destroying layout ~A and its children." (id-from-path id-path))

;;     (loop for child-id-segment in (getf layout-local-state :children-ids)
;;           for child-full-id-path = (append id-path (list child-id-segment))
;;           for child-type = (elmtui.state.api:get-path child-full-id-path  app-state :type)
;;           when child-type
;;             do (let ((child-instance (make-instance child-type)))
;;                  (multiple-value-bind (child-patches child-commands-from-destroy)
;;                      (elmtui.ui.api:destroy child-instance app-state :id-path child-full-id-path)
;;                    (setf all-patches (append child-patches all-patches))
;;                    (setf all-commands (append child-commands-from-destroy all-commands))))
;;           else
;;             do (log-warn "Layout destroy: Child ~A type not found for path ~A during layout ~A destruction."
;;                          child-id-segment child-full-id-path (id-from-path id-path)))

;;     ;; Add patch to remove the layout's own state
;;     (push (elmtui.ui.api:make-state-patch id-path :elmtui-delete-path) all-patches)
;;     (values (nreverse all-patches) (nreverse all-commands))))
;; )
;; (elmtui.app.api:registered-dsl-component-p :layout)
