;;;===============================================================
;;; File: examples/comprehensive-widgets-demo.lisp
;;; A comprehensive demo of all standardized v2 widgets
;;;===============================================================
(uiop:define-package :elmtui.examples.comprehensive-widgets
  (:use :cl)
  (:import-from :elmtui.state
                #:application-state #:make-application-state
                #:state-ref #:update-state)
  (:import-from :elmtui.view.dsl #:define-view)
  (:import-from :elmtui.ui.widgets
                ;; Button widget
                #:view-button
                #:init-button
                #:update-button
                ;; Label widget
                #:view-label
                #:init-label
                ;; TextInput widget
                #:view-textinput
                #:init-textinput
                #:update-textinput
                #:msg-textinput-set-value
                #:msg-textinput-key-press
                ;; ListBox widget
                #:view-listbox
                #:init-listbox
                #:update-listbox
                #:msg-listbox-select-index
                #:msg-listbox-set-items)
  (:import-from :elmtui.runtime
                #:def-elm-app
                #:run-app))
(in-package :elmtui.examples.comprehensive-widgets)

;;;-----------------------------------------------------------------------------
;;; Model
;;;-----------------------------------------------------------------------------

(defun init-comprehensive-demo ()
  "Initialize the comprehensive widgets demo application."
  (let ((app-state (make-application-state)))
    ;; Application state
    (setf (state-ref app-state 'counter) 0)
    (setf (state-ref app-state 'name) "")
    (setf (state-ref app-state 'email) "")
    (setf (state-ref app-state 'selected-item) nil)
    (setf (state-ref app-state 'current-tab) 'buttons)
    (setf (state-ref app-state 'form-submitted) nil)
    
    ;; Tab buttons initialization
    (multiple-value-bind (buttons-tab _)
        (init-button "buttons-tab" :label "Buttons" :on-click '(:switch-tab :tab buttons))
      (setf (state-ref app-state "buttons-tab") buttons-tab))
    
    (multiple-value-bind (inputs-tab _)
        (init-button "inputs-tab" :label "Inputs" :on-click '(:switch-tab :tab inputs))
      (setf (state-ref app-state "inputs-tab") inputs-tab))
      
    (multiple-value-bind (list-tab _)
        (init-button "list-tab" :label "Lists" :on-click '(:switch-tab :tab lists))
      (setf (state-ref app-state "list-tab") list-tab))

    (multiple-value-bind (form-tab _)
        (init-button "form-tab" :label "Form" :on-click '(:switch-tab :tab form))
      (setf (state-ref app-state "form-tab") form-tab))
    
    ;; Buttons tab widgets
    (multiple-value-bind (inc-btn _)
        (init-button "inc-button" :label "+" :on-click :increment)
      (setf (state-ref app-state "inc-button") inc-btn))
    
    (multiple-value-bind (dec-btn _)
        (init-button "dec-button" :label "-" :on-click :decrement)
      (setf (state-ref app-state "dec-button") dec-btn))
    
    (multiple-value-bind (reset-btn _)
        (init-button "reset-button" :label "Reset" :on-click :reset)
      (setf (state-ref app-state "reset-button") reset-btn))

    (multiple-value-bind (disabled-btn _)
        (init-button "disabled-button" :label "Disabled" :disabled t)
      (setf (state-ref app-state "disabled-button") disabled-btn))
    
    ;; Inputs tab widgets
    (multiple-value-bind (name-label _)
        (init-label "name-label" :text "Name:" :for "name-input")
      (setf (state-ref app-state "name-label") name-label))

    (multiple-value-bind (name-input _)
        (init-textinput "name-input" :placeholder "Enter your name" 
                          :on-change '(:update-name))
      (setf (state-ref app-state "name-input") name-input))

    (multiple-value-bind (email-label _)
        (init-label "email-label" :text "Email:" :for "email-input")
      (setf (state-ref app-state "email-label") email-label))

    (multiple-value-bind (email-input _)
        (init-textinput "email-input" :placeholder "Enter your email" 
                          :on-change '(:update-email))
      (setf (state-ref app-state "email-input") email-input))

    (multiple-value-bind (disabled-input _)
        (init-textinput "disabled-input" :placeholder "Disabled input" 
                          :disabled t)
      (setf (state-ref app-state "disabled-input") disabled-input))
    
    ;; Lists tab widgets
    (multiple-value-bind (fruit-list-label _)
        (init-label "fruit-list-label" :text "Select a fruit:" :for "fruit-listbox")
      (setf (state-ref app-state "fruit-list-label") fruit-list-label))
    
    (multiple-value-bind (fruit-listbox _)
        (init-listbox "fruit-listbox" 
                        :items '("Apple" "Banana" "Cherry" "Date" "Elderberry"
                                "Fig" "Grape" "Honeydew" "Kiwi" "Lemon")
                        :height 5
                        :on-select '(:select-fruit))
      (setf (state-ref app-state "fruit-listbox") fruit-listbox))

    (multiple-value-bind (color-list-label _)
        (init-label "color-list-label" :text "Select a color:" :for "color-listbox")
      (setf (state-ref app-state "color-list-label") color-list-label))
    
    (multiple-value-bind (color-listbox _)
        (init-listbox "color-listbox" 
                        :items '("Red" "Orange" "Yellow" "Green" "Blue" 
                                "Indigo" "Violet" "Black" "White" "Gray")
                        :height 5
                        :on-select '(:select-color))
      (setf (state-ref app-state "color-listbox") color-listbox))

    ;; Form tab widgets
    (multiple-value-bind (form-name-label _)
        (init-label "form-name-label" :text "Name:" :for "form-name-input")
      (setf (state-ref app-state "form-name-label") form-name-label))

    (multiple-value-bind (form-name-input _)
        (init-textinput "form-name-input" :placeholder "Enter your name" 
                          :on-change '(:form-update-name)
                          :on-submit '(:submit-form))
      (setf (state-ref app-state "form-name-input") form-name-input))

    (multiple-value-bind (form-email-label _)
        (init-label "form-email-label" :text "Email:" :for "form-email-input")
      (setf (state-ref app-state "form-email-label") form-email-label))

    (multiple-value-bind (form-email-input _)
        (init-textinput "form-email-input" :placeholder "Enter your email" 
                          :on-change '(:form-update-email)
                          :on-submit '(:submit-form))
      (setf (state-ref app-state "form-email-input") form-email-input))

    (multiple-value-bind (form-submit-button _)
        (init-button "form-submit-button" :label "Submit" :on-click '(:submit-form))
      (setf (state-ref app-state "form-submit-button") form-submit-button))
    
    ;; Return initialized app-state and no commands
    (values app-state nil)))

;;;-----------------------------------------------------------------------------
;;; Update
;;;-----------------------------------------------------------------------------

(defun update-comprehensive-demo (msg app-state)
  "Update the comprehensive widgets demo application based on messages."
  (let ((commands nil))
    (etypecase msg
      (keyword
       (case msg
         ;; Handle counter operations
         (:increment
          (update-state app-state 'counter (1+ (state-ref app-state 'counter))))
         
         (:decrement
          (update-state app-state 'counter (1- (state-ref app-state 'counter))))
         
         (:reset
          (update-state app-state 'counter 0))
         
         ;; Unknown message type
         (otherwise
          (format t "Unknown message: ~S~%" msg))))
      
      (list
       (case (first msg)
         ;; Tab switching
         (:switch-tab
          (let ((tab (getf (rest msg) :tab)))
            (when tab
              (update-state app-state 'current-tab tab))))
         
         ;; Input field updates
         (:update-name
          (let ((new-value (getf (rest msg) :value)))
            (update-state app-state 'name new-value)
            
            ;; Also update the model
            (let ((input-model (state-ref app-state "name-input")))
              (when input-model
                (multiple-value-bind (updated-input input-commands)
                    (update-textinput (list msg-textinput-set-value :value new-value) 
                                       input-model)
                  ;; Update the input in app-state
                  (setf (state-ref app-state "name-input") updated-input)
                  ;; Collect commands
                  (setf commands (append input-commands commands)))))))

         (:update-email
          (let ((new-value (getf (rest msg) :value)))
            (update-state app-state 'email new-value)
            
            ;; Also update the model
            (let ((input-model (state-ref app-state "email-input")))
              (when input-model
                (multiple-value-bind (updated-input input-commands)
                    (update-textinput (list msg-textinput-set-value :value new-value) 
                                       input-model)
                  ;; Update the input in app-state
                  (setf (state-ref app-state "email-input") updated-input)
                  ;; Collect commands
                  (setf commands (append input-commands commands)))))))

         ;; Form field updates
         (:form-update-name
          (let ((new-value (getf (rest msg) :value)))
            (update-state app-state 'form-name new-value)))

         (:form-update-email
          (let ((new-value (getf (rest msg) :value)))
            (update-state app-state 'form-email new-value)))

         (:submit-form
          (update-state app-state 'form-submitted t))
         
         ;; List selection
         (:select-fruit
          (let ((selected-index (getf (rest msg) :index))
                (selected-item (getf (rest msg) :item)))
            (update-state app-state 'selected-fruit selected-item)
            
            ;; Update the listbox model
            (let ((listbox-model (state-ref app-state "fruit-listbox")))
              (when listbox-model
                (multiple-value-bind (updated-listbox listbox-commands)
                    (update-listbox (list msg-listbox-select-index :index selected-index) 
                                     listbox-model)
                  ;; Update the listbox in app-state
                  (setf (state-ref app-state "fruit-listbox") updated-listbox)
                  ;; Collect commands
                  (setf commands (append listbox-commands commands)))))))

         (:select-color
          (let ((selected-index (getf (rest msg) :index))
                (selected-item (getf (rest msg) :item)))
            (update-state app-state 'selected-color selected-item)
            
            ;; Update the listbox model
            (let ((listbox-model (state-ref app-state "color-listbox")))
              (when listbox-model
                (multiple-value-bind (updated-listbox listbox-commands)
                    (update-listbox (list msg-listbox-select-index :index selected-index) 
                                     listbox-model)
                  ;; Update the listbox in app-state
                  (setf (state-ref app-state "color-listbox") updated-listbox)
                  ;; Collect commands
                  (setf commands (append listbox-commands commands)))))))
         
         ;; Handle generic widget update delegations
         (:update-widget
          (let* ((widget-type (getf (rest msg) :type))
                 (widget-id (getf (rest msg) :id))
                 (widget-msg (getf (rest msg) :msg))
                 (widget-model (state-ref app-state widget-id)))
            (when widget-model
              (multiple-value-bind (updated-widget widget-commands)
                  (case widget-type
                    (:button (update-button widget-msg widget-model))
                    (:textinput (update-textinput widget-msg widget-model))
                    (:listbox (update-listbox widget-msg widget-model))
                    (t (values widget-model nil)))
                ;; Update the widget in app-state
                (setf (state-ref app-state widget-id) updated-widget)
                ;; Collect commands
                (setf commands (append widget-commands commands))))))
         
         ;; Unknown message type
         (otherwise
          (format t "Unknown message: ~S~%" msg)))))
    
    ;; Return updated state and commands
    (values app-state commands)))

;;;-----------------------------------------------------------------------------
;;; View
;;;-----------------------------------------------------------------------------

(define-view view-comprehensive-demo (app-state dispatch)
  (:div :class "widgets-demo"
        :padding 1
        :border-style :single
        :border-color :blue
        :width 70
        :height 25
    
    ;; Title
    (:h1 :class "app-title" "Standardized Widgets Comprehensive Demo")
    
    ;; Tab bar
    (:div :class "tabs"
          :display :flex
          :flex-direction :row
          :margin-bottom 1
          :border-bottom-style :single
          :border-color :gray
          :padding-bottom 1
          :width 68
      
      ;; Tab buttons
      (:button :widget-id "buttons-tab"
               :class (if (eq 'buttons (state-ref app-state 'current-tab)) 
                         "tab tab-active" 
                         "tab"))
      
      (:button :widget-id "inputs-tab"
               :class (if (eq 'inputs (state-ref app-state 'current-tab)) 
                         "tab tab-active" 
                         "tab"))
      
      (:button :widget-id "list-tab"
               :class (if (eq 'lists (state-ref app-state 'current-tab)) 
                         "tab tab-active" 
                         "tab"))
                         
      (:button :widget-id "form-tab"
               :class (if (eq 'form (state-ref app-state 'current-tab)) 
                         "tab tab-active" 
                         "tab")))
    
    ;; Content area - conditionally show different tabs
    (:div :class "content"
          :padding 1
          :border-style :single
          :width 68
          :height 15
    
      ;; Buttons Tab
      (when (eq 'buttons (state-ref app-state 'current-tab))
        (:div :class "buttons-tab"
           
          ;; Counter display
          (:div :class "counter-display"
                :margin-top 1
                :margin-bottom 1
                :padding 1
                :border-style :single
                :width 20
            (format nil "Count: ~A" (state-ref app-state 'counter)))
          
          ;; Standard Buttons Row
          (:div :class "button-row"
                :display :flex
                :flex-direction :row
                :justify-content :space-between
                :width 30
                :margin-top 1
                :margin-bottom 3
            
            ;; Using the standardized V2 button widgets
            (:button :widget-id "inc-button"
                    :on-click :increment)
            
            (:button :widget-id "dec-button"
                    :on-click :decrement)
            
            (:button :widget-id "reset-button"
                    :on-click :reset))
                    
          ;; Button Variations Row
          (:div :class "button-variations"
                :display :flex
                :flex-direction :column
                :gap 1
                
            (:h3 "Button Variations")
            
            (:div :class "button-row"
                  :display :flex
                  :flex-direction :row
                  :justify-content :space-between
                  :width 50
                  :margin-top 1
              
              ;; Button with tooltip
              (:button :widget-id "tooltip-button"
                      :label "With Tooltip"
                      :tooltip "This is a tooltip example"
                      :on-click '(:message "Tooltip button clicked"))
              
              ;; Disabled button
              (:button :widget-id "disabled-button")
              
              ;; Button with custom class
              (:button :widget-id "custom-button"
                      :label "Custom Style"
                      :class "button button-primary"
                      :on-click '(:message "Custom button clicked"))))))
      
      ;; Inputs Tab
      (when (eq 'inputs (state-ref app-state 'current-tab))
        (:div :class "inputs-tab"
          
          ;; Text Input Fields
          (:div :class "form-section"
                :margin-top 1
                :margin-bottom 2
            
            (:h3 "Text Input Fields")
            
            ;; Name Input Row with Label
            (:div :class "form-row"
                  :margin-top 1
                  :margin-bottom 1
                  :display :flex
                  :flex-direction :row
                  :align-items :center
              
              ;; Using the standardized V2 label widget
              (:label :widget-id "name-label"
                     :width 10)
              
              ;; Using the standardized V2 text input widget
              (:textinput :widget-id "name-input"
                        :width 30)))
            
            ;; Email Input Row with Label
            (:div :class "form-row"
                  :margin-top 1
                  :margin-bottom 1
                  :display :flex
                  :flex-direction :row
                  :align-items :center
              
              (:label :widget-id "email-label"
                     :width 10)
              
              (:textinput :widget-id "email-input"
                        :width 30))
            
            ;; Disabled input example
            (:div :class "form-row"
                  :margin-top 1
                  :margin-bottom 1
                  :display :flex
                  :flex-direction :row
                  :align-items :center
              
              (:label :text "Disabled:"
                     :width 10)
              
              (:textinput :widget-id "disabled-input"
                        :width 30))
            
            ;; Output display for inputs
            (:div :class "inputs-output"
                  :margin-top 2
                  :padding 1
                  :border-style :single
                  :width 50
                  :display (if (and (string= "" (state-ref app-state 'name))
                                   (string= "" (state-ref app-state 'email)))
                              :none :block)
              
              (:div (format nil "Name: ~A" (state-ref app-state 'name)))
              (:div (format nil "Email: ~A" (state-ref app-state 'email))))))
      
      ;; Lists Tab
      (when (eq 'lists (state-ref app-state 'current-tab))
        (:div :class "lists-tab"
          
          ;; Listbox examples
          (:div :class "listbox-section"
                :margin-top 1
                :margin-bottom 2
            
            (:h3 "List Selection Widgets")
            
            ;; Two listboxes side by side
            (:div :class "listbox-container"
                  :display :flex
                  :flex-direction :row
                  :justify-content :space-between
                  :width 60
                  :margin-top 1
              
              ;; Fruit listbox
              (:div :class "listbox-group"
                    :width 28
                
                (:label :widget-id "fruit-list-label")
                (:listbox :widget-id "fruit-listbox"
                         :width 25))
              
              ;; Color listbox
              (:div :class "listbox-group"
                    :width 28
                
                (:label :widget-id "color-list-label")
                (:listbox :widget-id "color-listbox"
                         :width 25))))
            
            ;; Display selections
            (:div :class "selections-display"
                  :margin-top 2
                  :padding 1
                  :border-style :single
                  :width 50
              
              (:div (format nil "Selected Fruit: ~A" 
                           (or (state-ref app-state 'selected-fruit) "None")))
              (:div (format nil "Selected Color: ~A" 
                           (or (state-ref app-state 'selected-color) "None"))))))
      
      ;; Form Tab - combines multiple widgets
      (when (eq 'form (state-ref app-state 'current-tab))
        (:div :class "form-tab"
          
          (if (state-ref app-state 'form-submitted)
              ;; Form submitted view
              (:div :class "form-success"
                    :margin-top 2
                    :padding 1
                    :border-style :single
                    :border-color :green
                    :width 50
                    :height 5
                
                (:h3 :class "success-title" "Form Submitted Successfully!")
                (:div (format nil "Name: ~A" (state-ref app-state 'form-name)))
                (:div (format nil "Email: ~A" (state-ref app-state 'form-email))))
              
              ;; Form input view
              (:div :class "form-inputs"
                    :margin-top 1
                
                (:h3 "Contact Form")
                
                ;; Name Input Row with Label
                (:div :class "form-row"
                      :margin-top 1
                      :margin-bottom 1
                      :display :flex
                      :flex-direction :row
                      :align-items :center
                  
                  (:label :widget-id "form-name-label"
                         :width 10)
                  
                  (:textinput :widget-id "form-name-input"
                            :width 40))
                
                ;; Email Input Row with Label
                (:div :class "form-row"
                      :margin-top 1
                      :margin-bottom 2
                      :display :flex
                      :flex-direction :row
                      :align-items :center
                  
                  (:label :widget-id "form-email-label"
                         :width 10)
                  
                  (:textinput :widget-id "form-email-input"
                            :width 40))
                
                ;; Submit Button
                (:div :class "form-actions"
                      :margin-top 2
                  
                  (:button :widget-id "form-submit-button"
                          :class "button button-primary")))))))
    
    ;; Status bar
    (:div :class "status-bar"
          :margin-top 1
          :padding-top 1
          :border-top-style :single
          :border-color :gray
          :width 68
      (format nil "Current tab: ~A" (state-ref app-state 'current-tab)))))

;;;-----------------------------------------------------------------------------
;;; App Definition and Runner
;;;-----------------------------------------------------------------------------

(def-elm-app comprehensive-widgets-demo
  :init #'init-comprehensive-demo
  :update #'update-comprehensive-demo
  :view #'view-comprehensive-demo)

(defun run-comprehensive-widgets-demo ()
  "Run the comprehensive widgets demo application."
  (run-app :app-name 'comprehensive-widgets-demo))
