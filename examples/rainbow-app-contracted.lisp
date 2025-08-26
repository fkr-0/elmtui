;;;===============================================================
;;; File: examples/rainbow-app-contracted.lisp
;;; Rainbow app demonstration using formal Elm Architecture contracts
;;; This shows the proper way to structure Elm apps with contract enforcement
;;;===============================================================
(uiop:define-package :elmtui.examples.rainbow-app-contracted
  (:use :cl :alexandria :log4cl)
  (:import-from :log4cl #:log-info #:log-debug)
  (:import-from :elmtui.contracts
                #:defupdate #:defview #:defsubscriptions
                #:enable-contract-debugging #:validate-elm-application)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :cl-styles.api #:defrule #:defstylesheet #:rgb #:cls> #:type>)
  (:import-from :elmtui.core.event-types #:key-event)
  (:import-from :elmtui.state.api #:make-update-result)
  (:export
   :run-rainbow-contracted-app
   :initialize-app-state-rainbow-contracted-app
   :rainbow-contracted-update
   :rainbow-contracted-view
   :rainbow-contracted-subscriptions))

(in-package :elmtui.examples.rainbow-app-contracted)

;;;--------------------------------------------------------------
;;; Color Data & Stylesheet (same as original)
;;;--------------------------------------------------------------
(defvar rainbow-colors-with-names
  '((:red "red-stripe" (255 0 0))
    (:pink "pink-stripe" (255 192 203))
    (:orange "orange-stripe" (255 165 0))
    (:yellow "yellow-stripe" (255 255 0))
    (:green "green-stripe" (0 255 0))
    (:blue "blue-stripe" (0 0 255))
    (:indigo "indigo-stripe" (75 0 130))
    (:violet "violet-stripe" (238 130 238)))
  "List of colors and their corresponding class names for stripes.")

(defun generate-stripe-rules-forms ()
  "Generates a list of (defrule ...) forms for stripes."
  (loop for (color-name class-name rgb-vals) in rainbow-colors-with-names
        collect `(defrule (cls> ,class-name)
                   :bg-color ,(rgb rgb-vals)
                   :width 12
                   :height :fill)))

(defparameter rainbow-contracted-stylesheet
  `(defstylesheet
     ;; Container base style
     (defrule (type> :container)
       :display :flex
       :flex-direction :row
       :width :fill
       :height :fill)

     ;; Generate individual stripe rules
     ,@(generate-stripe-rules-forms))
  "Stylesheet for the rainbow application with contracts.")

;;;--------------------------------------------------------------
;;; Elm Architecture Implementation with Contracts
;;;--------------------------------------------------------------

;; CONTRACT ENFORCED: update(model, message) => (values new-model commands)
(defupdate rainbow-contracted-update (model message)
  "Handles updates to the rainbow application state with contract enforcement.

   Model Structure:
   - :should-quit - boolean indicating if app should terminate
   - :current-stylesheet - stylesheet for rendering
   - :animation-state - optional animation state

   Messages:
   - key-event instances - quit on any key
   - :app-quit-requested - explicit quit request"

  (cond
    ;; Handle key events - quit on any key press
    ((typep message 'key-event)
     (log-info "Key pressed, quitting rainbow app")
     (values (list :should-quit t
                   :current-stylesheet (getf model :current-stylesheet))
             ;; Commands: could add cleanup commands here
             nil))

    ;; Handle explicit quit messages
    ((and (listp message) (eq (first message) :app-quit-requested))
     (log-info "Explicit quit requested")
     (values (list :should-quit t
                   :current-stylesheet (getf model :current-stylesheet))
             nil))

    ;; Handle animation tick (future enhancement)
    ((and (listp message) (eq (first message) :animation-tick))
     (let ((current-tick (getf model :animation-tick 0)))
       (values (list :should-quit (getf model :should-quit)
                     :current-stylesheet (getf model :current-stylesheet)
                     :animation-tick (1+ current-tick))
               nil)))

    ;; Default: no change
    (t
     (log-debug "Unknown message in rainbow update: ~S" message)
     (values nil nil))))

;; CONTRACT ENFORCED: view(model) => dsl-tree
(defview rainbow-contracted-view (model)
  "Generates the DSL for the rainbow stripes with contract enforcement.

   Returns a container with colored stripes as children."

  (declare (ignore model)) ; This view is stateless

  `(:container
    :id :rainbow-main-container
    :style (:display :flex
            :flex-direction :row
            :height :fill
            :width :fill
            :bg-color ,(rgb '(10 10 10)))
    :children
    ,(loop for (color-name class-name rgb-val) in rainbow-colors-with-names
           collect
           `(:container
             :id ,(intern (format nil "STRIPE-~A" (string color-name)) :keyword)
             :classes (,class-name)
             :style (:width 12
                     :height :fill
                     :bg-color ,(rgb rgb-val))
             :children nil))))

;; CONTRACT ENFORCED: subscriptions(model) => [subscription]
(defsubscriptions rainbow-contracted-subscriptions (model)
  "Defines subscriptions for the rainbow app with contract enforcement.

   Current subscriptions:
   - Keyboard input (always active)
   - Optional timer for animation (if animation enabled)"

  (let ((subs nil))

    ;; Always subscribe to keyboard events
    (push (elmtui.contracts:make-subscription
           :type :keyboard
           :config '(:all-keys t)
           :message-fn (lambda (key-event) key-event))
          subs)

    ;; Optional: subscribe to timer if animation is enabled
    (when (getf model :animation-enabled)
      (push (elmtui.contracts:make-subscription
             :type :timer
             :config '(:interval 1000) ; 1 second
             :message-fn (lambda (tick) (list :animation-tick tick)))
            subs))

    ;; Return list of active subscriptions
    subs))

;;;--------------------------------------------------------------
;;; Application Definition with Contracts
;;;--------------------------------------------------------------

;; Note: This would ideally use a contract-enforced defapplication macro
;; For now, we use the existing defapplication but ensure our functions are contracted
(defapplication rainbow-contracted-example-app
  :root-viewport-id :rainbow-root-vp
  :initial-state-plist (list :current-stylesheet rainbow-contracted-stylesheet
                             :should-quit nil
                             :animation-enabled nil)
  :root-component-dsl `(:column)
  :update-fn 'rainbow-contracted-update
  :view-fn 'rainbow-contracted-view)

;;;--------------------------------------------------------------
;;; Application Validation & Testing
;;;--------------------------------------------------------------

(defun validate-rainbow-app ()
  "Validates the rainbow app against Elm Architecture contracts"
  (enable-contract-debugging t)

  (let ((test-model '(:should-quit nil
                      :current-stylesheet rainbow-contracted-stylesheet
                      :animation-enabled nil)))

    (log-info "Validating rainbow app contracts...")

    ;; This will throw contract violations if functions don't conform
    (validate-elm-application #'rainbow-contracted-update
                              #'rainbow-contracted-view
                              #'rainbow-contracted-subscriptions
                              test-model)

    (log-info "✓ All contracts validated successfully!")

    ;; Test a few specific scenarios
    (log-info "Testing update scenarios...")

    ;; Test key event handling
    (multiple-value-bind (new-model commands)
        (rainbow-contracted-update test-model (make-instance 'key-event :key #\q))
      (assert (getf new-model :should-quit) () "Key event should set quit flag")
      (assert (null commands) () "Key event should not generate commands"))

    ;; Test quit message handling
    (multiple-value-bind (new-model commands)
        (rainbow-contracted-update test-model '(:app-quit-requested))
      (assert (getf new-model :should-quit) () "Quit message should set quit flag")
      (assert (null commands) () "Quit message should not generate commands"))

    ;; Test unknown message handling
    (multiple-value-bind (new-model commands)
        (rainbow-contracted-update test-model :unknown-message)
      (assert (null new-model) () "Unknown message should return nil model")
      (assert (null commands) () "Unknown message should return nil commands"))

    (log-info "✓ All update scenarios validated!")

    ;; Test view generation
    (let ((dsl (rainbow-contracted-view test-model)))
      (assert (listp dsl) () "View should return a list")
      (assert (eq (first dsl) :container) () "Root should be container")
      (assert (getf (rest dsl) :children) () "Container should have children"))

    (log-info "✓ View generation validated!")

    ;; Test subscriptions
    (let ((subs (rainbow-contracted-subscriptions test-model)))
      (assert (listp subs) () "Subscriptions should return a list")
      (assert (every #'elmtui.contracts:subscription-p subs) () "All items should be subscriptions"))

    (log-info "✓ Subscriptions validated!")

    t))

;;;--------------------------------------------------------------
;;; Application Runner
;;;--------------------------------------------------------------

(defun run-rainbow-contracted-app (&optional validate-first)
  "Run the rainbow example application with contract enforcement.

   If validate-first is true, runs contract validation before starting the app."

  (when validate-first
    (validate-rainbow-app))

  (log-info "Starting rainbow app with contract enforcement...")

  ;; Enable contract debugging for development
  (enable-contract-debugging t)

  ;; Run the application using the platform driver
  ;; Note: This should eventually use a contract-enforced application runner
  (elmtui.platform.driver:run-app-platform
   (initialize-app-state-rainbow-contracted-app)))

;;;--------------------------------------------------------------
;;; Development & Testing Utilities
;;;--------------------------------------------------------------

(defun demo-contract-violations ()
  "Demonstrates what happens when contracts are violated"
  (enable-contract-debugging t)

  (log-info "Demonstrating contract violations...")

  ;; This should work fine
  (log-info "1. Valid update call:")
  (rainbow-contracted-update '(:should-quit nil) :test-message)

  ;; This should fail - invalid model structure
  (log-info "2. Invalid model structure (should fail):")
  (handler-case
      (rainbow-contracted-update "not-a-plist" :test-message)
    (elmtui.contracts:contract-violation (e)
      (log-info "✓ Caught expected contract violation: ~A" e)))

  ;; This would fail if we returned invalid data from update
  (log-info "3. Contract enforcement prevents runtime errors")

  t)

;; Usage examples:
;; (validate-rainbow-app)                          ; Validate contracts
;; (run-rainbow-contracted-app t)                  ; Run with validation
;; (demo-contract-violations)                      ; See contract enforcement
;; (elmtui.contracts:contract-summary)             ; View execution statistics
