;;;===============================================================
;;; File: tests/v2/test-app-lifecycle.lisp
;;; FiveAM Integration Tests for Full Application Lifecycle using v2 Components
;;;===============================================================

(uiop:define-package :elmtui-test-app-lifecycle
  (:use :cl :fiveam)
  (:import-from :elmtui.state
                #:make-application-state
                #:state-ref
                #:set-state
                #:with-transaction)
  (:import-from :elmtui.state.update
                #:defupdate)
  (:import-from :elmtui.view.dsl
                #:define-view)
  (:import-from :elmtui.runtime
                #:def-elm-app
                #:make-app-config
                #:initialize-app)
  (:import-from :elmtui.ui.widgets)  ; Import all v2 widgets
  (:import-from :elmtui.ui.widgets.button
                #:init-button)
  (:import-from :elmtui.ui.widgets.textinput
                #:init-textinput
                #:textinput-model-value)
  (:import-from :elmtui.ui.widgets.label
                #:init-label
                #:label-model-text)
  (:import-from :elmtui.core.events
                #:key-event)
  (:export :run-elmtui-test-app-lifecycle))

(in-package :elmtui-test-app-lifecycle)

(def-suite elmtui-test-app-lifecycle-suite
  :description "Integration tests for full application lifecycle with v2 components")
(in-suite elmtui-test-app-lifecycle-suite)

;;;-----------------------------------------------------------------------------
;;; Demo Counter Application
;;;-----------------------------------------------------------------------------

(defun counter-app-init ()
  "Initialize a simple counter application"
  (let ((app-state (make-application-state))
        (initial-commands nil))

    ;; Initialize widgets
    (multiple-value-bind (counter-label _)
        (init-label :counter-label :text "Count: 0")
      (declare (ignore _))

      (multiple-value-bind (increment-btn _)
          (init-button :increment-btn :label "+" :on-click-msg :increment)
        (declare (ignore _))

        (multiple-value-bind (decrement-btn _)
            (init-button :decrement-btn :label "-" :on-click-msg :decrement)
          (declare (ignore _))

          ;; Set initial state
          (with-transaction (app-state)
            (set-state app-state :counter-label counter-label)
            (set-state app-state :increment-btn increment-btn)
            (set-state app-state :decrement-btn decrement-btn)
            (set-state app-state :count 0)
            (set-state app-state :current-focus-id :increment-btn))

          (values app-state initial-commands))))))

(defupdate counter-app-update (app-state message)
  "Update function for counter application"
  (case message
    (:increment
     (let ((new-count (1+ (state-ref app-state :count))))
       (values
        (list :count new-count
              :counter-label (init-label :counter-label
                                         :text (format nil "Count: ~A" new-count)))
        nil)))

    (:decrement
     (let ((new-count (1- (state-ref app-state :count))))
       (values
        (list :count new-count
              :counter-label (init-label :counter-label
                                         :text (format nil "Count: ~A" new-count)))
        nil)))

    (otherwise
     (values nil nil))))

(define-view counter-app-view (app-state dispatch)
  (:div :id "counter-app" :class "app-container"
        (:label :widget-id :counter-label)
        (:div :class "button-group"
              (:button :widget-id :decrement-btn)
              (:button :widget-id :increment-btn))))

(def-elm-app counter-test-app
  :init #'counter-app-init
  :update #'counter-app-update
  :view #'counter-app-view)

;;;-----------------------------------------------------------------------------
;;; Demo Form Application
;;;-----------------------------------------------------------------------------

(defun form-app-init ()
  "Initialize a simple form application"
  (let ((app-state (make-application-state))
        (initial-commands nil))

    ;; Initialize widgets
    (multiple-value-bind (name-input _)
        (init-textinput :name-input :placeholder "Your Name")
      (declare (ignore _))

      (multiple-value-bind (email-input _)
          (init-textinput :email-input :placeholder "Your Email")
        (declare (ignore _))

        (multiple-value-bind (submit-btn _)
            (init-button :submit-btn :label "Submit" :on-click-msg :submit-form)
          (declare (ignore _))

          (multiple-value-bind (status-label _)
              (init-label :status-label :text "Please fill the form")
            (declare (ignore _))

            ;; Set initial state
            (with-transaction (app-state)
              (set-state app-state :name-input name-input)
              (set-state app-state :email-input email-input)
              (set-state app-state :submit-btn submit-btn)
              (set-state app-state :status-label status-label)
              (set-state app-state :current-focus-id :name-input)
              (set-state app-state :submission-count 0))

            (values app-state initial-commands)))))))

(defupdate form-app-update (app-state message)
  "Update function for form application"
  (cond
    ;; Handle input changes
    ((and (listp message) (eq (first message) :textinput-change))
     (let* ((widget-id (getf (rest message) :widget-id))
            (value (getf (rest message) :value))
            (current-input (state-ref app-state widget-id))
            (updated-input (copy-structure current-input)))

       ;; Update input value
       (setf (slot-value updated-input 'elmtui.ui.widgets.textinput::value) value)

       (values
        (list widget-id updated-input)
        nil)))

    ;; Handle form submission
    ((eq message :submit-form)
     (let* ((name-input (state-ref app-state :name-input))
            (email-input (state-ref app-state :email-input))
            (name (textinput-model-value name-input))
            (email (textinput-model-value email-input))
            (submission-count (1+ (state-ref app-state :submission-count)))
            (status-text (if (and name (not (string= name ""))
                                  email (not (string= email "")))
                             (format nil "Thank you, ~A! Form submitted (#~A)" name submission-count)
                             "Please fill all fields")))

       (values
        (list :submission-count submission-count
              :status-label (init-label :status-label :text status-text))
        nil)))

    (t
     (values nil nil))))

(define-view form-app-view (app-state dispatch)
  (:div :id "form-app" :class "form-container"
        (:h1 "Contact Form")
        (:form :class "contact-form"
               (:div :class "form-group"
                     (:label :text "Name:")
                     (:textinput :widget-id :name-input))
               (:div :class "form-group"
                     (:label :text "Email:")
                     (:textinput :widget-id :email-input))
               (:div :class "form-actions"
                     (:button :widget-id :submit-btn))
               (:div :class "form-status"
                     (:label :widget-id :status-label)))))

(def-elm-app form-test-app
  :init #'form-app-init
  :update #'form-app-update
  :view #'form-app-view)

;;;-----------------------------------------------------------------------------
;;; Integration Tests
;;;-----------------------------------------------------------------------------

(test counter-app-full-lifecycle
  "Test the full lifecycle of the counter application"
  ;; Initialize the app
  (multiple-value-bind (app-state _)
      (counter-app-init)
    (declare (ignore _))

    ;; Verify initial state
    (is (= (state-ref app-state :count) 0))
    (is (equal (label-model-text (state-ref app-state :counter-label)) "Count: 0"))

    ;; Get the initial view
    (let ((view (counter-app-view app-state #'identity)))
      (is (eq (elmtui.view.core:ui-node-type view) :div))
      (is (= (length (elmtui.view.core:ui-node-children view)) 2))

      ;; Simulate increment action
      (multiple-value-bind (changes commands)
          (counter-app-update app-state :increment)
        ;; Check that state changes were returned correctly
        (is (= (getf changes :count) 1))
        (is (null commands))

        ;; Apply changes to state
        (with-transaction (app-state)
          (loop for (k v) on changes by #'cddr
                do (set-state app-state k v)))

        ;; Verify state was updated
        (is (= (state-ref app-state :count) 1))
        (is (equal (label-model-text (state-ref app-state :counter-label)) "Count: 1"))

        ;; Get updated view
        (let ((updated-view (counter-app-view app-state #'identity)))
          ;; Structure should be the same
          (is (eq (elmtui.view.core:ui-node-type updated-view) :div))
          (is (= (length (elmtui.view.core:ui-node-children updated-view)) 2))

          ;; Simulate decrement action twice
          (multiple-value-bind (changes1 _)
              (counter-app-update app-state :decrement)
            (declare (ignore _))
            (with-transaction (app-state)
              (loop for (k v) on changes1 by #'cddr
                    do (set-state app-state k v)))

            (multiple-value-bind (changes2 _)
                (counter-app-update app-state :decrement)
              (declare (ignore _))
              (with-transaction (app-state)
                (loop for (k v) on changes2 by #'cddr
                      do (set-state app-state k v)))

              ;; Final state should reflect the updates
              (is (= (state-ref app-state :count) -1))
              (is (equal (label-model-text (state-ref app-state :counter-label))
                         "Count: -1")))))))))

(test form-app-full-lifecycle
  "Test the full lifecycle of the form application"
  ;; Initialize the app
  (multiple-value-bind (app-state _)
      (form-app-init)
    (declare (ignore _))

    ;; Create a message collector for dispatch
    (let ((messages '())
          (dispatch-fn (lambda (msg) (push msg messages))))

      ;; Get the initial view
      (let ((view (form-app-view app-state dispatch-fn)))
        (is (eq (elmtui.view.core:ui-node-type view) :div))

        ;; Find the name input in the view and update it
        (let* ((name-input-id :name-input)
               (name-input (state-ref app-state name-input-id))
               (change-msg (list :textinput-change :widget-id name-input-id :value "John Doe")))

          ;; Process the update
          (multiple-value-bind (changes _)
              (form-app-update app-state change-msg)
            (declare (ignore _))

            ;; Apply changes
            (with-transaction (app-state)
              (loop for (k v) on changes by #'cddr
                    do (set-state app-state k v)))

            ;; Verify name was updated
            (is (equal (textinput-model-value (state-ref app-state name-input-id)) "John Doe"))

            ;; Update email field
            (let* ((email-input-id :email-input)
                   (email-input (state-ref app-state email-input-id))
                   (change-msg (list :textinput-change :widget-id email-input-id :value "john@example.com")))

              ;; Process the update
              (multiple-value-bind (changes _)
                  (form-app-update app-state change-msg)
                (declare (ignore _))

                ;; Apply changes
                (with-transaction (app-state)
                  (loop for (k v) on changes by #'cddr
                        do (set-state app-state k v)))

                ;; Verify email was updated
                (is (equal (textinput-model-value (state-ref app-state email-input-id)) "john@example.com"))

                ;; Submit the form
                (multiple-value-bind (changes _)
                    (form-app-update app-state :submit-form)
                  (declare (ignore _))

                  ;; Apply changes
                  (with-transaction (app-state)
                    (loop for (k v) on changes by #'cddr
                          do (set-state app-state k v)))

                  ;; Verify submission was processed
                  (is (= (state-ref app-state :submission-count) 1))
                  (is (search "Thank you, John Doe"
                              (label-model-text (state-ref app-state :status-label))))

                  ;; Get updated view
                  (let ((updated-view (form-app-view app-state dispatch-fn)))
                    ;; Structure should be preserved
                    (is (eq (elmtui.view.core:ui-node-type updated-view) :div))))))))))))

;;;-----------------------------------------------------------------------------
;;; App Configuration and Initialization
;;;-----------------------------------------------------------------------------

(test app-configuration
  "Test app configuration and initialization"
  ;; Define configuration for counter app
  (let ((app-config (make-app-config
                     :app-name 'counter-test-app
                     :init-fn #'counter-app-init
                     :update-fn #'counter-app-update
                     :view-fn #'counter-app-view)))

    ;; Initialize the app
    (multiple-value-bind (app-state initial-commands)
        (initialize-app app-config)

      ;; Verify app was initialized correctly
      (is (not (null app-state)))
      (is (= (state-ref app-state :count) 0))
      (is (null initial-commands)) ; No initial commands expected
      )))

;; (defun run-elmtui-test-app-lifecycle ()
;;   (fiveam:run! 'elmtui-test-app-lifecycle-suite))
