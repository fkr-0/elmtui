;; Example using the standardized widget pattern and enhanced DSL
(uiop:define-package :elmtui.examples.standardized-widgets
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
                ;; ListBox widget
                #:view-listbox
                #:init-listbox
                #:update-listbox
                #:msg-listbox-select-index)
  (:import-from :elmtui.runtime
                #:def-elm-app
                #:run-app))
(in-package :elmtui.examples.standardized-widgets)

;;;-----------------------------------------------------------------------------
;;; Model
;;;-----------------------------------------------------------------------------

(defun init-widgets-demo ()
  "Initialize the standardized widgets demo application."
  (let ((app-state (make-application-state)))
    ;; Initialize counter value in the app-state
    (setf (state-ref app-state 'counter) 0)
    (setf (state-ref app-state 'name) "")
    (setf (state-ref app-state 'selected-item) nil)
    (setf (state-ref app-state 'current-tab) 'counter)
    
    ;; Initialize button models
    (multiple-value-bind (inc-btn _)
        (init-button "inc-button" :label "+" :on-click :increment)
      (setf (state-ref app-state "inc-button") inc-btn))
    
    (multiple-value-bind (dec-btn _)
        (init-button "dec-button" :label "-" :on-click :decrement)
      (setf (state-ref app-state "dec-button") dec-btn))
    
    (multiple-value-bind (reset-btn _)
        (init-button "reset-button" :label "Reset" :on-click :reset)
      (setf (state-ref app-state "reset-button") reset-btn))

    ;; Initialize tab buttons
    (multiple-value-bind (counter-tab _)
        (init-button "counter-tab" :label "Counter" :on-click '(:switch-tab :tab counter))
      (setf (state-ref app-state "counter-tab") counter-tab))
    
    (multiple-value-bind (form-tab _)
        (init-button "form-tab" :label "Form" :on-click '(:switch-tab :tab form))
      (setf (state-ref app-state "form-tab") form-tab))
      
    (multiple-value-bind (list-tab _)
        (init-button "list-tab" :label "List" :on-click '(:switch-tab :tab list))
      (setf (state-ref app-state "list-tab") list-tab))
    
    ;; Initialize text input
    (multiple-value-bind (name-input _)
        (init-textinput "name-input" :placeholder "Enter your name" 
                         :on-change '(:update-name))
      (setf (state-ref app-state "name-input") name-input))

    ;; Initialize label for name field
    (multiple-value-bind (name-label _)
        (init-label "name-label" :text "Name:" :for "name-input")
      (setf (state-ref app-state "name-label") name-label))
    
    ;; Initialize listbox with sample items
    (multiple-value-bind (items-listbox _)
        (init-listbox "items-listbox" 
                       :items '("Apple" "Banana" "Cherry" "Date" "Elderberry"
                               "Fig" "Grape" "Honeydew" "Kiwi" "Lemon")
                       :height 5
                       :on-select '(:select-item))
      (setf (state-ref app-state "items-listbox") items-listbox))
    
    ;; Return initialized app-state and no commands
    (values app-state nil)))

;;;-----------------------------------------------------------------------------
;;; Update
;;;-----------------------------------------------------------------------------

(defun update-widgets-demo (msg app-state)
  "Update the widgets demo application based on messages."
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
         
         ;; Name input updates
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
         
         ;; List selection
         (:select-item
          (let ((selected-index (getf (rest msg) :index))
                (selected-item (getf (rest msg) :item)))
            (update-state app-state 'selected-item selected-item)
            
            ;; Update the listbox model
            (let ((listbox-model (state-ref app-state "items-listbox")))
              (when listbox-model
                (multiple-value-bind (updated-listbox listbox-commands)
                    (update-listbox (list msg-listbox-select-index :index selected-index) 
                                     listbox-model)
                  ;; Update the listbox in app-state
                  (setf (state-ref app-state "items-listbox") updated-listbox)
                  ;; Collect commands
                  (setf commands (append listbox-commands commands)))))))
         
         ;; Handle widget update delegations
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

(define-view view-counter-example (app-state dispatch)
  (:div :class "counter-app"
        :padding 1
        :border-style :single
        :border-color :blue
        :width 40
        :height 10
    
    ;; Title
    (:h1 :class "app-title" "Counter Example")
    
    ;; Counter display
    (:div :class "counter-display"
          :margin-top 1
          :margin-bottom 1
          :padding 1
          :border-style :single
          :width 20
      (format nil "Count: ~A" (state-ref app-state 'counter)))
    
    ;; Buttons
    (:div :class "button-row"
          :display :flex
          :flex-direction :row
          :justify-content :space-between
          :width 30
          :margin-top 1
      
      ;; Increment button
      (:button :widget-id "inc-button"
               :on-click :increment)
      
      ;; Decrement button
      (:button :widget-id "dec-button"
               :on-click :decrement)
      
      ;; Reset button
      (:button :widget-id "reset-button"
               :on-click :reset))))

;;;-----------------------------------------------------------------------------
;;; App Definition and Runner
;;;-----------------------------------------------------------------------------

(def-elm-app counter-example-app
  :init #'init-counter-example
  :update #'update-counter-example
  :view #'view-counter-example)

(defun run-counter-example ()
  "Run the counter example application."
  (run-app :app-name 'counter-example-app))
