;;;===============================================================
;;; File: examples/grid-event-form-app.lisp
;;; Example Application Using Grid Layout and Event System
;;;===============================================================

(uiop:define-package :elmtui-grid-event-example
  (:use :cl :alexandria)
  ;; Import UI components
  (:import-from :elmtui.view.dsl #:define-view)
  (:import-from :elmtui.view.core #:make-ui-node)
  ;; Import grid layout
  (:import-from :elmtui.view.grid-layout
                #:define-grid-template
                #:build-grid-from-template)
  ;; Import event system
  (:import-from :elmtui.core.event-types
                #:make-key-event
                #:ui-event-stop-propagation)
  (:import-from :elmtui.core.focus-manager
                #:make-focus-manager
                #:set-focus
                #:get-next-focusable)
  ;; Import state management
  (:import-from :elmtui.state #:defmodel #:defupdate #:defview)
  (:import-from :elmtui.state.msg #:defmsg)
  (:import-from :elmtui.core.keymap #:make-keymap #:define-key))

(in-package :elmtui-grid-event-example)

;;;-----------------------------------------------------------------------------
;;; Application Model
;;;-----------------------------------------------------------------------------

;; Define model for form data
(defmodel form-state
  ((name "" :type string)
   (email "" :type string)
   (subject "" :type string)
   (message "" :type string)
   (focus-manager (make-focus-manager) :type focus-manager)
   (submitted nil :type boolean)
   (validation-errors nil :type list)))

;; Define messages for form updates
(defmsg update-field (field value))
(defmsg submit-form ())
(defmsg validate-form ())
(defmsg change-focus (target-id))
(defmsg form-tab-pressed (shift-pressed))

;; Define update functions for messages
(defupdate update-field (state msg)
  "Update a form field"
  (let ((field (getf msg :field))
        (value (getf msg :value)))
    (setf (slot-value state field) value)
    (setf (slot-value state 'validation-errors) nil)
    state))

(defupdate validate-form (state msg)
  "Validate form fields"
  (let ((errors nil))
    (when (string= (slot-value state 'name) "")
      (push '(:field name :message "Name is required") errors))
    (when (string= (slot-value state 'email) "")
      (push '(:field email :message "Email is required") errors))
    (when (not (search "@" (slot-value state 'email)))
      (push '(:field email :message "Email must contain @") errors))
    (when (string= (slot-value state 'subject) "")
      (push '(:field subject :message "Subject is required") errors))
    
    (setf (slot-value state 'validation-errors) errors)
    state))

(defupdate submit-form (state msg)
  "Submit the form"
  ;; First validate
  (setq state (validate-form state (list :type :validate-form)))
  
  ;; If no errors, mark as submitted
  (when (null (slot-value state 'validation-errors))
    (setf (slot-value state 'submitted) t))
  
  state)

(defupdate change-focus (state msg)
  "Change the currently focused element"
  (let ((target-id (getf msg :target-id))
        (focus-manager (slot-value state 'focus-manager)))
    (set-focus focus-manager target-id)
    state))

(defupdate form-tab-pressed (state msg)
  "Handle tab key for form navigation"
  (let ((shift-pressed (getf msg :shift-pressed))
        (focus-manager (slot-value state 'focus-manager))
        (current-focus (slot-value state 'focus-manager)))
    
    ;; Get the next focusable element in the appropriate direction
    (let ((next-focus (if shift-pressed
                          (elmtui.core.focus-manager:get-previous-focusable
                           focus-manager
                           (elmtui.core.focus-manager:focus-manager-current-focus focus-manager))
                          (elmtui.core.focus-manager:get-next-focusable
                           focus-manager
                           (elmtui.core.focus-manager:focus-manager-current-focus focus-manager)))))
      
      ;; Set focus to the next element
      (when next-focus
        (set-focus focus-manager next-focus)))
    
    state))

;;;-----------------------------------------------------------------------------
;;; Grid Layout Definition
;;;-----------------------------------------------------------------------------

;; Define a grid template for our form
(defparameter *form-grid-template*
  (define-grid-template 
   :form-layout
   ;; Rows: header, form fields (4 rows), submit row, footer
   '("auto" "auto" "auto" "auto" "auto" "auto" "1fr")
   ;; Columns: label, field, validation
   '("100px" "1fr" "200px")
   ;; Named areas
   "header header header |
    name-label name-field name-validation |
    email-label email-field email-validation |
    subject-label subject-field subject-validation |
    message-label message-field message-validation |
    . submit-btn . |
    footer footer footer"))

;;;-----------------------------------------------------------------------------
;;; Event Handling
;;;-----------------------------------------------------------------------------

;; Keymap for our form
(defparameter *form-keymap* (make-keymap :name :form-keymap))

;; Define key bindings
(define-key *form-keymap* :tab 
  (lambda (event app-state)
    (elmtui.state.msg:send-message
     (list :type :form-tab-pressed
           :shift-pressed nil))))

(define-key *form-keymap* :shift-tab
  (lambda (event app-state)
    (elmtui.state.msg:send-message
     (list :type :form-tab-pressed
           :shift-pressed t))))

(define-key *form-keymap* :enter
  (lambda (event app-state)
    (let ((current-focus (elmtui.core.focus-manager:focus-manager-current-focus
                          (slot-value app-state 'focus-manager))))
      (when (eq current-focus :submit-btn)
        (elmtui.state.msg:send-message
         (list :type :submit-form)))
      ;; Stop propagation to prevent default handling
      (ui-event-stop-propagation event))))

;;;-----------------------------------------------------------------------------
;;; UI Components
;;;-----------------------------------------------------------------------------

(defun make-text-input (id value &optional placeholder)
  "Create a text input component with proper focus handling"
  (make-ui-node
   :type :input
   :id id
   :props (list :type "text"
                :value value
                :placeholder (or placeholder "")
                :focusable t)
   :on-key-down (lambda (event)
                  ;; Handle input field key events
                  (when (eq (elmtui.core.event-types:key-event-key event) :enter)
                    (elmtui.state.msg:send-message
                     (list :type :submit-form))
                    (ui-event-stop-propagation event)))
   :on-change (lambda (event)
                (elmtui.state.msg:send-message
                 (list :type :update-field
                       :field (intern (string-upcase (symbol-name id)))
                       :value (getf event :value))))))

(defun make-textarea (id value &optional placeholder)
  "Create a textarea component with proper focus handling"
  (make-ui-node
   :type :textarea
   :id id
   :props (list :value value
                :placeholder (or placeholder "")
                :focusable t)
   :on-change (lambda (event)
                (elmtui.state.msg:send-message
                 (list :type :update-field
                       :field (intern (string-upcase (symbol-name id)))
                       :value (getf event :value))))))

(defun make-validation-message (errors field-name)
  "Create a validation message component for a specific field"
  (let ((field-errors (remove-if-not
                       (lambda (err) (eq (getf err :field) field-name))
                       errors)))
    (if field-errors
        (make-ui-node
         :type :div
         :props (list :class "validation-error")
         :children (mapcar (lambda (err)
                             (make-ui-node
                              :type :span
                              :props (list :text (getf err :message))))
                           field-errors))
        ;; No errors, return empty div
        (make-ui-node
         :type :div))))

(defun make-submit-button (submitted validation-errors)
  "Create a submit button component"
  (make-ui-node
   :type :button
   :id :submit-btn
   :props (list :text (if submitted "Submitted!" "Submit")
                :disabled submitted
                :focusable t)
   :on-click (lambda (event)
               (elmtui.state.msg:send-message
                (list :type :submit-form)))))

;;;-----------------------------------------------------------------------------
;;; Main View
;;;-----------------------------------------------------------------------------

(defview form-app-view (state)
  "Main view for the form application"
  (let ((name (slot-value state 'name))
        (email (slot-value state 'email))
        (subject (slot-value state 'subject))
        (message (slot-value state 'message))
        (submitted (slot-value state 'submitted))
        (validation-errors (slot-value state 'validation-errors)))
    
    ;; Build the form components
    (let* ((header (make-ui-node
                    :type :h1
                    :props (list :text "Contact Form")))
           (name-label (make-ui-node
                        :type :label
                        :props (list :text "Name:")))
           (name-field (make-text-input :name-field name "Enter your name"))
           (name-validation (make-validation-message validation-errors 'name))
           
           (email-label (make-ui-node
                         :type :label
                         :props (list :text "Email:")))
           (email-field (make-text-input :email-field email "Enter your email"))
           (email-validation (make-validation-message validation-errors 'email))
           
           (subject-label (make-ui-node
                           :type :label
                           :props (list :text "Subject:")))
           (subject-field (make-text-input :subject-field subject "Enter subject"))
           (subject-validation (make-validation-message validation-errors 'subject))
           
           (message-label (make-ui-node
                           :type :label
                           :props (list :text "Message:")))
           (message-field (make-textarea :message-field message "Enter your message"))
           (message-validation (make-validation-message validation-errors 'message))
           
           (submit-btn (make-submit-button submitted validation-errors))
           
           (footer (make-ui-node
                    :type :div
                    :props (list :class "footer")
                    :children (list 
                               (make-ui-node
                                :type :span
                                :props (list :text "Press Tab to navigate, Enter to submit")))))
           
           ;; Map areas to components
           (area-map `(("header" . ,header)
                        ("name-label" . ,name-label)
                        ("name-field" . ,name-field)
                        ("name-validation" . ,name-validation)
                        ("email-label" . ,email-label)
                        ("email-field" . ,email-field)
                        ("email-validation" . ,email-validation)
                        ("subject-label" . ,subject-label)
                        ("subject-field" . ,subject-field)
                        ("subject-validation" . ,subject-validation)
                        ("message-label" . ,message-label)
                        ("message-field" . ,message-field)
                        ("message-validation" . ,message-validation)
                        ("submit-btn" . ,submit-btn)
                        ("footer" . ,footer))))
      
      ;; Build the complete form using our grid layout
      (build-grid-from-template 
       *form-grid-template* 
       area-map
       :gap 10))))

;;;-----------------------------------------------------------------------------
;;; Run the Application
;;;-----------------------------------------------------------------------------

(defun run-form-app ()
  "Run the form application"
  (let ((initial-state (make-instance 'form-state)))
    ;; Set up initial focus to the name field
    (let ((focus-manager (slot-value initial-state 'focus-manager)))
      (elmtui.core.focus-manager:recalculate-focusable-elements 
       focus-manager 
       (form-app-view initial-state))
      (set-focus focus-manager :name-field))
    
    ;; Run the application with our UI and update functions
    (elmtui:run-app initial-state 'form-app-view)))

;; To run the application:
;; (run-form-app)
