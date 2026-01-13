(uiop:define-package :elmtui.ui.widgets.panel
  (:use :cl :alexandria :elmtui.ui.defcomponent)
  (:import-from :elmtui.ui.api
                #:component #:id-from-path #:app-state #:get-component-property
                #:init #:update #:view #:destroy #:make-state-patch) ; Added make-state-patch
  (:import-from :elmtui.state.api
                #:make-update-result
                #:get-path
                #:state-ref
                #:update-result-patches
                #:update-result-commands)
  (:export #:panel))

(in-package :elmtui.ui.widgets.panel)

(defcomponent panel ()
    () ;; No direct CLOS slots
    (:state
     (title nil :type (or null string) :documentation "Optional title for the panel."
                  :initarg :title :accessor panel-title)
     (border-style :single :type keyword :documentation "Style of the border (e.g., :none, :single, :double, :rounded)."
                           :initarg :border-style :accessor panel-border-style)
     (padding 0 :type (or null integer string list) :documentation "Internal padding. Integer for all sides, list (t r b l), or CSS string."
                  :initarg :padding :accessor panel-padding)
     (children-ids nil :type list :documentation "List of keyword IDs for child components managed by this panel.")
     ;; Common style properties that have initargs
     (width nil :type (or null integer string) :documentation "Width of the panel."
                  :initarg :width :accessor panel-width)
     (height nil :type (or null integer string) :documentation "Height of the panel."
                   :initarg :height :accessor panel-height)
     (margin nil :type (or null integer string list) :documentation "Margin around the panel."
                   :initarg :margin :accessor panel-margin)
     (background-color nil :type (or null string keyword) :documentation "Background color of the panel."
                                 :initarg :background-color :accessor panel-background-color)
     (color nil :type (or null string keyword) :documentation "Foreground color (text color) of the panel."
                  :initarg :color :accessor panel-color)
     (border nil :type (or null string) :documentation "Explicit border string (e.g., \"1px solid green\"). Overrides border-style if set."
                   :initarg :border :accessor panel-border)
     (border-radius nil :type (or null string integer) :documentation "Border radius for rounded corners."
                          :initarg :border-radius :accessor panel-border-radius)
     (overflow nil :type (or null keyword) :documentation "Overflow behavior (e.g., :hidden, :scroll, :auto)."
                     :initarg :overflow :accessor panel-overflow)
     ;; For any other properties passed to make-instance not covered by above initargs
     (other-style-props nil :type list :documentation "Plist of other style properties passed during init."))
  (:documentation "A panel component that visually groups its children, often with a border and title.")
  (:on-unhandled-message :log)

  (:init (props self-id-path)
   (let ((collected-child-effects nil)
         (collected-child-id-segments nil)
         (other-props-for-state nil)
         ;; List of initargs that defcomponent will handle for the panel's own state
         (panel-handled-initargs '(:title :border-style :padding :width :height :margin
                                   :background-color :color :border :border-radius :overflow)))

     ;; Initialize children from the :children prop
     (loop for child-spec in (getf props :children)
           for child-type = (first child-spec)
           for child-id-segment = (second child-spec) ; e.g., :button1
           for child-initargs = (cddr child-spec)
           for child-full-id-path = (append self-id-path (list child-id-segment))
           do
              (push child-id-segment collected-child-id-segments)
              (let ((child-instance (make-instance child-type)))
                (multiple-value-bind (_child-instance child-patches child-commands)
                    (apply #'elmtui.ui.api:init child-instance :id-path child-full-id-path child-initargs)
                  (declare (ignore _child-instance))
                  (setf collected-child-effects
                        (append child-patches child-commands collected-child-effects)))))
     
     ;; Collect any props passed to make-instance that are not :children and not one of the panel's direct initargs
     (loop for (key val) on props by #'cddr
           unless (or (eq key :children) (member key panel-handled-initargs))
             do (setf other-props-for-state (list* key val other-props-for-state)))
     
     ;; Return values for state fields that defcomponent doesn't automatically handle from initargs,
     ;; or that need special calculation.
     ;; :title, :border-style, etc., will be set by defcomponent from props using their :initargs.
     (values `(:children-ids ,(nreverse collected-child-id-segments)
               :other-style-props ,(nreverse other-props-for-state))
             (nreverse collected-child-effects))))

  (:update (message local-state app-state self-id-path)
   (:set-property (prop-keyword new-value)
    (if (member prop-keyword '(:title :border-style :padding :width :height :margin :background-color :color :border :border-radius :overflow))
        (values (list prop-keyword new-value) nil)
        (let ((current-other-styles (getf local-state :other-style-props)))
          (if (getf current-other-styles prop-keyword) ;; Check if it's an existing "other" style
              (values `(:other-style-props ,(let ((osp (copy-list current-other-styles)))
                                              (setf (getf osp prop-keyword) new-value)
                                              osp))
                      nil)
              (progn
                (warn "Panel ~A: Attempt to set unknown property ~S via :set-property." (id-from-path self-id-path) prop-keyword)
                (values nil nil))))))
   
   (:add-child (child-id-segment child-type &rest child-initargs)
    (let* ((child-full-id-path (append self-id-path (list child-id-segment)))
           (child-instance (make-instance child-type))
           (new-children-ids (cons child-id-segment (getf local-state :children-ids))))
      (multiple-value-bind (_instance child-patches child-commands)
          (apply #'elmtui.ui.api:init child-instance :id-path child-full-id-path child-initargs)
        (declare (ignore _instance))
        (values `(:children-ids ,(remove-duplicates new-children-ids :test #'equal))
                (append child-patches child-commands)))))

   (:remove-child (child-id-segment)
    (let* ((child-full-id-path (append self-id-path (list child-id-segment)))
           (new-children-ids (remove child-id-segment (getf local-state :children-ids) :test #'equal))
           ;; Command to trigger destruction of the child component's state and view
           (destroy-command `(:destroy-component-recursive ,child-full-id-path)))
      (values `(:children-ids ,new-children-ids) (list destroy-command))))

   (:message-to (target-child-id-segment &rest child-message)
    (let* ((child-full-id-path (append self-id-path (list target-child-id-segment)))
           (child-type (get-path child-full-id-path app-state :type)))
      (if (and child-type (find target-child-id-segment (getf local-state :children-ids) :test #'equal))
          (let* ((child-instance (make-instance child-type))
                 (child-update-result (elmtui.ui.api:update child-instance app-state child-message :id-path child-full-id-path)))
            (values nil ; No local state change for the panel itself
                    (append (update-result-patches child-update-result)
                            (update-result-commands child-update-result))))
          (progn
            (warn "Panel ~A: Message ~S targeted non-child or unknown-type child ~A."
                  (id-from-path self-id-path) child-message target-child-id-segment)
            (values nil nil))))))

  (:view (local-state app-state self-id-path)
   (let* ((component-id (id-from-path self-id-path))
          (title (getf local-state :title))
          (border-style (getf local-state :border-style :single))
          (padding-val (getf local-state :padding 0))
          (children-ids (getf local-state :children-ids))
          (style-properties nil))

     ;; Populate style-properties from local-state's direct style fields
     (loop for style-key in '(:width :height :margin :background-color :color :border :border-radius :overflow)
           for value = (getf local-state style-key)
           when value
             do (setf (getf style-properties style-key) value))
     (setf (getf style-properties :padding) padding-val)

     ;; Merge properties from :other-style-props
     (loop for (key val) on (getf local-state :other-style-props) by #'cddr
           do (setf (getf style-properties key) val))
           
     (setf (getf style-properties :display) :block)

     (unless (getf style-properties :border)
       (case border-style
         (:single (setf (getf style-properties :border) "1px solid"))
         (:double (setf (getf style-properties :border) "3px double"))
         (:rounded (setf (getf style-properties :border) "1px solid")
                   (unless (getf style-properties :border-radius)
                     (setf (getf style-properties :border-radius) "5px")))))
     
     `(:ui-element
       :id ,component-id
       :type :panel
       :style ,style-properties
       :properties `(,@(when title `(:title ,title))
                     :border-style ,border-style)
       :children ,(mapcar (lambda (child-id-segment)
                            (let* ((child-full-id-path (append self-id-path (list child-id-segment)))
                                   (child-type (get-path child-full-id-path app-state :type)))
                              (if child-type
                                  (let ((child-instance (make-instance child-type)))
                                    (elmtui.ui.api:view child-instance app-state :id-path child-full-id-path))
                                  `(:error "Child component type not found for ID: ~a in panel ~a"
                                          ,child-id-segment ,component-id))))
                          children-ids)))))

;; Method to handle destruction of the panel and its children
(defmethod elmtui.ui.api:destroy ((self panel) app-state &key id-path)
  (let ((panel-local-state (get-path id-path app-state))
        (all-patches nil)
        (all-commands nil))

    (loop for child-id-segment in (getf panel-local-state :children-ids)
          for child-full-id-path = (append id-path (list child-id-segment))
          for child-type = (get-path child-full-id-path app-state :type)
          when child-type
            do (let ((child-instance (make-instance child-type)))
                 (multiple-value-bind (child-patches child-commands-from-destroy)
                     (elmtui.ui.api:destroy child-instance app-state :id-path child-full-id-path)
                   (setf all-patches (append child-patches all-patches))
                   (setf all-commands (append child-commands-from-destroy all-commands))))
          else
            do (warn "Panel destroy: Child ~A type not found for path ~A during panel ~A destruction."
                     child-id-segment child-full-id-path (id-from-path id-path)))

    (push (elmtui.ui.api:make-state-patch id-path :elmtui-delete-path) all-patches)

    (values (nreverse all-patches) (nreverse all-commands))))
