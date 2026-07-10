;;;===============================================================
;;; File: src/ui/widgets/button-enhanced.lisp
;;; Enhanced Button Widget with DSL Integration and Contracts
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.button-enhanced
  (:use :cl :alexandria)
  (:import-from :elmtui.view.dsl 
                #:dsl->ui-node)
  (:import-from :elmtui.state.model
                #:defmodel-contracted #:defpatch #:deftransaction #:make-state-patch #:apply-state-patches)
  (:import-from :elmtui.contracts
                #:defupdate-hybrid #:defview)
  (:import-from :elmtui.ui.defcomponent #:defcomponent)
  (:import-from :elmtui.ui.api #:id-from-path)
  (:import-from :elmtui.state.msg #:defmsg)
  (:export 
   #:button-enhanced #:make-button-enhanced
   ;; Button state model
   #:button-state #:make-button-state #:validate-button-state
   ;; Button operations
   #:update-button-text #:set-button-style #:toggle-button-state
   ;; Button messages
   #:ButtonMsg
   ;; Legacy compatibility
   #:button))

(in-package :elmtui.ui.widgets.button-enhanced)

;; Lightweight shims for DSL helpers
(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (fboundp 'validate-base-dsl)
    (defun validate-base-dsl (dsl) dsl))
  (unless (fboundp 'expand-base-dsl)
    (defun expand-base-dsl (dsl) dsl)))

;;;--------------------------------------------------------------
;;; Button Message Schema
;;;--------------------------------------------------------------

(defmsg ButtonMsg (:docstring "Messages for button widget interactions")
  ;; User interactions
  ButtonClicked
  ButtonPressed
  ButtonReleased
  
  ;; Focus events  
  ButtonFocused
  ButtonBlurred
  
  ;; State changes
  (SetButtonText :text string)
  (SetButtonDisabled :disabled boolean)
  (SetButtonStyle :property keyword :value t)
  (SetButtonVariant :variant keyword)
  
  ;; Action configuration
  (SetButtonAction :action t)
  (SetButtonHotkey :key keyword :modifiers list))

;;;--------------------------------------------------------------
;;; Enhanced Button State Model
;;;--------------------------------------------------------------

(defmodel-contracted button-state
  ((text "Button" :type string :required t
         :validator (lambda (v) (and (stringp v) (> (length v) 0))))
   (disabled nil :type boolean)
   (focused nil :type boolean)
   (pressed nil :type boolean :documentation "Whether button is currently being pressed")
   (variant :default :type keyword 
            :validator (lambda (v) (member v '(:default :primary :secondary :success :warning :danger :info))))
   (size :medium :type keyword
         :validator (lambda (v) (member v '(:small :medium :large :extra-large))))
   (style :solid :type keyword
          :validator (lambda (v) (member v '(:solid :outline :ghost :link))))
   (icon nil :type (or null keyword string))
   (icon-position :left :type keyword
                  :validator (lambda (v) (member v '(:left :right :top :bottom))))
   (hotkey nil :type (or null keyword))
   (hotkey-modifiers nil :type list)
   (action nil :type t :documentation "Action to execute when clicked")
   (loading nil :type boolean :documentation "Whether button is in loading state")
   (tooltip nil :type (or null string))
   (aria-label nil :type (or null string))
   (form-action nil :type (or null keyword) 
                :validator (lambda (v) (or (null v) (member v '(:submit :reset :button)))))
   (width nil :type (or null keyword integer))
   (height nil :type (or null keyword integer))
   (full-width nil :type boolean :documentation "Whether button takes full container width")
   (visible t :type boolean)
   (focusable t :type boolean))
  
  :validation (lambda (state)
                ;; Custom validation rules
                (when (and (getf state :disabled) (getf state :focused))
                  (warn "Button is disabled but focused - this may cause accessibility issues"))
                
                (when (and (getf state :loading) (not (getf state :disabled)))
                  (warn "Loading button should typically be disabled"))
                
                (when (and (getf state :hotkey) (not (getf state :focusable)))
                  (error "Button with hotkey must be focusable")))
  
  :transactions
  ((click-button-transaction (state)
     "Transaction for button click interaction"
     (if (or (getf state :disabled) (getf state :loading))
         ;; No state change if disabled or loading
         nil
         ;; Brief pressed state for visual feedback
         (list (make-state-patch :path '(:pressed) :value t :operation :set))))
   
   (set-button-text-transaction (state new-text)
     "Transaction to update button text"
     (list (make-state-patch :path '(:text) :value new-text :operation :set)))
   
   (set-button-state-transaction (state disabled loading)
     "Transaction to update button interactive state"
     (list (make-state-patch :path '(:disabled) :value disabled :operation :set)
           (make-state-patch :path '(:loading) :value loading :operation :set)
           ;; If disabling, also unfocus
           (when disabled
             (make-state-patch :path '(:focused) :value nil :operation :set))))
   
   (set-button-style-transaction (state variant size style)
     "Transaction to update button visual style"
     (list (make-state-patch :path '(:variant) :value variant :operation :set)
           (make-state-patch :path '(:size) :value size :operation :set)
           (make-state-patch :path '(:style) :value style :operation :set))))
  
  :observers
  ((lambda (old-state new-state change-type)
     (declare (ignore old-state new-state change-type))
     nil))
  
  :documentation "Comprehensive button state model with interaction tracking and accessibility"
  :export-accessors t)

;;;--------------------------------------------------------------
;;; Button Patch Operations
;;;--------------------------------------------------------------

(defpatch update-button-text (state new-text)
  "Updates button text with validation"
  (make-state-patch :path '(:text)
                   :value new-text
                   :operation :set
                   :validator (lambda (v) (and (stringp v) (> (length v) 0)))
                   :source :user-action
                   :metadata (list :old-text (getf state :text))))

(defpatch set-button-style (state property value)
  "Updates a button style property"
  (let ((valid-properties '(:variant :size :style :icon :icon-position :width :height :full-width)))
    (unless (member property valid-properties)
      (error "Invalid button style property: ~A" property))
    
    (make-state-patch :path (list property)
                     :value value
                     :operation :set
                     :source :style-update
                     :metadata (list :property property :old-value (getf state property)))))

(defpatch toggle-button-state (state property)
  "Toggles a boolean button state property"
  (let ((valid-toggles '(:disabled :loading :focused :pressed :full-width :visible :focusable))
        (current-value (getf state property)))
    (unless (member property valid-toggles)
      (error "Invalid button toggle property: ~A" property))
    
    (make-state-patch :path (list property)
                     :value (not current-value)
                     :operation :set
                     :source :state-toggle)))

;;;--------------------------------------------------------------
;;; Enhanced Button Component (using defcomponent)
;;;--------------------------------------------------------------

(defcomponent button-enhanced ()
  (:metadata
   (:documentation "Enhanced button component with typed messages and accessibility metadata."))
  
  (:state
   (text "Button" :type string)
   (disabled nil :type (or null boolean))
   (action nil :type (or null t))
   (style nil :type (or null list)))
  
  (:init (props id-path)
    (let ((initial-state (make-button-state
                         :text (getf props :text (getf props :initial-text "Button"))
                         :disabled (getf props :disabled nil)
                         :variant (getf props :variant :default)
                         :size (getf props :size :medium)
                         :style (getf props :style :solid)
                         :icon (getf props :icon)
                         :icon-position (getf props :icon-position :left)
                         :action (getf props :action)
                         :hotkey (getf props :hotkey)
                         :hotkey-modifiers (getf props :hotkey-modifiers)
                         :tooltip (getf props :tooltip)
                         :aria-label (getf props :aria-label)
                         :form-action (getf props :form-action)
                         :width (getf props :width)
                         :height (getf props :height)
                         :full-width (getf props :full-width nil)
                         :visible (getf props :visible t)
                         :focusable (getf props :focusable t))))
      (values initial-state nil)))
  
  (:update (message state app-state id-path)
    ;; Handle typed messages
    (:button-clicked ()
      (if (or (getf state :disabled) (getf state :loading))
          (values state nil)
          (let ((action (getf state :action)))
            (values state (when action (list action))))))
    
    (:button-pressed ()
      (unless (getf state :disabled)
        (values (list* :pressed t state) nil)))
    
    (:button-released ()
      (values (list* :pressed nil state) nil))
    
    (:button-focused ()
      (if (and (getf state :focusable) (not (getf state :disabled)))
          (values (list* :focused t state) nil)
          (values state nil)))
    
    (:button-blurred ()
      (values (list* :focused nil state) nil))
    
    (:set-button-text (text)
      (let ((patches (update-button-text state text)))
        (values (apply-state-patches state (list patches)) nil)))
    
    (:set-button-disabled (disabled)
      (let ((new-state (list* :disabled disabled state)))
        ;; If disabling, also unfocus
        (when disabled
          (setf new-state (list* :focused nil new-state)))
        (values new-state nil)))
    
    (:set-button-style (property value)
      (let ((patches (set-button-style state property value)))
        (values (apply-state-patches state (list patches)) nil)))
    
    (:set-button-variant (variant)
      (values (list* :variant variant state) nil))
    
    (:set-button-action (action)
      (values (list* :action action state) nil))
    
    (:set-button-hotkey (key modifiers)
      (values (list* :hotkey key :hotkey-modifiers modifiers state) nil))
    
    ;; Handle flexible messages
    (:click ()
      (if (or (getf state :disabled) (getf state :loading))
          (values state nil)
          (let ((action (getf state :action)))
            (values state (when action (list action))))))
    
    (:focus ()
      (if (and (getf state :focusable) (not (getf state :disabled)))
          (values (list* :focused t state) nil)
          (values state nil)))
    
    (:blur ()
      (values (list* :focused nil state) nil))
    
    (:disable ()
      (values (list* :disabled t :focused nil state) nil))
    
    (:enable ()
      (values (list* :disabled nil state) nil))
    
    (:toggle-loading ()
      (let ((current-loading (getf state :loading)))
        (values (list* :loading (not current-loading) state) nil))))
  
  (:view (state app-state id-path children)
    (declare (ignore app-state children))
    (let* ((component-id (id-from-path id-path))
           (text (getf state :text "Button"))
           (disabled (getf state :disabled))
           (focused (getf state :focused))
           (pressed (getf state :pressed))
           (loading (getf state :loading))
           (variant (getf state :variant :default))
           (size (getf state :size :medium))
           (style-type (getf state :style :solid))
           (icon (getf state :icon))
           (icon-position (getf state :icon-position :left))
           (tooltip (getf state :tooltip))
           (aria-label (getf state :aria-label))
           (form-action (getf state :form-action))
           (width (getf state :width))
           (height (getf state :height))
           (full-width (getf state :full-width))
           (visible (getf state :visible t))
           (focusable (getf state :focusable t))
           (style-props nil))
      
      ;; Build style properties
      (when width
          (setf (getf style-props :width) width))
        (when height
          (setf (getf style-props :height) height))
        (when full-width
          (setf (getf style-props :width) "100%"))
        (when (not visible)
          (setf (getf style-props :display) :none))
        
        ;; Variant-specific styling
        (setf (getf style-props :background-color) (variant-background-color variant style-type))
        (setf (getf style-props :color) (variant-text-color variant style-type))
        (setf (getf style-props :border) (variant-border variant style-type))
        
        ;; Size-specific styling
        (multiple-value-bind (padding font-size) (size-properties size)
          (setf (getf style-props :padding) padding)
          (setf (getf style-props :font-size) font-size))
        
        ;; State-specific styling
        (when pressed
          (setf (getf style-props :transform) "scale(0.98)"))
        (when focused
          (setf (getf style-props :outline) "2px solid blue"))
      (when (or disabled loading)
        (setf (getf style-props :opacity) 0.6)
        (setf (getf style-props :cursor) :not-allowed))
      
      ;; Build CSS classes
      (let ((classes (list :ui-button
                          (intern (format nil "BUTTON-~A" (string-upcase variant)) :keyword)
                          (intern (format nil "BUTTON-~A" (string-upcase size)) :keyword)
                          (intern (format nil "BUTTON-~A" (string-upcase style-type)) :keyword))))
        (when disabled (push :disabled classes))
        (when focused (push :focused classes))
        (when pressed (push :pressed classes))
        (when loading (push :loading classes))
        (when full-width (push :full-width classes))
        
        ;; Generate button content
        (let ((button-content (build-button-content text icon icon-position loading)))
          
          ;; Generate base DSL
          (let ((button-dsl
                 `(:button
                   :id ,component-id
                   :text ,text
                   :class ,classes
                   :style ,style-props
                   :disabled ,(or disabled loading)
                   :focusable ,(and focusable (not disabled) (not loading))
                   :on-click ,(unless (or disabled loading) '(:button-clicked))
                   :on-focus ,(unless (or disabled loading) '(:button-focused))
                   :on-blur '(:button-blurred)
                   :on-key-down ,(when (getf state :hotkey)
                                  `(:hotkey-pressed :key ,(getf state :hotkey)))
                   :aria-role :button
                   :aria-pressed ,(if pressed "true" "false")
                   :aria-disabled ,(if (or disabled loading) "true" "false")
                   ,@(when tooltip `(:title ,tooltip))
                   ,@(when aria-label `(:aria-label ,aria-label))
                   ,@(when form-action `(:type ,form-action))
                   :children ,button-content)))
            
            ;; Validate and expand the DSL
            (validate-base-dsl button-dsl)
            (expand-base-dsl button-dsl)))))))

;;;--------------------------------------------------------------
;;; Button Styling Helpers
;;;--------------------------------------------------------------

(defun variant-background-color (variant style-type)
  "Returns background color based on variant and style"
  (case style-type
    (:solid
     (case variant
       (:primary "#007bff")
       (:secondary "#6c757d") 
       (:success "#28a745")
       (:warning "#ffc107")
       (:danger "#dc3545")
       (:info "#17a2b8")
       (t "#f8f9fa")))
    (:outline "transparent")
    (:ghost "transparent")
    (:link "transparent")))

(defun variant-text-color (variant style-type)
  "Returns text color based on variant and style"
  (case style-type
    (:solid
     (if (member variant '(:primary :secondary :success :danger :info))
         "#ffffff"
         "#212529"))
    ((:outline :ghost :link)
     (case variant
       (:primary "#007bff")
       (:secondary "#6c757d")
       (:success "#28a745")
       (:warning "#ffc107")
       (:danger "#dc3545")
       (:info "#17a2b8")
       (t "#212529")))))

(defun variant-border (variant style-type)
  "Returns border style based on variant and style"
  (case style-type
    ((:solid :outline)
     (format nil "1px solid ~A" 
             (case variant
               (:primary "#007bff")
               (:secondary "#6c757d")
               (:success "#28a745")
               (:warning "#ffc107") 
               (:danger "#dc3545")
               (:info "#17a2b8")
               (t "#dee2e6"))))
    ((:ghost :link) "none")))

(defun size-properties (size)
  "Returns padding and font-size for button size"
  (case size
    (:small (values "4px 8px" "12px"))
    (:medium (values "8px 16px" "14px"))
    (:large (values "12px 24px" "16px"))
    (:extra-large (values "16px 32px" "18px"))
    (t (values "8px 16px" "14px"))))

(defun build-button-content (text icon icon-position loading)
  "Builds the content structure for the button"
  (cond
    ;; Loading state
    (loading
     (list `(:container
             :layout :horizontal 
             :style (:align-items :center :gap 8)
             :children ((:text :content "⟳" :class (:loading-spinner))
                       (:text :content ,text)))))
    
    ;; Icon + text
    (icon
     (let ((icon-element `(:text :content ,icon :class (:button-icon)))
           (text-element `(:text :content ,text :class (:button-text))))
       (case icon-position
         (:left (list `(:container :layout :horizontal :style (:gap 8) 
                                  :children (,icon-element ,text-element))))
         (:right (list `(:container :layout :horizontal :style (:gap 8)
                                   :children (,text-element ,icon-element))))
         (:top (list `(:container :layout :vertical :style (:gap 4)
                                 :children (,icon-element ,text-element))))
         (:bottom (list `(:container :layout :vertical :style (:gap 4)
                                   :children (,text-element ,icon-element))))
         (t (list text-element)))))
    
    ;; Text only
    (t (list `(:text :content ,text :class (:button-text))))))

;;;--------------------------------------------------------------
;;; Contract-Enforced Functions for Direct Use
;;;--------------------------------------------------------------

(defupdate-hybrid button-enhanced-update (message model)
    :message-type ButtonMsg :prefer-typed t
  "Enhanced button update function for direct use"
  
  (let ((msg-type (if (listp message) (first message) message))
        (msg-data (when (listp message) (rest message))))
    
    (case msg-type
      ;; Typed messages
      (:button-clicked
       (unless (or (getf model :disabled) (getf model :loading))
         (let ((action (getf model :action)))
           (values model (when action (list action))))))
      
      (:set-button-text
       (let ((new-text (getf msg-data :text)))
         (when (stringp new-text)
           (let ((patches (update-button-text model new-text)))
             (values (apply-state-patches model (list patches)) nil)))))
      
      (:set-button-disabled
       (let ((disabled (getf msg-data :disabled)))
         (multiple-value-bind (new-state transaction)
             (set-button-state-transaction model disabled (getf model :loading))
           (declare (ignore transaction))
           (values new-state nil))))
      
      (:set-button-style
       (let ((property (getf msg-data :property))
             (value (getf msg-data :value)))
         (when (and property value)
           (let ((patches (set-button-style model property value)))
             (values (apply-state-patches model (list patches)) nil)))))
      
      ;; Flexible messages
      (:click
       (unless (or (getf model :disabled) (getf model :loading))
         (let ((action (getf model :action)))
           (values model (when action (list action))))))
      
      (:focus
       (if (and (getf model :focusable) (not (getf model :disabled)))
           (values (list* :focused t model) nil)
           (values model nil)))
      
      (:blur
       (values (list* :focused nil model) nil))
      
      (t (values nil nil)))))

(defview button-enhanced-view (model)
  "Enhanced button view function for direct use"
  
  (let* ((text (getf model :text "Button"))
         (component-id (getf model :id :button))
         (disabled (getf model :disabled))
         (pressed (getf model :pressed)))
    
    ;; Generate and validate base DSL
    (let ((button-dsl
           `(:button
             :id ,component-id
             :text ,text
             :class ,(build-button-classes model)
             :style ,(build-button-style-props model)
             :disabled ,(or disabled (getf model :loading))
             :focusable ,(and (getf model :focusable t) (not disabled))
             :on-click ,(unless (or disabled (getf model :loading)) '(:button-clicked))
             :aria-role :button
             :aria-pressed ,(if pressed "true" "false")
             :children ,(build-button-content text (getf model :icon) 
                                             (getf model :icon-position :left) 
                                             (getf model :loading)))))
      
      (validate-base-dsl button-dsl)
      button-dsl)))

;;;--------------------------------------------------------------
;;; Helper Functions
;;;--------------------------------------------------------------

(defun build-button-style-props (model)
  "Builds style properties from button state"
  (let ((style-props nil)
        (variant (getf model :variant :default))
        (size (getf model :size :medium))
        (style-type (getf model :style :solid))
        (pressed (getf model :pressed))
        (focused (getf model :focused))
        (disabled (getf model :disabled))
        (loading (getf model :loading)))
    
    ;; Size and dimensions
    (when (getf model :width)
      (setf (getf style-props :width) (getf model :width)))
    (when (getf model :height)
      (setf (getf style-props :height) (getf model :height)))
    (when (getf model :full-width)
      (setf (getf style-props :width) "100%"))
    
    ;; Variant styling
    (setf (getf style-props :background-color) (variant-background-color variant style-type))
    (setf (getf style-props :color) (variant-text-color variant style-type))
    (setf (getf style-props :border) (variant-border variant style-type))
    
    ;; Size styling
    (multiple-value-bind (padding font-size) (size-properties size)
      (setf (getf style-props :padding) padding)
      (setf (getf style-props :font-size) font-size))
    
    ;; State styling
    (when pressed
      (setf (getf style-props :transform) "scale(0.98)"))
    (when focused
      (setf (getf style-props :outline) "2px solid blue"))
    (when (or disabled loading)
      (setf (getf style-props :opacity) 0.6)
      (setf (getf style-props :cursor) :not-allowed))
    (when (not (getf model :visible t))
      (setf (getf style-props :display) :none))
    
    style-props))

(defun build-button-classes (model)
  "Builds CSS classes from button state"
  (let ((classes (list :ui-button
                      (intern (format nil "BUTTON-~A" (string-upcase (getf model :variant :default))) :keyword)
                      (intern (format nil "BUTTON-~A" (string-upcase (getf model :size :medium))) :keyword)
                      (intern (format nil "BUTTON-~A" (string-upcase (getf model :style :solid))) :keyword))))
    
    (when (getf model :disabled) (push :disabled classes))
    (when (getf model :focused) (push :focused classes))
    (when (getf model :pressed) (push :pressed classes))
    (when (getf model :loading) (push :loading classes))
    (when (getf model :full-width) (push :full-width classes))
    (when (not (getf model :visible t)) (push :hidden classes))
    
    (nreverse classes)))

;;;--------------------------------------------------------------
;;; Legacy Compatibility
;;;--------------------------------------------------------------

;; Legacy button class for compatibility
(defclass button (button-enhanced)
  ()
  (:documentation "Legacy button compatibility class"))

(defun make-button-enhanced (&key id text disabled action variant size style)
  "Creates a new enhanced button instance"
  (make-instance 'button-enhanced :id id :text text :disabled disabled 
                :action action :variant variant :size size :style style))

;; Legacy factory function
(defun make-button (&key id text action disabled)
  "Legacy button factory function"
  (make-button-enhanced :id id :text text :action action :disabled disabled))

;;;--------------------------------------------------------------
;;; Button Utilities
;;;--------------------------------------------------------------

(defun button-accessibility-check (button-state)
  "Validates button accessibility properties"
  (let ((issues nil))
    
    ;; Check for meaningful text
    (when (or (null (getf button-state :text))
             (string= (getf button-state :text) "")
             (string= (getf button-state :text) "Button"))
      (push "Button has generic or empty text" issues))
    
    ;; Check for action
    (unless (getf button-state :action)
      (push "Button has no action defined" issues))
    
    ;; Check focusability
    (when (and (not (getf button-state :disabled))
              (not (getf button-state :focusable)))
      (push "Interactive button should be focusable" issues))
    
    ;; Check loading state
    (when (and (getf button-state :loading)
              (not (getf button-state :disabled)))
      (push "Loading button should be disabled" issues))
    
    (if issues issues t)))

(defun describe-button-state (button-state &optional stream)
  "Return detailed information about BUTTON-STATE as a string.
When STREAM is non-NIL, also write the description to that stream."
  (let ((description
          (with-output-to-string (out)
            (format out "~&Button State:~%")
            (format out "  Text: '~A'~%" (getf button-state :text))
            (format out "  Variant: ~A Size: ~A Style: ~A~%"
                    (getf button-state :variant)
                    (getf button-state :size)
                    (getf button-state :style))
            (format out "  States: disabled=~A focused=~A pressed=~A loading=~A~%"
                    (getf button-state :disabled)
                    (getf button-state :focused)
                    (getf button-state :pressed)
                    (getf button-state :loading))
            (format out "  Action: ~A~%" (getf button-state :action))
            (format out "  Hotkey: ~A~A~%"
                    (getf button-state :hotkey)
                    (if (getf button-state :hotkey-modifiers)
                        (format nil " (~{~A~^+~})" (getf button-state :hotkey-modifiers))
                        ""))
            (format out "  Accessibility: ~A~%" (button-accessibility-check button-state)))))
    (when stream
      (write-string description stream))
    description))
