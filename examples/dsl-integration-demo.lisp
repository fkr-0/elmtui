;;;===============================================================
;;; File: examples/dsl-integration-demo.lisp
;;; Comprehensive demonstration of all DSL layers working together
;;; Shows Base DSL, Component DSL, Application DSL, and State Model integration
;;;===============================================================
(uiop:define-package :elmtui.examples.dsl-integration
  (:use :cl :alexandria)
  (:import-from :elmtui.view.dsl.base 
                #:validate-base-dsl #:expand-base-dsl #:make-dsl-element)
  (:import-from :elmtui.state.model 
                #:defmodel-contracted #:defpatch #:deftransaction #:make-state-patch)
  (:import-from :elmtui.contracts 
                #:defupdate-hybrid #:defview #:defsubscriptions #:enable-contract-debugging)
  (:import-from :elmtui.state.msg #:defmsg)
  (:import-from :elmtui.ui.defcomponent #:defcomponent)
  (:import-from :elmtui.app #:defapplication)
  (:export 
   #:run-dsl-integration-demo
   #:demo-base-dsl #:demo-component-dsl #:demo-application-dsl
   #:demo-state-model #:demo-complete-integration))

(in-package :elmtui.examples.dsl-integration)

;;;--------------------------------------------------------------
;;; LAYER 1: Enhanced State Model Definition
;;;--------------------------------------------------------------

;; Define a comprehensive state model for our demo application
(defmodel-contracted contact-app-state
  ((current-view :contact-list :type keyword :required t
                 :validator (lambda (v) (member v '(:contact-list :contact-form :contact-detail))))
   (contacts nil :type list)
   (selected-contact-id nil :type (or null keyword))
   (form-data nil :type list)
   (search-query "" :type string)
   (loading nil :type boolean)
   (error-message nil :type (or null string))
   (last-action nil :type (or null keyword))
   (action-timestamp nil :type (or null integer)))
  
  :validation (lambda (state)
                ;; Global validation rules
                (when (eq (getf state :current-view) :contact-detail)
                  (unless (getf state :selected-contact-id)
                    (error "Contact detail view requires selected-contact-id")))
                
                (let ((contacts (getf state :contacts)))
                  (when contacts
                    (unless (every (lambda (contact)
                                   (and (listp contact)
                                        (getf contact :id)
                                        (getf contact :name)))
                                 contacts)
                      (error "All contacts must have :id and :name")))))
  
  :transactions
  ((navigate-to-view (state view-name &optional context)
     "Transaction to navigate between views"
     (list (make-state-patch :path '(:current-view) :value view-name :operation :set)
           (make-state-patch :path '(:last-action) :value :navigate :operation :set)
           (make-state-patch :path '(:action-timestamp) :value (get-universal-time) :operation :set)))
   
   (add-contact (state contact-data)
     "Transaction to add a new contact"
     (let ((new-id (intern (format nil "CONTACT-~A" (get-universal-time)) :keyword))
           (contact (list* :id new-id contact-data)))
       (list (make-state-patch :path '(:contacts) :value contact :operation :append)
             (make-state-patch :path '(:selected-contact-id) :value new-id :operation :set)
             (make-state-patch :path '(:current-view) :value :contact-detail :operation :set)
             (make-state-patch :path '(:last-action) :value :add-contact :operation :set))))
   
   (update-contact (state contact-id updates)
     "Transaction to update an existing contact"
     (let ((contacts (getf state :contacts))
           (updated-contacts (mapcar (lambda (contact)
                                     (if (eq (getf contact :id) contact-id)
                                         (apply #'list* :id contact-id updates)
                                         contact))
                                   contacts)))
       (list (make-state-patch :path '(:contacts) :value updated-contacts :operation :set)
             (make-state-patch :path '(:last-action) :value :update-contact :operation :set))))
   
   (set-error (state message)
     "Transaction to set an error message"
     (list (make-state-patch :path '(:error-message) :value message :operation :set)
           (make-state-patch :path '(:last-action) :value :error :operation :set))))
  
  :observers
  ((lambda (old-state new-state change-type)
     ;; Log significant state changes
     (when (eq change-type :updated)
       (let ((old-view (getf old-state :current-view))
             (new-view (getf new-state :current-view)))
         (when (not (eq old-view new-view))
           (format t "~&[State Observer] View changed: ~A -> ~A~%" old-view new-view))))))
  
  :documentation "Complete state model for contact management application"
  :export-accessors t)

;;;--------------------------------------------------------------
;;; LAYER 2: Message Schema Definition
;;;--------------------------------------------------------------

(defmsg ContactAppMsg (:docstring "Messages for contact management application")
  ;; Navigation messages
  (NavigateToView :view keyword)
  (NavigateBack)
  
  ;; Contact management messages
  (AddContact :contact-data list)
  (UpdateContact :contact-id keyword :updates list)
  (DeleteContact :contact-id keyword)
  (SelectContact :contact-id keyword)
  
  ;; Form messages
  (UpdateFormField :field keyword :value t)
  (SubmitForm)
  (ClearForm)
  (ValidateForm)
  
  ;; Search messages
  (UpdateSearchQuery :query string)
  (ClearSearch)
  
  ;; System messages
  (SetLoading :loading boolean)
  (SetError :message string)
  (ClearError)
  
  ;; Component-specific messages
  (ContactListItemClicked :contact-id keyword)
  (ContactFormSubmitted :form-data list)
  (ConfirmationDialogAccepted :action keyword))

;;;--------------------------------------------------------------
;;; LAYER 3: Update Function with Contract Integration
;;;--------------------------------------------------------------

(defupdate-hybrid contact-app-update (model message) 
    :message-type ContactAppMsg :prefer-typed t
  "Hybrid update function handling both typed and flexible messages"
  
  (let ((msg-type (if (listp message) (first message) message))
        (msg-data (when (listp message) (rest message))))
    
    (case msg-type
      ;; Navigation
      ((:navigate-to-view :nav)
       (let ((view (if (listp message) 
                      (getf msg-data :view)
                      :contact-list)))  ; Default for flexible messages
         (multiple-value-bind (new-state transaction)
             (navigate-to-view model view)
           (values new-state nil))))
      
      (:navigate-back
       (let ((current-view (getf model :current-view)))
         (let ((previous-view (case current-view
                               (:contact-detail :contact-list)
                               (:contact-form :contact-list)
                               (t :contact-list))))
           (multiple-value-bind (new-state transaction)
               (navigate-to-view model previous-view)
             (values new-state nil)))))
      
      ;; Contact management
      ((:add-contact :add)
       (let ((contact-data (if (listp message)
                              (getf msg-data :contact-data)
                              '(:name "New Contact" :email ""))))
         (multiple-value-bind (new-state transaction)
             (add-contact model contact-data)
           (values new-state nil))))
      
      ((:update-contact :update)
       (let ((contact-id (getf msg-data :contact-id))
             (updates (getf msg-data :updates)))
         (multiple-value-bind (new-state transaction)
             (update-contact model contact-id updates)
           (values new-state nil))))
      
      ((:select-contact :select)
       (let ((contact-id (if (listp message)
                            (getf msg-data :contact-id)
                            :contact-1)))  ; Default for demo
         (values (list* :selected-contact-id contact-id
                       :current-view :contact-detail
                       model)
                nil)))
      
      ;; Form handling
      ((:update-form-field :form-field)
       (let ((field (getf msg-data :field))
             (value (getf msg-data :value))
             (current-form (getf model :form-data)))
         (values (list* :form-data (list* field value current-form) model) nil)))
      
      ((:submit-form :submit)
       (let ((form-data (getf model :form-data)))
         (if (and (getf form-data :name) (not (string= (getf form-data :name) "")))
             ;; Valid form - add contact
             (multiple-value-bind (new-state transaction)
                 (add-contact model form-data)
               (values (list* :form-data nil new-state) nil))
             ;; Invalid form - set error
             (multiple-value-bind (new-state transaction)
                 (set-error model "Contact name is required")
               (values new-state nil)))))
      
      ;; Search
      ((:update-search-query :search)
       (let ((query (if (listp message)
                       (getf msg-data :query)
                       "")))
         (values (list* :search-query query model) nil)))
      
      ;; Error handling
      ((:set-error :error)
       (let ((error-msg (if (listp message)
                           (getf msg-data :message)
                           "Unknown error")))
         (multiple-value-bind (new-state transaction)
             (set-error model error-msg)
           (values new-state nil))))
      
      (:clear-error
       (values (list* :error-message nil model) nil))
      
      ;; Loading state
      ((:set-loading :loading)
       (let ((loading (if (listp message)
                         (getf msg-data :loading)
                         t)))
         (values (list* :loading loading model) nil)))
      
      ;; Default case
      (t 
       (format t "~&[Update] Unhandled message: ~S~%" message)
       (values nil nil)))))

;;;--------------------------------------------------------------
;;; LAYER 4: Component DSL Definitions
;;;--------------------------------------------------------------

;; Contact list item component
(defcomponent contact-list-item ()
  (:state
   (contact nil :type list)
   (selected nil :type boolean)
   (hover nil :type boolean))
  
  (:init (props id-path)
    (values (list :contact (getf props :contact)
                  :selected (getf props :selected)
                  :hover nil)
            nil))
  
  (:update (message state app-state id-path)
    (:mouse-enter ()
      (values (list :hover t) nil))
    (:mouse-leave ()
      (values (list :hover nil) nil))
    (:click ()
      (let ((contact-id (getf (getf state :contact) :id)))
        (values nil (list (list :app-message 
                               (list :select-contact :contact-id contact-id)))))))
  
  (:view (state app-state id-path)
    (let* ((contact (getf state :contact))
           (selected (getf state :selected))
           (hover (getf state :hover))
           (name (getf contact :name "Unknown"))
           (email (getf contact :email "")))
      
      ;; Using enhanced base DSL with validation
      (validate-base-dsl
       `(:container
         :id ,(elmtui.ui.api:id-from-path id-path)
         :class ,(append '(:contact-item)
                        (when selected '(:selected))
                        (when hover '(:hover)))
         :style (:padding 10 
                :border (:style ,(if selected :double :single))
                :background-color ,(if hover :light-gray :white))
         :children
         ((:container
           :layout :horizontal
           :children
           ((:text :content ,name :class (:contact-name))
            (:spacer :width 10)
            (:text :content ,email :class (:contact-email :secondary))))
          ,@(when selected
              `((:text :content "▶ Selected" :class (:selection-indicator))))))))))

;; Contact form component  
(defcomponent contact-form ()
  (:state
   (form-data nil :type list)
   (validation-errors nil :type list)
   (dirty nil :type boolean))
  
  (:init (props id-path)
    (values (list :form-data (getf props :initial-data)
                  :validation-errors nil
                  :dirty nil)
            nil))
  
  (:update (message state app-state id-path)
    (:field-changed (field value)
      (let ((current-data (getf state :form-data)))
        (values (list :form-data (list* field value current-data)
                      :dirty t
                      :validation-errors nil)
                nil)))
    (:submit ()
      (let ((form-data (getf state :form-data))
            (errors nil))
        ;; Validate form
        (unless (getf form-data :name)
          (push "Name is required" errors))
        (unless (getf form-data :email)
          (push "Email is required" errors))
        
        (if errors
            (values (list :validation-errors errors) nil)
            (values (list :dirty nil :validation-errors nil)
                   (list (list :app-message 
                              (list :contact-form-submitted :form-data form-data))))))))
  
  (:view (state app-state id-path)
    (let ((form-data (getf state :form-data))
          (errors (getf state :validation-errors))
          (dirty (getf state :dirty)))
      
      ;; Complex nested DSL structure
      (expand-base-dsl
       `(:container
         :id ,(elmtui.ui.api:id-from-path id-path)
         :class (:contact-form)
         :style (:padding 20 :gap 15)
         :children
         ((:text :content "Contact Information" :class (:form-title))
          
          ;; Name field
          (:container
           :class (:form-field)
           :children
           ((:label :text "Name:" :for :name-input)
            (:input :id :name-input 
                   :type :text
                   :value ,(getf form-data :name "")
                   :placeholder "Enter contact name"
                   :required t)))
          
          ;; Email field
          (:container
           :class (:form-field)
           :children
           ((:label :text "Email:" :for :email-input)
            (:input :id :email-input
                   :type :email
                   :value ,(getf form-data :email "")
                   :placeholder "Enter email address"
                   :required t)))
          
          ;; Phone field
          (:container
           :class (:form-field)
           :children
           ((:label :text "Phone:" :for :phone-input)
            (:input :id :phone-input
                   :type :tel
                   :value ,(getf form-data :phone "")
                   :placeholder "Enter phone number")))
          
          ;; Validation errors
          ,@(when errors
              `((:container
                 :class (:validation-errors)
                 :style (:color :red :background-color :light-pink :padding 10)
                 :children
                 ,(mapcar (lambda (error)
                           `(:text :content ,error :class (:error-message)))
                         errors))))
          
          ;; Form actions
          (:container
           :class (:form-actions)
           :layout :horizontal
           :style (:gap 10)
           :children
           ((:button :text "Save Contact" 
                    :class (:primary-button)
                    :disabled ,(and (not dirty) (null errors)))
            (:button :text "Cancel" 
                    :class (:secondary-button))))))))))

;;;--------------------------------------------------------------
;;; LAYER 5: View Function with Full DSL Integration
;;;--------------------------------------------------------------

(defview contact-app-view (model)
  "Main view function using complete DSL integration"
  
  (let ((current-view (getf model :current-view))
        (contacts (getf model :contacts))
        (selected-id (getf model :selected-contact-id))
        (search-query (getf model :search-query))
        (error-message (getf model :error-message))
        (loading (getf model :loading)))
    
    ;; Main application layout using enhanced base DSL
    (normalize-base-dsl
     `(:container
       :id :main-app
       :class (:contact-app)
       :style (:height "100vh" :display :flex :flex-direction :column)
       :children
       
       ;; Header
       ((:container
         :id :app-header
         :class (:app-header)
         :style (:background-color :blue :color :white :padding 15)
         :children
         ((:text :content "Contact Manager" :class (:app-title))
          (:container
           :layout :horizontal
           :style (:align-items :center :gap 10)
           :children
           ((:text :content ,(format nil "View: ~A" current-view) :class (:current-view))
            ,@(when loading
                `((:text :content "Loading..." :class (:loading-indicator))))))))
        
        ;; Error banner
        ,@(when error-message
            `((:container
               :id :error-banner
               :class (:error-banner)
               :style (:background-color :red :color :white :padding 10)
               :children
               ((:text :content ,error-message)
                (:button :text "×" :class (:close-button))))))
        
        ;; Search bar (shown on contact list view)
        ,@(when (eq current-view :contact-list)
            `((:container
               :id :search-bar
               :class (:search-bar)
               :style (:padding 10 :background-color :light-gray)
               :children
               ((:input :id :search-input
                       :type :search
                       :value ,search-query
                       :placeholder "Search contacts..."
                       :style (:width "100%"))))))
        
        ;; Main content area
        (:container
         :id :main-content
         :class (:main-content)
         :style (:flex 1 :padding 20)
         :children
         ,(case current-view
            (:contact-list
             ;; Contact list view
             `((:container
                :id :contact-list-container
                :class (:contact-list)
                :children
                ((:container
                  :class (:list-header)
                  :layout :horizontal
                  :style (:justify-content :space-between :margin-bottom 20)
                  :children
                  ((:text :content ,(format nil "Contacts (~A)" (length contacts)) 
                         :class (:contact-count))
                   (:button :text "Add Contact" 
                           :class (:add-button :primary-button))))
                 
                 ;; Contact list items
                 ,@(if contacts
                       (mapcar (lambda (contact)
                                `(contact-list-item 
                                  :id ,(getf contact :id)
                                  :contact ,contact
                                  :selected ,(eq (getf contact :id) selected-id)))
                              contacts)
                       `((:text :content "No contacts yet. Click 'Add Contact' to get started."
                               :class (:empty-state))))))))
            
            (:contact-form
             ;; Contact form view
             `((:container
                :id :contact-form-container
                :class (:contact-form-container)
                :children
                ((:container
                  :class (:form-header)
                  :layout :horizontal
                  :style (:justify-content :space-between :margin-bottom 20)
                  :children
                  ((:text :content "Add New Contact" :class (:form-title))
                   (:button :text "← Back to List" :class (:back-button))))
                 
                 (contact-form :id :main-contact-form
                              :initial-data ,(getf model :form-data))))))
            
            (:contact-detail
             ;; Contact detail view
             (let ((selected-contact (find selected-id contacts 
                                          :key (lambda (c) (getf c :id)))))
               (if selected-contact
                   `((:container
                      :id :contact-detail-container
                      :class (:contact-detail)
                      :children
                      ((:container
                        :class (:detail-header)
                        :layout :horizontal
                        :style (:justify-content :space-between :margin-bottom 20)
                        :children
                        ((:text :content ,(getf selected-contact :name) :class (:contact-name))
                         (:container
                          :layout :horizontal
                          :style (:gap 10)
                          :children
                          ((:button :text "Edit" :class (:edit-button))
                           (:button :text "Delete" :class (:delete-button :danger))
                           (:button :text "← Back" :class (:back-button))))))
                       
                       (:container
                        :class (:contact-details)
                        :style (:gap 15)
                        :children
                        ((:container
                          :class (:detail-field)
                          :children
                          ((:label :text "Email:")
                           (:text :content ,(getf selected-contact :email "Not provided"))))
                         
                         (:container
                          :class (:detail-field)
                          :children
                          ((:label :text "Phone:")
                           (:text :content ,(getf selected-contact :phone "Not provided"))))))))
                   
                   ;; Contact not found
                   `((:container
                      :class (:error-state)
                      :children
                      ((:text :content "Contact not found" :class (:error-message))
                       (:button :text "← Back to List" :class (:back-button))))))))
            
            (t 
             ;; Unknown view
             `((:text :content ,(format nil "Unknown view: ~A" current-view)
                     :class (:error-message))))))
        
        ;; Footer
        (:container
         :id :app-footer
         :class (:app-footer)
         :style (:background-color :light-gray :padding 10 :text-align :center)
         :children
         ((:text :content ,(format nil "Last action: ~A at ~A" 
                                  (getf model :last-action "none")
                                  (if (getf model :action-timestamp)
                                      (format nil "~A" (getf model :action-timestamp))
                                      "never"))
                :class (:footer-info))))))))

;;;--------------------------------------------------------------
;;; LAYER 6: Application Definition with Complete Integration
;;;--------------------------------------------------------------

(defapplication contact-manager-app
  :root-component-dsl (contact-app-view 
                      (make-contact-app-state 
                       :contacts '((:id :contact-1 :name "John Doe" :email "john@example.com")
                                   (:id :contact-2 :name "Jane Smith" :email "jane@example.com"))
                       :current-view :contact-list))
  
  :initial-state-plist (make-contact-app-state 
                        :contacts '((:id :contact-1 :name "John Doe" :email "john@example.com" :phone "+1-555-0123")
                                    (:id :contact-2 :name "Jane Smith" :email "jane@example.com" :phone "+1-555-0456")
                                    (:id :contact-3 :name "Bob Johnson" :email "bob@example.com"))
                        :current-view :contact-list
                        :search-query ""
                        :loading nil
                        :error-message nil)
  
  :update-fn 'contact-app-update
  :view-fn 'contact-app-view
  
  :subscriptions-fn (lambda (model)
                      ;; Simple keyboard navigation
                      (list 
                       (elmtui.contracts:make-subscription
                        :type :keyboard
                        :config '(:capture-all t)
                        :message-fn (lambda (key-event)
                                     (case (getf key-event :key)
                                       (:escape '(:navigate-back))
                                       (:f5 '(:clear-error))
                                       (:n '(:navigate-to-view :view :contact-form))
                                       (t nil))))))
  
  :root-viewport-id :contact-manager-viewport)

;;;--------------------------------------------------------------
;;; Demo Functions
;;;--------------------------------------------------------------

(defun demo-base-dsl ()
  "Demonstrates base DSL validation and expansion"
  (format t "~&=== Base DSL Demo ===~%")
  
  ;; Test basic DSL validation
  (let ((simple-dsl '(:text :content "Hello World")))
    (format t "Simple DSL: ~S~%" simple-dsl)
    (format t "Valid: ~A~%" (elmtui.view.dsl.base:base-dsl-p simple-dsl))
    (format t "Expanded: ~S~%" (expand-base-dsl simple-dsl)))
  
  ;; Test complex nested DSL
  (let ((complex-dsl '(:container 
                       :id :main
                       :children ((:text :content "Title")
                                 (:button :text "Click Me")))))
    (format t "~%Complex DSL: ~S~%" complex-dsl)
    (format t "Valid: ~A~%" (elmtui.view.dsl.base:base-dsl-p complex-dsl))
    (format t "Statistics: ~S~%" (elmtui.view.dsl.base:dsl-statistics complex-dsl)))
  
  ;; Test DSL manipulation
  (let ((element (make-dsl-element :button :text "Original" :id :btn1)))
    (format t "~%Original element: ~S~%" element)
    (let ((updated (elmtui.view.dsl.base:update-dsl-element element :text "Updated")))
      (format t "Updated element: ~S~%" updated))))

(defun demo-state-model ()
  "Demonstrates enhanced state model functionality"
  (format t "~&=== State Model Demo ===~%")
  
  ;; Create initial state
  (let ((state (make-contact-app-state 
                :contacts '((:id :demo-1 :name "Demo User" :email "demo@test.com"))
                :current-view :contact-list)))
    
    (format t "Initial state: ~S~%" state)
    (format t "Valid: ~A~%" (validate-contact-app-state state))
    
    ;; Test transaction
    (multiple-value-bind (new-state transaction)
        (add-contact state '(:name "New Contact" :email "new@test.com"))
      (format t "~%After adding contact:~%")
      (format t "New state: ~S~%" new-state)
      (format t "Transaction: ~S~%" transaction))
    
    ;; Test patch operation
    (let ((patches (update-form-field state :name "Updated Name")))
      (format t "~%Form field patches: ~S~%" patches)
      (let ((patched-state (apply-state-patches state patches)))
        (format t "Patched state: ~S~%" patched-state)))))

(defun demo-component-dsl ()
  "Demonstrates component DSL functionality"
  (format t "~&=== Component DSL Demo ===~%")
  
  ;; This would normally be integrated with the component system
  (format t "Component DSL integration requires full UI system~%")
  (format t "See the contact-list-item and contact-form components above~%"))

(defun demo-application-dsl ()
  "Demonstrates application DSL functionality"
  (format t "~&=== Application DSL Demo ===~%")
  
  ;; Show application configuration
  (let ((app-config (gethash 'contact-manager-app elmtui.core.globals:*applications*)))
    (if app-config
        (progn
          (format t "Application registered: contact-manager-app~%")
          (format t "Update function: ~A~%" (elmtui.app.api:app-config-update-fn-sym app-config))
          (format t "View function: ~A~%" (elmtui.app.api:app-config-view-fn-sym app-config)))
        (format t "Application not found (may need to load application system)~%"))))

(defun demo-complete-integration ()
  "Demonstrates complete DSL integration"
  (format t "~&=== Complete Integration Demo ===~%")
  
  ;; Enable contract debugging
  (enable-contract-debugging t)
  
  ;; Test update function with various message types
  (let ((initial-state (make-contact-app-state :current-view :contact-list)))
    
    ;; Test typed message
    (format t "Testing typed message...~%")
    (multiple-value-bind (new-state commands)
        (contact-app-update initial-state '(:navigate-to-view :view :contact-form))
      (format t "Result: ~S~%" new-state)
      (format t "Commands: ~S~%" commands))
    
    ;; Test flexible message
    (format t "~%Testing flexible message...~%")
    (multiple-value-bind (new-state commands)
        (contact-app-update initial-state :nav)
      (format t "Result: ~S~%" new-state)
      (format t "Commands: ~S~%" commands))
    
    ;; Test view function
    (format t "~%Testing view function...~%")
    (let ((view-result (contact-app-view initial-state)))
      (format t "View DSL generated successfully: ~A elements~%" 
              (getf (elmtui.view.dsl.base:dsl-statistics view-result) :total-elements))))
  
  (enable-contract-debugging nil))

(defun run-dsl-integration-demo (&key (demos :all))
  "Runs the complete DSL integration demonstration"
  (format t "~&=== Elmtui DSL Integration Demonstration ===~%")
  (format t "This demo shows all DSL layers working together:~%")
  (format t "- Base DSL (UI primitives)~%")
  (format t "- Component DSL (reusable components)~%") 
  (format t "- Application DSL (complete applications)~%")
  (format t "- State Model (enhanced state management)~%")
  (format t "- Contract Integration (validation and safety)~%~%")
  
  (case demos
    (:base-dsl (demo-base-dsl))
    (:state-model (demo-state-model))
    (:component-dsl (demo-component-dsl))
    (:application-dsl (demo-application-dsl))
    (:integration (demo-complete-integration))
    (:all 
     (demo-base-dsl)
     (demo-state-model)
     (demo-component-dsl)
     (demo-application-dsl)
     (demo-complete-integration))
    (t (format t "Unknown demo: ~A~%" demos)))
  
  (format t "~&=== Demo Complete ===~%"))

;; Usage examples:
;; (run-dsl-integration-demo)                    ; Run all demos
;; (run-dsl-integration-demo :demos :base-dsl)   ; Just base DSL demo
;; (run-dsl-integration-demo :demos :integration) ; Just integration demo