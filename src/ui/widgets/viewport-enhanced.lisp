;;;===============================================================
;;; File: src/ui/widgets/viewport-enhanced.lisp
;;; Enhanced Viewport Widget with DSL Integration and Contracts
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.viewport-enhanced
  (:use :cl :alexandria)
  (:import-from :elmtui.view.dsl.base 
                #:validate-base-dsl #:expand-base-dsl #:make-dsl-element)
  (:import-from :elmtui.state.model
                #:defmodel-contracted #:defpatch #:deftransaction #:make-state-patch)
  (:import-from :elmtui.contracts
                #:defupdate-hybrid #:defview)
  (:import-from :elmtui.ui.api 
                #:component #:id-from-path #:get-path)
  (:import-from :elmtui.app.api
                #:get-component-instance #:destroy-component-state)
  (:export 
   #:viewport-enhanced #:make-viewport-enhanced
   ;; Viewport state model
   #:viewport-state #:make-viewport-state #:validate-viewport-state
   ;; Viewport operations
   #:scroll-viewport #:resize-viewport #:set-viewport-child))

(in-package :elmtui.ui.widgets.viewport-enhanced)

;;;--------------------------------------------------------------
;;; Enhanced Viewport State Model
;;;--------------------------------------------------------------

(defmodel-contracted viewport-state
  ((width 80 :type integer :required t 
          :validator (lambda (v) (and (integerp v) (> v 0))))
   (height 24 :type integer :required t
           :validator (lambda (v) (and (integerp v) (> v 0))))
   (offset-x 0 :type integer 
             :validator (lambda (v) (and (integerp v) (>= v 0))))
   (offset-y 0 :type integer
             :validator (lambda (v) (and (integerp v) (>= v 0))))
   (scroll-x 0 :type integer
             :validator (lambda (v) (and (integerp v) (>= v 0))))
   (scroll-y 0 :type integer
             :validator (lambda (v) (and (integerp v) (>= v 0))))
   (child-id nil :type (or null keyword))
   (child-dsl nil :type (or null list))
   (visible t :type boolean)
   (clipping t :type boolean :documentation "Whether content is clipped to viewport bounds"))
  
  :validation (lambda (state)
                ;; Custom validation: if child-id is present, child-dsl should be too
                (when (getf state :child-id)
                  (unless (getf state :child-dsl)
                    (warn "Viewport has child-id but no child-dsl"))))
  
  :transactions
  ((scroll-to-position (state x y)
     "Transaction to scroll viewport to specific position"
     (list (make-state-patch :path '(:scroll-x) :value x :operation :set)
           (make-state-patch :path '(:scroll-y) :value y :operation :set)))
   
   (resize-viewport-transaction (state new-width new-height)
     "Transaction to resize viewport"
     (list (make-state-patch :path '(:width) :value new-width :operation :set)
           (make-state-patch :path '(:height) :value new-height :operation :set)))
   
   (set-child-transaction (state child-id child-dsl)
     "Transaction to set viewport child"
     (list (make-state-patch :path '(:child-id) :value child-id :operation :set)
           (make-state-patch :path '(:child-dsl) :value child-dsl :operation :set))))
  
  :documentation "Enhanced viewport state model with validation and transactions"
  :export-accessors t)

;;;--------------------------------------------------------------
;;; Viewport Patch Operations
;;;--------------------------------------------------------------

(defpatch scroll-viewport (state direction amount)
  "Scrolls viewport in the specified direction"
  (case direction
    (:up (make-state-patch :path '(:scroll-y) 
                          :value (lambda (current) (max 0 (- current amount)))
                          :operation :update))
    (:down (make-state-patch :path '(:scroll-y)
                            :value (lambda (current) (+ current amount))
                            :operation :update))
    (:left (make-state-patch :path '(:scroll-x)
                            :value (lambda (current) (max 0 (- current amount)))
                            :operation :update))
    (:right (make-state-patch :path '(:scroll-x)
                             :value (lambda (current) (+ current amount))
                             :operation :update))
    (t (error "Invalid scroll direction: ~A" direction))))

(defpatch resize-viewport (state new-width new-height)
  "Resizes viewport to new dimensions"
  (list (make-state-patch :path '(:width) :value new-width :operation :set
                         :validator (lambda (v) (and (integerp v) (> v 0))))
        (make-state-patch :path '(:height) :value new-height :operation :set
                         :validator (lambda (v) (and (integerp v) (> v 0))))))

(defpatch set-viewport-child (state child-dsl)
  "Sets the child content of the viewport"
  (let ((validated-dsl (when child-dsl (validate-base-dsl child-dsl))))
    (make-state-patch :path '(:child-dsl) :value validated-dsl :operation :set)))

;;;--------------------------------------------------------------
;;; Enhanced Viewport Component
;;;--------------------------------------------------------------

(defclass viewport-enhanced (component)
  ()
  (:documentation "Enhanced viewport component with DSL integration and contracts"))

(defun make-viewport-enhanced (&key id)
  "Creates a new enhanced viewport instance"
  (make-instance 'viewport-enhanced :id id))

;;;--------------------------------------------------------------
;;; Contract-Enforced Update Function
;;;--------------------------------------------------------------

(defupdate-hybrid viewport-enhanced-update (model message) 
    :message-type nil :prefer-typed nil
  "Enhanced viewport update function with contract enforcement"
  
  (let ((msg-type (if (listp message) (first message) message))
        (msg-data (when (listp message) (rest message))))
    
    (case msg-type
      ;; Scrolling operations
      ((:scroll-to :scroll)
       (let ((x (if (listp message) (getf msg-data :x) 0))
             (y (if (listp message) (getf msg-data :y) 0)))
         (multiple-value-bind (new-state transaction)
             (scroll-to-position model x y)
           (values new-state nil))))
      
      (:scroll-by
       (let ((direction (getf msg-data :direction :down))
             (amount (getf msg-data :amount 1)))
         (let ((patches (scroll-viewport model direction amount)))
           (values (apply-state-patches model (list patches)) nil))))
      
      ;; Resize operations
      ((:resize :set-dimensions)
       (let ((width (getf msg-data :width (getf model :width)))
             (height (getf msg-data :height (getf model :height))))
         (multiple-value-bind (new-state transaction)
             (resize-viewport-transaction model width height)
           (values new-state nil))))
      
      ;; Child management
      (:set-child
       (let ((child-dsl (getf msg-data :dsl)))
         (let ((patches (set-viewport-child model child-dsl)))
           (values (apply-state-patches model (list patches)) nil))))
      
      ;; Visibility toggle
      (:set-visible
       (let ((visible (getf msg-data :visible t)))
         (values (list* :visible visible model) nil)))
      
      ;; Clipping toggle
      (:set-clipping
       (let ((clipping (getf msg-data :clipping t)))
         (values (list* :clipping clipping model) nil)))
      
      ;; Default case
      (t 
       (values nil nil)))))

;;;--------------------------------------------------------------
;;; Contract-Enforced View Function
;;;--------------------------------------------------------------

(defview viewport-enhanced-view (model)
  "Enhanced viewport view function with base DSL output"
  
  (let* ((width (getf model :width 80))
         (height (getf model :height 24))
         (offset-x (getf model :offset-x 0))
         (offset-y (getf model :offset-y 0))
         (scroll-x (getf model :scroll-x 0))
         (scroll-y (getf model :scroll-y 0))
         (child-dsl (getf model :child-dsl))
         (visible (getf model :visible t))
         (clipping (getf model :clipping t))
         (component-id (getf model :id :viewport)))
    
    ;; Build viewport DSL using base DSL system
    (let ((viewport-dsl
           `(:container
             :id ,component-id
             :class (:viewport)
             :style (:width ,width
                    :height ,height
                    :offset-x ,offset-x
                    :offset-y ,offset-y
                    :scroll-x ,scroll-x
                    :scroll-y ,scroll-y
                    :overflow ,(if clipping :hidden :visible)
                    :display ,(if visible :block :none)
                    :position :relative)
             :children ,(when child-dsl
                         (list (expand-base-dsl child-dsl))))))
      
      ;; Validate and return the DSL
      (validate-base-dsl viewport-dsl)
      viewport-dsl)))

;;;--------------------------------------------------------------
;;; Legacy API Compatibility Layer
;;;--------------------------------------------------------------

;; Enhanced viewport class that extends the original interface
(defclass viewport (viewport-enhanced)
  ()
  (:documentation "Legacy viewport compatibility class"))

(defun make-viewport (&key id)
  "Legacy viewport constructor"
  (make-viewport-enhanced :id id))

;; Legacy init method with enhanced state management
(defmethod init ((component viewport-enhanced) &key id-path initial-width initial-height 
                                                   initial-offset-x initial-offset-y 
                                                   initial-child-spec dsl &allow-other-keys)
  "Enhanced init method with state model integration"
  (let ((component-id (id-from-path id-path))
        (viewport-state (make-viewport-state 
                        :width (or initial-width 80)
                        :height (or initial-height 24)
                        :offset-x (or initial-offset-x 0)
                        :offset-y (or initial-offset-y 0)
                        :child-dsl (when initial-child-spec
                                    (validate-base-dsl initial-child-spec)))))
    
    (values component
            (list (list id-path 
                       (list* :type (type-of component)
                             :id component-id
                             :state viewport-state)))
            nil)))

;; Legacy update method with contract integration
(defmethod update ((component viewport-enhanced) state message &key id-path)
  "Enhanced update method with contract enforcement"
  (let* ((current-state (getf (get-path state id-path) :state))
         (patches nil)
         (commands nil))
    
    ;; Use the contract-enforced update function
    (multiple-value-bind (new-state new-commands)
        (viewport-enhanced-update current-state message)
      
      (when new-state
        (push (list (append id-path '(:state)) new-state) patches))
      
      (when new-commands
        (setf commands (append commands new-commands))))
    
    (values patches commands)))

;; Legacy view method with DSL integration
(defmethod view ((component viewport-enhanced) state &key id-path)
  "Enhanced view method with base DSL output"
  (let* ((component-state (getf (get-path state id-path) :state))
         (enhanced-state (list* :id (id-from-path id-path) component-state)))
    
    ;; Use the contract-enforced view function
    (viewport-enhanced-view enhanced-state)))

;;;--------------------------------------------------------------
;;; Viewport Utilities
;;;--------------------------------------------------------------

(defun viewport-bounds (viewport-state)
  "Returns the effective bounds of the viewport"
  (list :left (getf viewport-state :offset-x)
        :top (getf viewport-state :offset-y)
        :right (+ (getf viewport-state :offset-x) (getf viewport-state :width))
        :bottom (+ (getf viewport-state :offset-y) (getf viewport-state :height))))

(defun point-in-viewport-p (viewport-state x y)
  "Checks if a point is within the viewport bounds"
  (let ((bounds (viewport-bounds viewport-state)))
    (and (>= x (getf bounds :left))
         (< x (getf bounds :right))
         (>= y (getf bounds :top))
         (< y (getf bounds :bottom)))))

(defun viewport-scroll-bounds (viewport-state content-width content-height)
  "Calculates the maximum scroll bounds for given content size"
  (list :max-scroll-x (max 0 (- content-width (getf viewport-state :width)))
        :max-scroll-y (max 0 (- content-height (getf viewport-state :height)))))

(defun normalize-scroll-position (viewport-state content-width content-height)
  "Ensures scroll position is within valid bounds"
  (let* ((bounds (viewport-scroll-bounds viewport-state content-width content-height))
         (max-x (getf bounds :max-scroll-x))
         (max-y (getf bounds :max-scroll-y))
         (current-x (getf viewport-state :scroll-x))
         (current-y (getf viewport-state :scroll-y)))
    
    (list :scroll-x (max 0 (min current-x max-x))
          :scroll-y (max 0 (min current-y max-y)))))

;;;--------------------------------------------------------------
;;; Development and Debugging Support
;;;--------------------------------------------------------------

(defun describe-viewport-state (viewport-state)
  "Provides detailed information about viewport state"
  (format t "~&Viewport State:~%")
  (format t "  Dimensions: ~Ax~A~%" 
          (getf viewport-state :width) 
          (getf viewport-state :height))
  (format t "  Position: (~A, ~A)~%" 
          (getf viewport-state :offset-x) 
          (getf viewport-state :offset-y))
  (format t "  Scroll: (~A, ~A)~%" 
          (getf viewport-state :scroll-x) 
          (getf viewport-state :scroll-y))
  (format t "  Child ID: ~A~%" (getf viewport-state :child-id))
  (format t "  Visible: ~A~%" (getf viewport-state :visible))
  (format t "  Clipping: ~A~%" (getf viewport-state :clipping)))

(defun validate-viewport-hierarchy (viewport-state)
  "Validates the viewport state and its child hierarchy"
  (validate-viewport-state viewport-state)
  
  (let ((child-dsl (getf viewport-state :child-dsl)))
    (when child-dsl
      (validate-base-dsl child-dsl)))
  
  t)