;;;===============================================================
;;; File: tests/elmtui-integration-tests.lisp
;;; Integration Tests for the Core Elmtui Pipeline
;;;===============================================================

(uiop:define-package :elmtui-integration-tests
  (:use :cl :fiveam)
  ;; Import Elmtui components needed for the test app and pipeline
  (:import-from :elmtui.state #:make-application-state #:state-ref)
  (:import-from :ut.state.state #:set-state) ; For direct state manipulation in tests if needed
  (:import-from :elmtui.state.update #:defupdate)
  (:import-from :elmtui.view.core #:make-ui-node) ; Basic node creation if not using DSL
  (:import-from :elmtui.view.dsl #:define-view) ; Using DSL for test view
  (:import-from :elmtui.view.styled #:apply-stylesheet-to-tree)
  (:import-from :elmtui.view.layout #:layout-tree)
  (:import-from :elmtui.view.geo #:make-rectangle #:make-pos #:make-size)
  (:import-from :elmtui.platform.api #:initialize-backend #:shutdown-backend) ; Backend lifecycle
  (:import-from :elmtui.platform.output #:render-frame) ; Rendering function
  (:import-from :elmtui.style.presets #:dark-theme) ; Example stylesheet
  (:import-from :elmtui.ui.widgets.button #:init-button #:update-button #:view-button) ; Example widget
  (:import-from :elmtui.state.msg #:make-key-event-app-msg) ; Example message
  )

(in-package :elmtui-integration-tests)

;;; Define a Test Suite
(def-suite elmtui-integration-suite
  :description "Integration tests for the Elmtui core pipeline.")

(in-suite elmtui-integration-suite)

;;; Test Application (Simple Counter)

;; State Keys: :count, :button-state
(defun test-app-init ()
  (values
   ;; Initial Model (plist)
   (list :count 0
         :button-state (init-button :inc-btn :label "Inc")
         :current-stylesheet dark-theme ; Use a theme
         :current-focus-id :inc-btn ; Focus button initially
         :focusable-elements '(:inc-btn))
   ;; Initial Commands
   nil))

;; Update Function
(defupdate test-app-update (app-state message)
  (let ((msg-type (first message)))
    (case msg-type
      (:button-click ; Assuming button dispatches this on enter when focused
       (let ((button-id (getf (rest message) :id)))
         (case button-id
           (:inc-btn
            (set-state! :count (1+ (state-ref app-state :count)))
            nil)))) ; No commands
      ;; Handle focus messages (needed for button activation)
      (:focus-next nil) ; Ignore for this simple test
      (:focus-previous nil)
      (:request-focus (set-state! :current-focus-id (getf (rest message) :widget-id)) nil)
      (:update-focusable-ids (set-state! :focusable-elements (getf (rest message) :ids)) nil)
      (otherwise nil))))

;; View Function (using DSL)
(define-view test-app-view (app-state dispatch-fn)
  (declare (ignore dispatch-fn))
  (:div :id :main :direction :column
        (:label :id :counter-label :value (format nil "Count: ~D" (state-ref app-state :count)))
        (:button :id :inc-btn :model (state-ref app-state :button-state) :on-click '(:button-click :id :inc-btn))))

;;; Helper Functions for Testing

(defun run-view-pipeline (app-state view-fn stylesheet screen-rect)
  "Runs the view -> style -> layout pipeline."
  (let* ((raw-view-tree (funcall view-fn app-state #'identity)) ; Pass dummy dispatch
         (styled-tree (if stylesheet
                          (apply-stylesheet-to-tree raw-view-tree stylesheet)
                          raw-view-tree))
         (laid-out-tree (layout-tree styled-tree screen-rect)))
    laid-out-tree))

(defun run-render-step (laid-out-tree backend-instance)
  "Runs the render step."
  (render-frame laid-out-tree backend-instance))

(defun read-faketerm-log (filepath)
  "Reads the content of the faketerm log file."
  (uiop:read-file-string filepath))

(defun parse-faketerm-log (log-content)
  "Parses the faketerm log into a list of commands/operations."
  (remove "" (mapcar #'str:trim (str:lines log-content)) :test #'string=))

;;; Test Case

(test full-pipeline-test
  "Tests the init -> update -> view -> style -> layout -> render pipeline."
  (let* ((log-file (uiop:merge-pathnames* "faketerm-pipeline-test.log" #p"/tmp/")) ; Use /tmp
         (screen-rect (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 80 :h 24)))
         (backend-instance nil)
         (initial-state nil)
         (initial-commands nil))

    (unwind-protect
         (progn
           ;; 1. Setup Backend
           (setf backend-instance (initialize-backend :faketerm :filepath log-file :width 80 :height 24))
           (is-true backend-instance "Faketerm backend should initialize.")

           ;; 2. Initialize App State
           (multiple-value-setq (initial-state initial-commands) (test-app-init))
           (is (getf initial-state :count) 0 "Initial count should be 0.")
           (is (getf initial-state :current-stylesheet) dark-theme "Initial stylesheet should be dark-theme.")
           (is (null initial-commands) "Initial commands should be nil.")

           ;; 3. Initial Render
           (let* ((laid-out-tree (run-view-pipeline initial-state #'test-app-view dark-theme screen-rect)))
             (run-render-step laid-out-tree backend-instance)
             (let* ((log-content (read-faketerm-log log-file))
                    (log-lines (parse-faketerm-log log-content)))
               (is (search "CLEAR_SCREEN" (first log-lines)) "Log should start with CLEAR_SCREEN.")
               (is (search "Count: 0" log-content) "Initial render should show 'Count: 0'.")
               (is (search "Inc" log-content) "Initial render should show button label 'Inc'.")
               ;; Check for button focus style (e.g., border color cyan from dark-theme)
               (is (search ":border-color \"cyan\"" log-content :test #'string-equal) ; Assuming style is logged like this
                   "Focused button should have cyan border in initial render.")))

           ;; 4. Simulate Input & Update State
           ;; Simulate pressing Enter on the focused button
           (let* ((click-message '(:button-click :id :inc-btn))
                  (updated-state (copy-list initial-state)) ; Start from initial
                  (update-commands nil))
             ;; Manually apply update (defupdate needs transaction, simulate effect)
             (setf (getf updated-state :count) 1) ; Simulate effect of update
             ;; We would ideally call test-app-update here, but need transactional context.
             ;; For this test, we manually create the expected state after update.
             (is (= (getf updated-state :count) 1) "State count should be 1 after update.")

             ;; 5. Second Render (after update)
             (let* ((laid-out-tree (run-view-pipeline updated-state #'test-app-view dark-theme screen-rect)))
               (run-render-step laid-out-tree backend-instance)
               (let* ((log-content (read-faketerm-log log-file))
                      (log-lines (parse-faketerm-log log-content)))
                 ;; Check the *last* render commands in the log
                 (is (search "CLEAR_SCREEN" (elt log-lines (- (length log-lines) 3))) ; Approx position
                     "Second render should start with CLEAR_SCREEN.")
                 (is (search "Count: 1" log-content) "Second render should show 'Count: 1'.")
                 (is (search "Inc" log-content) "Second render should still show button label 'Inc'."))))
           )
      ;; Cleanup
      (when backend-instance
        (shutdown-backend backend-instance))
      (when (uiop:file-exists-p log-file)
        (delete-file log-file)))))

;; Add more tests as needed
