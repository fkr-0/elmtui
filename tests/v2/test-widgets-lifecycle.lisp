;;;===============================================================
;;; File: tests/v2/test-widgets-lifecycle.lisp
;;; FiveAM Unit Tests for v2 Widget Lifecycle and Integration
;;;===============================================================

(uiop:define-package :elmtui-test-widgets-lifecycle
  (:use :cl :fiveam)
  (:import-from :elmtui.state
                #:make-application-state
                #:state-ref
                #:set-state
                #:with-transaction)
  (:import-from :elmtui.ui.widgets)  ; Import all v2 widgets
  (:import-from :elmtui.ui.widgets.button
                #:button-model
                #:make-button-model
                #:init-button
                #:update-button
                #:view-button)
  (:import-from :elmtui.ui.widgets.label
                #:label-model
                #:make-label-model
                #:init-label
                #:view-label)
  (:import-from :elmtui.ui.widgets.textinput
                #:textinput-model
                #:make-textinput-model
                #:init-textinput
                #:update-textinput
                #:view-textinput)
  (:import-from :elmtui.ui.widgets.utils
                #:widget-focused-p)
  (:import-from :elmtui.view.styled
                #:make-styled-node
                #:styled-ui-node
                #:ui-node-type
                #:ui-node-props
                #:ui-node-children)
  (:export :run-elmtui-test-widgets-lifecycle))

(in-package :elmtui-test-widgets-lifecycle)

(def-suite elmtui-test-widgets-lifecycle-suite
  :description "Unit tests for v2 Widget Lifecycle and Integration")
(in-suite elmtui-test-widgets-lifecycle-suite)

;;; --- Button Widget Lifecycle Tests ---

(test button-lifecycle
  "Test complete lifecycle of a button widget: init, update, view"
  (let* ((app-state (make-application-state))
         (widget-id :test-button)
         (on-click-msg :button-clicked)
         (messages '())
         (dispatch-fn (lambda (msg) (push msg messages))))
    
    ;; 1. Initialize button
    (multiple-value-bind (model cmds)
        (init-button widget-id :label "Test Button" :on-click-msg on-click-msg)
      
      ;; Check model was created correctly
      (is (button-model-p model))
      (is (eq (button-model-id model) widget-id))
      (is (equal (button-model-label model) "Test Button"))
      (is (eq (button-model-on-click-msg model) on-click-msg))
      (is (not (button-model-disabled model)))
      
      ;; No initial commands expected
      (is (null cmds))
      
      ;; Add model to app state
      (with-transaction (app-state)
        (set-state app-state widget-id model))
      
      ;; 2. Test rendering
      (let ((view (view-button app-state :widget-id widget-id)))
        ;; Verify view structure
        (is (styled-ui-node-p view))
        (is (getf (ui-node-props view) :focusable))
        (is (equal (getf (ui-node-props view) :id) widget-id))
        
        ;; Find label text
        (let ((label-node (first (ui-node-children view))))
          (is (equal (getf (ui-node-props label-node) :value) "Test Button")))
        
        ;; 3. Test update on click
        (let ((on-click-handler (getf (ui-node-props view) :on-click)))
          (is (functionp on-click-handler))
          
          ;; Simulate click
          (funcall on-click-handler nil)
          
          ;; Check that dispatch was called with the correct message
          (is (equal (first messages) on-click-msg)))))))

;;; --- TextInput Widget Lifecycle Tests ---

(test textinput-lifecycle
  "Test complete lifecycle of a textinput widget: init, update, view"
  (let* ((app-state (make-application-state))
         (widget-id :test-input)
         (messages '())
         (dispatch-fn (lambda (msg) (push msg messages))))
    
    ;; 1. Initialize textinput
    (multiple-value-bind (model cmds)
        (init-textinput widget-id :initial-value "Initial" :placeholder "Enter text...")
      
      ;; Check model was created correctly
      (is (textinput-model-p model))
      (is (eq (textinput-model-id model) widget-id))
      (is (equal (textinput-model-value model) "Initial"))
      (is (equal (textinput-model-placeholder model) "Enter text..."))
      
      ;; No initial commands expected
      (is (null cmds))
      
      ;; Add model to app state
      (with-transaction (app-state)
        (set-state app-state widget-id model))
      
      ;; 2. Test rendering
      (let ((view (view-textinput app-state :widget-id widget-id)))
        ;; Verify view structure
        (is (styled-ui-node-p view))
        (is (getf (ui-node-props view) :focusable))
        (is (equal (getf (ui-node-props view) :id) widget-id))
        (is (equal (getf (ui-node-props view) :value) "Initial"))
        (is (equal (getf (ui-node-props view) :placeholder) "Enter text..."))
        
        ;; 3. Test update on text change
        (let ((on-change-handler (getf (ui-node-props view) :on-change)))
          (is (functionp on-change-handler))
          
          ;; Simulate text change
          (funcall on-change-handler "Updated Value")
          
          ;; Check that dispatch was called with the correct message
          (is (listp (first messages)))
          (is (eq (first (first messages)) :textinput-change))
          (is (eq (getf (rest (first messages)) :widget-id) widget-id))
          (is (equal (getf (rest (first messages)) :value) "Updated Value"))
          
          ;; 4. Process the update
          (let ((update-msg (first messages)))
            (multiple-value-bind (changes cmds)
                (update-textinput update-msg model)
              
              ;; Check changes include updated value
              (is (equal (getf changes :value) "Updated Value"))
              (is (null cmds)) ; No commands expected
              
              ;; Apply changes to model
              (let ((updated-model (make-textinput-model 
                                    :id widget-id
                                    :value (getf changes :value)
                                    :placeholder (textinput-model-placeholder model)
                                    :disabled (textinput-model-disabled model)
                                    :is-focused (textinput-model-is-focused model)
                                    :on-change (textinput-model-on-change model))))
                
                ;; Update state
                (with-transaction (app-state)
                  (set-state app-state widget-id updated-model))
                
                ;; 5. Verify updated rendering
                (let ((updated-view (view-textinput app-state :widget-id widget-id)))
                  (is (equal (getf (ui-node-props updated-view) :value) "Updated Value")))))))))))

;;; --- Focus Management Tests ---

(test widget-focus-management
  "Test focus management with v2 widgets"
  (let* ((app-state (make-application-state))
         (button-id :test-button)
         (input-id :test-input))
    
    ;; Initialize widgets
    (multiple-value-bind (button-model _)
        (init-button button-id :label "Test Button")
      (declare (ignore _))
      
      (multiple-value-bind (input-model _)
          (init-textinput input-id :initial-value "")
        (declare (ignore _))
        
        ;; Add models to app state
        (with-transaction (app-state)
          (set-state app-state button-id button-model)
          (set-state app-state input-id input-model)
          (set-state app-state :current-focus-id button-id))
        
        ;; Verify focus state
        (is (eq (get-current-focus app-state) button-id))
        (is (widget-focused-p app-state button-id))
        (is (not (widget-focused-p app-state input-id)))
        
        ;; Check that focus is reflected in views
        (let ((button-view (view-button app-state :widget-id button-id))
              (input-view (view-textinput app-state :widget-id input-id)))
          
          ;; Button should have focused class
          (is (search "focused" (getf (ui-node-props button-view) :class)))
          
          ;; TextInput should not have focused class
          (is (not (search "focused" (getf (ui-node-props input-view) :class))))
          
          ;; Change focus
          (with-transaction (app-state)
            (set-state app-state :current-focus-id input-id))
          
          ;; Verify updated focus state
          (is (eq (get-current-focus app-state) input-id))
          (is (not (widget-focused-p app-state button-id)))
          (is (widget-focused-p app-state input-id))
          
          ;; Check that focus change is reflected in views
          (let ((button-view-2 (view-button app-state :widget-id button-id))
                (input-view-2 (view-textinput app-state :widget-id input-id)))
            
            ;; Button should not have focused class
            (is (not (search "focused" (getf (ui-node-props button-view-2) :class))))
            
            ;; TextInput should have focused class
            (is (search "focused" (getf (ui-node-props input-view-2) :class)))))))))

;;; --- Label Widget Tests ---

(test label-widget
  "Test label widget initialization and view"
  (let* ((app-state (make-application-state))
         (widget-id :test-label))
    
    ;; Initialize label
    (multiple-value-bind (model cmds)
        (init-label widget-id :text "Hello World")
      
      ;; Check model was created correctly
      (is (label-model-p model))
      (is (eq (label-model-id model) widget-id))
      (is (equal (label-model-text model) "Hello World"))
      
      ;; No initial commands expected
      (is (null cmds))
      
      ;; Add model to app state
      (with-transaction (app-state)
        (set-state app-state widget-id model))
      
      ;; Test rendering
      (let ((view (view-label app-state :widget-id widget-id)))
        ;; Verify view structure
        (is (styled-ui-node-p view))
        (is (not (getf (ui-node-props view) :focusable))) ; Labels shouldn't be focusable
        (is (equal (getf (ui-node-props view) :id) widget-id))
        (is (equal (getf (ui-node-props view) :value) "Hello World"))))))

;;; --- Combined Widget Form Tests ---

(test form-with-multiple-widgets
  "Test a form with multiple widgets working together"
  (let* ((app-state (make-application-state))
         (messages '())
         (dispatch-fn (lambda (msg) (push msg messages)))
         (username-id :username-input)
         (password-id :password-input)
         (submit-id :submit-button)
         (status-id :status-label))
    
    ;; Initialize form elements
    (multiple-value-bind (username-model _)
        (init-textinput username-id :placeholder "Username")
      (declare (ignore _))
      
      (multiple-value-bind (password-model _)
          (init-textinput password-id :placeholder "Password")
        (declare (ignore _))
        
        (multiple-value-bind (submit-model _)
            (init-button submit-id :label "Log In" :on-click-msg '(:form-submit))
          (declare (ignore _))
          
          (multiple-value-bind (status-model _)
              (init-label status-id :text "Please log in")
            (declare (ignore _))
            
            ;; Add models to app state
            (with-transaction (app-state)
              (set-state app-state username-id username-model)
              (set-state app-state password-id password-model)
              (set-state app-state submit-id submit-model)
              (set-state app-state status-id status-model)
              (set-state app-state :current-focus-id username-id))
            
            ;; Create form view (could be done with DSL in real app)
            (let* ((username-view (view-textinput app-state :widget-id username-id))
                   (password-view (view-textinput app-state :widget-id password-id))
                   (submit-view (view-button app-state :widget-id submit-id))
                   (status-view (view-label app-state :widget-id status-id))
                   (form-view (make-styled-node
                               :type :form
                               :props `(:id :login-form :class "form")
                               :children (list username-view password-view submit-view status-view))))
              
              ;; Verify initial form structure
              (is (= (length (ui-node-children form-view)) 4))
              (is (eq (get-current-focus app-state) username-id))
              
              ;; Simulate entering username
              (let ((username-change (getf (ui-node-props username-view) :on-change)))
                (funcall username-change "testuser")
                
                ;; Process username change
                (let ((change-msg (first messages)))
                  (multiple-value-bind (changes _)
                      (update-textinput change-msg (state-ref app-state username-id))
                    (declare (ignore _))
                    
                    ;; Apply changes
                    (with-transaction (app-state)
                      (set-state app-state username-id 
                                 (make-textinput-model
                                  :id username-id
                                  :value (getf changes :value)
                                  :placeholder "Username")))
                    
                    ;; Verify username was updated
                    (is (equal 
                         (textinput-model-value (state-ref app-state username-id))
                         "testuser"))
                    
                    ;; Change focus to password field
                    (with-transaction (app-state)
                      (set-state app-state :current-focus-id password-id))
                    
                    ;; Simulate entering password
                    (let* ((password-view-2 (view-textinput app-state :widget-id password-id))
                           (password-change (getf (ui-node-props password-view-2) :on-change)))
                      (funcall password-change "secret")
                      
                      ;; Process password change
                      (let ((change-msg (first messages)))
                        (multiple-value-bind (changes _)
                            (update-textinput change-msg (state-ref app-state password-id))
                          (declare (ignore _))
                          
                          ;; Apply changes
                          (with-transaction (app-state)
                            (set-state app-state password-id 
                                       (make-textinput-model
                                        :id password-id
                                        :value (getf changes :value)
                                        :placeholder "Password")))
                          
                          ;; Verify password was updated
                          (is (equal 
                               (textinput-model-value (state-ref app-state password-id))
                               "secret"))
                          
                          ;; Change focus to submit button
                          (with-transaction (app-state)
                            (set-state app-state :current-focus-id submit-id))
                          
                          ;; Simulate clicking submit button
                          (let* ((submit-view-2 (view-button app-state :widget-id submit-id))
                                 (submit-click (getf (ui-node-props submit-view-2) :on-click)))
                            (funcall submit-click nil)
                            
                            ;; Check that form submit message was dispatched
                            (is (equal (first messages) '(:form-submit)))))))))))))))))

(defun run-elmtui-test-widgets-lifecycle ()
  (fiveam:run! 'elmtui-test-widgets-lifecycle-suite))
