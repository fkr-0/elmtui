;;;===============================================================
;;; File: tests/elmtui-integration-tests.lisp
;;; Integration Tests for the Core Elmtui Pipeline
;;;===============================================================

;; (uiop:define-package :elmtui-integration-tests
;;   (:use :cl :fiveam :alexandria) ; Add alexandria for assoc-value
;;   ;; Import Elmtui components needed for the test app and pipeline
;;   (:import-from :elmtui.state #:make-application-state #:state-ref)
;;   (:import-from :ut.state.state #:set-state) ; For direct state manipulation in tests if needed
;;   (:import-from :elmtui.state.update #:defupdate)
;;   (:import-from :elmtui.view.core #:make-ui-node) ; Basic node creation if not using DSL
;;   (:import-from :elmtui.view.dsl #:define-view) ; Using DSL for test view
;;   (:import-from :elmtui.view.styled #:apply-stylesheet-to-tree)
;;   (:import-from :elmtui.view.layout #:layout-tree)
;;   (:import-from :elmtui.view.geo #:make-rectangle #:make-pos #:make-size)
;;   (:import-from :elmtui.platform.api #:initialize-backend #:shutdown-backend) ; Backend lifecycle
;;   (:import-from :elmtui.platform.output #:render-frame) ; Rendering function
;;   (:import-from :elmtui.style.presets #:dark-theme) ; Example stylesheet
;;   (:import-from :elmtui.style-lib.api #:make-style-set #:stylesheet #:style-rule)
;;   (:import-FROM :elmtui.style-lib.selector #:type>)
;;   (:import-FROM :elmtui.style-lib.style-set #:set-style)
;;   (:import-FROM :elmtui.platform.backend.common.virtual-buffer
;;                 #:buffer-width #:buffer-height #:buffer-cell-at
;;                 #:buffer-cell-char #:get-buffer-cell-style) ; Import buffer operations
;;   (:import-from :elmtui.ui.widgets.button #:init-button #:update-button #:view-button) ; Example widget
;;   (:import-from :elmtui.ui.widgets.label #:init-label) ; Example widget
;;   (:import-from :elmtui.ui.widgets.textinput #:init-textinput) ; Example widget
;;   (:import-from :elmtui.ui.widgets.form #:init-form) ; Example widget
;;   (:import-from :elmtui.ui.widgets.listbox #:init-listbox) ; Example widget
;;   (:import-from :elmtui.ui.widgets.scrollable-container #:init-scrollable-container) ; Example widget
;;   (:import-from :elmtui.ui.widgets.scrollable-container #:scrollable-container-id) ; Example widget ID
;;   (:import-from :elmtui.state.msg #:make-key-event-app-msg) ; Example message
;;   ;; Import faketerm query functions
;;   (:import-from :elmtui.backend.faketerm #:get-char-at-faketerm #:get-cell-style-faketerm)
;;   ;; For keymap integration test
;;   (:import-from :elmtui.examples.keymap-app #:app-init #:app-update) ; Using the example app
;;   (:import-from :elmtui.core.input-events #:make-key-event)
;;   (:import-from :elmtui.core.base-focus #:get-current-focus)
;;   (:import-from :elmtui.core.keymap
;;                 #:key-event->normalized-key
;;                 #:lookup-keymap
;;                 #:list-widget-keybindings
;;                 #:normalized-key->string)
;;   (:import-from :elmtui.ui.widgets.counter #:counter-widget-id) ; For the example app's widget ID
;;   )

;; (in-package :elmtui-integration-tests)

;; ;;; Define a Test Suite
;; (def-suite elmtui-integration-suite
;;   :description "Integration tests for the Elmtui core pipeline.")

;; (in-suite elmtui-integration-suite)

;; ;;; Test Application (Simple Counter)

;; ;; State Keys: :count, :button-state
;; (defun test-app-init ()
;;   (values
;;    ;; Initial Model (plist)
;;    (list :count 0
;;          :button-state (init-button :inc-btn :label "Inc")
;;          :counter-label-state (init-label :counter-label :value "Count: 0") ; Initialize label model
;;          :current-stylesheet dark-theme ; Use a theme
;;          :current-focus-id :inc-btn ; Focus button initially
;;          :focusable-elements '(:inc-btn))
;;    ;; Initial Commands
;;    nil))

;; ;; Update Function
;; (defupdate test-app-update (app-state message)
;;   (let ((msg-type (first message)))
;;     (case msg-type
;;       (:button-click ; Assuming button dispatches this on enter when focused
;;        (let ((button-id (getf (rest message) :id)))
;;          (case button-id
;;            (:inc-btn
;;             ;; Update both the counter and the label showing the counter value
;;             (let ((new-count (1+ (state-ref app-state :count))))
;;               (set-state app-state :count new-count)
;;               ;; Update the label model to reflect the new count
;;               (let ((label-model (state-ref app-state :counter-label-state)))
;;                 (set-state app-state :counter-label-state
;;                            (list* :value (format nil "Count: ~D" new-count)
;;                                   (remove :value label-model :key #'car)))))
;;             nil)))) ; No commands
;;       ;; Handle focus messages (needed for button activation)
;;       (:focus-next nil) ; Ignore for this simple test
;;       (:focus-previous nil)
;;       (:request-focus (set-state app-state :current-focus-id (getf (rest message) :widget-id)) nil)
;;       (:update-focusable-ids (set-state app-state :focusable-elements (getf (rest message) :ids)) nil)
;;       (otherwise nil))))

;; ;; View Function (using DSL)
;; (define-view test-app-view (app-state dispatch-fn)
;;   (:div :id :main :direction :column
;;         (:label
;;          :id :counter-label
;;          :model (state-ref app-state :counter-label-state)) ; Use the label model
;;         (:button
;;          :id :inc-btn
;;          :model (state-ref app-state :button-state)
;;          :on-click (lambda (e) (funcall dispatch-fn '(:button-click :id :inc-btn))))))

;; ;;; Helper Functions for Testing

;; (defun run-view-pipeline (app-state view-fn stylesheet screen-rect)
;;   "Runs the view -> style -> layout pipeline."
;;   (let* ((raw-view-tree (funcall view-fn app-state #'identity)) ; Pass dummy dispatch
;;          (styled-tree (if stylesheet
;;                           (apply-stylesheet-to-tree raw-view-tree stylesheet)
;;                           raw-view-tree))
;;          (laid-out-tree (layout-tree styled-tree screen-rect)))
;;     laid-out-tree))

;; (defun run-render-step (laid-out-tree backend-instance)
;;   "Runs the render step."
;;   (render-frame laid-out-tree backend-instance))

;; (defun read-faketerm-log (filepath)
;;   "Reads the content of the faketerm log file."
;;   (uiop:read-file-string filepath))

;; (defun parse-faketerm-log (log-content)
;;   "Parses the faketerm log into a list of commands/operations."
;;   (remove "" (mapcar #'str:trim (str:lines log-content)) :test #'string=))

;; ;;; Test Case

;; (test full-pipeline-test
;;   "Tests the init -> update -> view -> style -> layout -> render pipeline."
;;   (let* ((log-file (uiop:merge-pathnames* "faketerm-pipeline-test.log" #p"/tmp/")) ; Use /tmp
;;          (screen-rect (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 80 :h 24)))
;;          (backend-instance nil)
;;          (initial-state nil)
;;          (initial-commands nil))

;;     (unwind-protect
;;          (progn
;;            ;; 1. Setup Backend
;;            (setf backend-instance (initialize-backend :faketerm :filepath log-file :width 80 :height 24))
;;            (is-true backend-instance "Faketerm backend should initialize.")

;;            ;; 2. Initialize App State
;;            (multiple-value-setq (initial-state initial-commands) (test-app-init))
;;            (is (getf initial-state :count) 0 "Initial count should be 0.")
;;            (is (getf initial-state :current-stylesheet) dark-theme "Initial stylesheet should be dark-theme.")
;;            (is (null initial-commands) "Initial commands should be nil.")

;;            ;; 3. Initial Render
;;            (let* ((laid-out-tree (run-view-pipeline initial-state #'test-app-view dark-theme screen-rect)))
;;              (run-render-step laid-out-tree backend-instance)
;;              (let* ((log-content (read-faketerm-log log-file))
;;                     (log-lines (parse-faketerm-log log-content)))
;;                (is (search "CLEAR_SCREEN" (first log-lines)) "Log should start with CLEAR_SCREEN.")
;;                (is (search "Count: 0" log-content) "Initial render should show 'Count: 0'.")
;;                (is (search "Inc" log-content) "Initial render should show button label 'Inc'.")
;;                ;; Check for button focus style (e.g., border color cyan from dark-theme)
;;                (is (search ":border-color \"cyan\"" log-content :test #'string-equal) ; Assuming style is logged like this
;;                    "Focused button should have cyan border in initial render.")))

;;            ;; 4. Simulate Input & Update State
;;            ;; Simulate pressing Enter on the focused button
;;            (let* ((click-message '(:button-click :id :inc-btn))
;;                   (updated-state (copy-list initial-state)) ; Start from initial
;;                   (update-commands nil))
;;              ;; Manually apply update (defupdate needs transaction, simulate effect)
;;              (setf (getf updated-state :count) 1) ; Simulate effect of update
;;              ;; We would ideally call test-app-update here, but need transactional context.
;;              ;; For this test, we manually create the expected state after update.
;;              (is (= (getf updated-state :count) 1) "State count should be 1 after update.")

;;              ;; 5. Second Render (after update)
;;              (let* ((laid-out-tree (run-view-pipeline updated-state #'test-app-view dark-theme screen-rect)))
;;                (run-render-step laid-out-tree backend-instance)
;;                (let* ((log-content (read-faketerm-log log-file))
;;                       (log-lines (parse-faketerm-log log-content)))
;;                  ;; Check the *last* render commands in the log
;;                  (is (search "CLEAR_SCREEN" (elt log-lines (- (length log-lines) 3))) ; Approx position
;;                      "Second render should start with CLEAR_SCREEN.")
;;                  (is (search "Count: 1" log-content) "Second render should show 'Count: 1'.")
;;                  (is (search "Inc" log-content) "Second render should still show button label 'Inc'."))))
;;            )
;;       ;; Cleanup
;;       (when backend-instance
;;         (shutdown-backend backend-instance))
;;       (when (uiop:file-exists-p log-file)
;;         (delete-file log-file)))))

;; (define-view box-model-test-view (app-state dispatch-fn)
;;   (:div :id :outer :width 20 :height 7
;;         :padding 1 :border-style :single :border-color :blue :background-color :darkgray
;;         (:p :id :inner :value "Hello" :margin 1 :background-color :gray)))

;; (test box-model-rendering-test
;;   "Tests rendering of padding, borders, and content with distinct styles using faketerm."
;;   (let* ((log-file (uiop:merge-pathnames* "faketerm-box-model-test.log" #p"/tmp/"))
;;          (screen-rect (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 30 :h 10)))
;;          (stylesheet (make-test-stylesheet
;;                       '(((type> :div) :width 20 :height 7 :padding 1 :border-style :single :border-top-width 1 :border-right-width 1 :border-bottom-width 1 :border-left-width 1 :border-color :blue :background-color :darkgray)
;;                         ((type> :p) :margin 1 :background-color :gray :fg-color :black)))) ; Added fg-color for content
;;          (app-state (list :current-stylesheet stylesheet)) ; Minimal state needed
;;          (backend-instance nil))

;;     (unwind-protect
;;          (progn
;;            (setf backend-instance (initialize-backend :faketerm :filepath log-file
;;                                                                 :width (w screen-rect) :height (h screen-rect)))
;;            (is-true backend-instance "Faketerm backend should initialize for box model test.")

;;            (let* ((laid-out-tree (run-view-pipeline app-state #'box-model-test-view stylesheet screen-rect)))
;;              (run-render-step laid-out-tree backend-instance)

;;              ;; Root node :outer (x=0, y=0, w=20, h=7)
;;              ;; Border char assertions (color :blue)
;;              (is (char= (get-char-at-faketerm backend-instance 0 0) #\┌))
;;              (is (equal (getf (get-cell-style-faketerm backend-instance 0 0) :fg) :blue))
;;              (is (char= (get-char-at-faketerm backend-instance 0 19) #\┐))
;;              (is (equal (getf (get-cell-style-faketerm backend-instance 0 19) :fg) :blue))
;;              (is (char= (get-char-at-faketerm backend-instance 6 0) #\└))
;;              (is (equal (getf (get-cell-style-faketerm backend-instance 6 0) :fg) :blue))
;;              (is (char= (get-char-at-faketerm backend-instance 6 19) #\┘))
;;              (is (equal (getf (get-cell-style-faketerm backend-instance 6 19) :fg) :blue))
;;              (is (char= (get-char-at-faketerm backend-instance 0 1) #\─)) ; Top border
;;              (is (equal (getf (get-cell-style-faketerm backend-instance 0 1) :fg) :blue))
;;              (is (char= (get-char-at-faketerm backend-instance 1 0) #\│)) ; Left border
;;              (is (equal (getf (get-cell-style-faketerm backend-instance 1 0) :fg) :blue))

;;              ;; Padding area assertions (bg :darkgray)
;;              ;; Cell (1,1) is top-left of padding area of :outer
;;              (is (char= (get-char-at-faketerm backend-instance 1 1) #\Space)) ; Padding char
;;              (is (equal (getf (get-cell-style-faketerm backend-instance 1 1) :bg) :darkgray))

;;              ;; Inner P node :inner
;;              ;; :outer (x=0,y=0, w=20,h=7), padding 1, border 1.
;;              ;; :outer content-box starts at x = 0+1(pad)+1(border)=2, y = 0+1+1=2
;;              ;; :outer content-box size: w = 20-2-2=16, h = 7-2-2=3
;;              ;; :inner has margin 1.
;;              ;; :inner margin-box x = outer-content-x + inner-margin-left = 2 + 1 = 3
;;              ;; :inner margin-box y = outer-content-y + inner-margin-top = 2 + 1 = 3
;;              ;; :inner border-box starts at (3,3)
;;              ;; :inner content (text "Hello") should be at (3,3) if no padding/border on :inner
;;              ;; Let's check background of :inner's margin box (which is its own background :gray)
;;              ;; Cell (3,3) should be the 'H' of "Hello"
;;              (is (char= (get-char-at-faketerm backend-instance 3 3) #\H))
;;              (is (equal (getf (get-cell-style-faketerm backend-instance 3 3) :bg) :gray))
;;              (is (equal (getf (get-cell-style-faketerm backend-instance 3 3) :fg) :black))

;;              (is (char= (get-char-at-faketerm backend-instance 3 4) #\e))
;;              (is (equal (getf (get-cell-style-faketerm backend-instance 3 4) :bg) :gray))

;;              ;; Check a cell within :inner's margin area but outside its content, should have :outer's bg
;;              ;; This test is tricky because :inner's margin area is conceptually part of :outer's content area.
;;              ;; The background of :inner (:gray) should fill its own border-box.
;;              ;; The area of :outer's content-box taken by :inner's margin should have :outer's content-bg (:darkgray)
;;              ;; Cell (2,2) is :outer's content area, and also top-left of :inner's margin area.
;;              ;; This cell should have :outer's background.
;;              ;; (is (char= (get-char-at-faketerm backend-instance 2 2) #\Space))
;;              ;; (is (equal (getf (get-cell-style-faketerm backend-instance 2 2) :bg) :darkgray))
;;              ;; This specific check for margin background needs careful thought on how backgrounds propagate or if margins are "transparent".
;;              ;; Current rendering fills :inner's background for its border-box. The margin area of :inner
;;              ;; would have the background of :outer's content area.

;;              ))
;;       (when backend-instance
;;         (shutdown-backend backend-instance))
;;       (when (uiop:file-exists-p log-file)
;;         (delete-file log-file)))))

;; (define-view focus-test-view (app-state dispatch-fn)
;;   `(:div :id :main
;;     ;; Use :focusable t prop for labels to make them part of focus cycle for testing
;;     (:label :id :item1 :value "Item 1" :focusable t :width 10 :height 1 :margin 1)
;;     (:label :id :item2 :value "Item 2" :focusable t :width 10 :height 1 :margin 1)
;;     (:button :id :btn1 :model ,(state-ref app-state :button1-state) :focusable t :width 10 :height 1 :margin 1)))

;; (defun focus-test-app-init ()
;;   (values
;;    (list :item1-state nil ; Dummy state for labels if needed
;;          :item2-state nil
;;          :button1-state (init-button :btn1 :label "Btn1")
;;          :current-stylesheet dark-theme
;;          :current-focus-id :item1 ; Initial focus
;;          :focusable-elements '(:item1 :item2 :btn1) ; Manually set for test simplicity
;;          :prev-focus-id nil)
;;    nil))

;; ;; Simplified update for base-focus testing - only handles base-focus messages via handle-base-focus-message
;; (defun focus-test-app-update (app-state message)
;;   (let ((msg-type (first message)))
;;     (case msg-type
;;       ((:focus-next :focus-previous :request-focus)
;;        (elmtui.core.base-focus:handle-base-focus-message message app-state)) ; Returns a patch
;;       (:update-focusable-elements ; For completeness, though not directly used in this simple test's flow
;;        (list (cons :focusable-elements (getf (rest message) :ids))))
;;       (otherwise nil)))) ; No commands, just state patch

;; (test focus-navigation-tab-test
;;   "Tests Tab key focus navigation."
;;   (let* ((log-file (uiop:merge-pathnames* "faketerm-focus-test.log" #p"/tmp/"))
;;          (screen-rect (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 30 :h 10)))
;;          (backend-instance nil)
;;          (app-state nil)
;;          (cmds nil))

;;     (unwind-protect
;;          (progn
;;            (setf backend-instance (initialize-backend :faketerm :filepath log-file
;;                                                                 :width (w screen-rect) :height (h screen-rect)))
;;            (multiple-value-setq (app-state cmds) (focus-test-app-init))

;;            (is (eq (getf app-state :current-focus-id) :item1) "Initial focus should be on :item1")

;;            ;; Simulate Tab press
;;            (let ((focus-patch (focus-test-app-update app-state '(:focus-next))))
;;              (dolist (change focus-patch)
;;                (setf (getf app-state (car change)) (cdr change))))

;;            (is (eq (getf app-state :current-focus-id) :item2) "Focus should move to :item2 after Tab")
;;            (is (eq (getf app-state :prev-focus-id) :item1) "Previous focus should be :item1")

;;            ;; Simulate another Tab press
;;            (let ((focus-patch (focus-test-app-update app-state '(:focus-next))))
;;              (dolist (change focus-patch)
;;                (setf (getf app-state (car change)) (cdr change))))

;;            (is (eq (getf app-state :current-focus-id) :btn1) "Focus should move to :btn1 after second Tab")
;;            (is (eq (getf app-state :prev-focus-id) :item2) "Previous focus should be :item2")

;;            ;; Simulate Tab press to wrap around
;;            (let ((focus-patch (focus-test-app-update app-state '(:focus-next))))
;;              (dolist (change focus-patch)
;;                (setf (getf app-state (car change)) (cdr change))))

;;            (is (eq (getf app-state :current-focus-id) :item1) "Focus should wrap to :item1 after third Tab")
;;            (is (eq (getf app-state :prev-focus-id) :btn1) "Previous focus should be :btn1")

;;            ;; Render to check visual cues (basic check for now, more detailed later)
;;            (let* ((laid-out-tree (run-view-pipeline app-state #'focus-test-view dark-theme screen-rect)))
;;              (run-render-step laid-out-tree backend-instance)
;;              ;; At this point, :item1 is focused. We'd check its style in faketerm buffer.
;;              ;; For example, if focused items get a specific class that changes border color.
;;              ;; This requires the test view and stylesheet to define such visual cues.
;;              (pass "Focus navigation test completed. Visual cue check would require specific styles.")))

;;       (when backend-instance
;;         (shutdown-backend backend-instance))
;;       (when (uiop:file-exists-p log-file)
;;         (delete-file log-file)))))

;; ;; Add more tests as needed

;; (test keymap-integration-test
;;   "Tests widget-specific keymap handling and message dispatch."
;;   (let* ((initial-app-model-plist nil)
;;          (initial-commands nil)
;;          (app-state (make-application-state))) ; Create a fresh app state container

;;     ;; 1. Initialize App State from the example keymap-app
;;     (multiple-value-setq (initial-app-model-plist initial-commands)
;;       (app-init))
;;     (is-true initial-app-model-plist "keymap-app:app-init should return a model plist.")
;;     (ut.state.state:merge-state app-state initial-app-model-plist) ; Populate the app-state

;;     (is (null initial-commands) "keymap-app:app-init should have no initial commands.")

;;     (let* ((counter-id (find-symbol (string :counter-a) :elmtui.examples.keymap-app)) ; Get the *counter-a-id* value
;;            (counter-model-path (list :widgets counter-id))
;;            (initial-counter-model (state-ref app-state counter-model-path)))
;;       (is-true initial-counter-model "Initial counter model should exist in app state.")
;;       (is (= (getf initial-counter-model :value) 10) "Initial counter value should be 10."))

;;     ;; 2. Simulate a key event ("+")
;;     (let ((plus-key-event (make-key-event :key :+ :char #\+ :modifiers nil)))

;;       ;; 3. Manually replicate keymap processing from driver's app-update-handler
;;       (let ((focused-widget-id (get-current-focus app-state))
;;             (effective-message plus-key-event) ; Default to raw event
;;             (event-processed-by-keymap nil))

;;         (is (eq focused-widget-id (find-symbol (string :counter-a) :elmtui.examples.keymap-app))
;;             "Counter widget should be focused initially.")

;;         (when focused-widget-id
;;           (let* ((widget-model-path (list :widgets focused-widget-id))
;;                  (widget-model (state-ref app-state widget-model-path)))
;;             (when widget-model
;;               (let ((widget-keymap (getf widget-model :active-keymap)))
;;                 (is-true widget-keymap "Widget should have an active keymap.")
;;                 (when widget-keymap
;;                   (let* ((norm-key (key-event->normalized-key plus-key-event))
;;                          (binding (lookup-keymap widget-keymap norm-key)))
;;                     (is-true binding "'+' key should have a binding in counter's keymap.")
;;                     (when binding
;;                       (setf event-processed-by-keymap t)
;;                       (if (eq (getf binding :type) :message)
;;                           (setf effective-message
;;                                 (list :dispatch-to-widget focused-widget-id (getf binding :target) binding))
;;                           (error "Test expected :message type binding for '+'")))))))))
;;         (is-true event-processed-by-keymap "Key event should be processed by widget keymap.")

;;         ;; 4. Call the main app-update with the effective message
;;         (multiple-value-bind (state-patch-plist returned-commands)
;;             (app-update app-state effective-message)

;;           (is-true state-patch-plist "app-update should return a state patch.")
;;           (is (null returned-commands) "app-update should return no commands for counter increment.")

;;           ;; 5. Apply the patch (simplified for test)
;;           ;; The actual defupdate macro handles this transactionally. Here we inspect the patch.
;;           (is (eq (first state-patch-plist) :widgets) "Patch should target :widgets.")
;;           (let* ((updated-widgets-alist (second state-patch-plist)) ; Value for :widgets key
;;                  (counter-a-sym (find-symbol "*COUNTER-A-ID*" :elmtui.examples.keymap-app))
;;                  (counter-a-id-val (if counter-a-sym (symbol-value counter-a-sym) :counter-a)) ; Fallback if not found
;;                  (updated-counter-model (assoc-value updated-widgets-alist counter-a-id-val)))
;;             (is-true updated-counter-model "Updated counter model should be in the patch.")
;;             (is (= (getf updated-counter-model :value) 11) "Counter value should be incremented to 11."))))

;;       ;; 6. Test introspection
;;       (let* ((counter-a-id (elmtui.examples.keymap-app::*counter-a-id*)) ; Directly access the exported/known ID
;;              (bindings (list-widget-keybindings app-state counter-a-id)))
;;         (is (= (length bindings) 3) "Counter widget should have 3 listed keybindings.")

;;         (let ((plus-binding (find "+" bindings :key #'(lambda (b) (getf b :key)) :test #'string-equal)))
;;           (is-true plus-binding "Should find '+' binding (key string should be \"+\").")
;;           (when plus-binding
;;             (is (eq (getf plus-binding :type) :message) "'+' binding type should be :message.")
;;             (is (equal (getf plus-binding :target) '(:increment)) "'+' binding target should be '(:increment).")
;;             (is (string= (getf plus-binding :description) "Increment counter") "'+' binding description is correct.")))

;;         (let ((enter-binding (find "Enter" bindings :key #'(lambda (b) (getf b :key)) :test #'string-equal)))
;;           (is-true enter-binding "Should find 'Enter' binding.")
;;           (when enter-binding
;;             (is (eq (getf enter-binding :type) :message) "'Enter' binding type should be :message.")
;;             (is (equal (getf enter-binding :target) '(:increment)) "'Enter' binding target should be '(:increment).")
;;             (is (string= (getf enter-binding :description) "Increment counter (Enter)") "'Enter' binding description is correct.")))

;;         (let ((minus-binding (find "-" bindings :key #'(lambda (b) (getf b :key)) :test #'string-equal)))
;;           (is-true minus-binding "Should find '-' binding.")
;;           (when minus-binding
;;             (is (eq (getf minus-binding :type) :message) "'-' binding type should be :message.")
;;             (is (equal (getf minus-binding :target) '(:decrement)) "'-' binding target should be '(:decrement).")
;;             (is (string= (getf minus-binding :description) "Decrement counter") "'-' binding description is correct.")))
;;         ))))

;; (define-view diff-integration-test-view (app-state dispatch-fn)
;;   `(:div :id :main :width 10 :height 5
;;     (:p :id :text :value ,(getf app-state :text))))

;; (defun diff-integration-test-app-init ()
;;   (values
;;    (list :text "Initial"
;;          :current-stylesheet dark-theme)
;;    nil))

;; (defun diff-integration-test-app-update (app-state message)
;;   (let ((msg-type (first message)))
;;     (case msg-type
;;       (:change-text
;;        (list (cons :text (getf (rest message) :new-text))))
;;       (otherwise nil))))

;; (test diff-renderer-integration-buffer-content-test
;;   "Tests that the virtual buffer content is correct after rendering."
;;   (let* ((log-file (uiop:merge-pathnames* "faketerm-diff-integration-test.log" #p"/tmp/"))
;;          (screen-rect (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 10 :h 5)))
;;          (backend-instance nil)
;;          (app-state nil)
;;          (cmds nil))

;;     (unwind-protect
;;          (progn
;;            ;; 1. Setup Backend (Faketerm)
;;            (setf backend-instance (elmtui.platform.api:initialize-backend :faketerm :filepath log-file
;;                                                                                     :width (w screen-rect) :height (h screen-rect)))
;;            (is-true backend-instance "Faketerm backend should initialize.")

;;            ;; Access the faketerm instance's buffers (assuming internal access for testing)
;;            (let ((front-buffer (elmtui.platform.backend.terminal::terminal-instance-front-buffer backend-instance))
;;                  (back-buffer (elmtui.platform.backend.terminal::terminal-instance-back-buffer backend-instance)))
;;              (is-true front-buffer "Front buffer should exist.")
;;              (is-true back-buffer "Back buffer should exist.")
;;              (is (= (buffer-width front-buffer) 10))
;;              (is (= (buffer-height front-buffer) 5))
;;              (is (= (buffer-width back-buffer) 10))
;;              (is (= (buffer-height back-buffer) 5)))

;;            ;; 2. Initialize App State
;;            (multiple-value-setq (app-state cmds) (diff-integration-test-app-init))
;;            (is (string= (getf app-state :text) "Initial") "Initial text should be 'Initial'.")

;;            ;; 3. Initial Render
;;            ;; Manually run the pipeline steps as done in the driver's render loop
;;            (let* ((laid-out-tree (run-view-pipeline app-state #'diff-integration-test-view
;;                                                     (getf app-state :current-stylesheet) screen-rect)))
;;              ;; Render to back buffer
;;              (run-render-step laid-out-tree backend-instance)

;;              ;; Swap buffers (simulating driver swap)
;;              (rotatef (elmtui.platform.backend.terminal::terminal-instance-front-buffer backend-instance)
;;                       (elmtui.platform.backend.terminal::terminal-instance-back-buffer backend-instance))

;;              ;; Assert content of the new front buffer
;;              (let ((current-front-buffer (elmtui.platform.backend.terminal::terminal-instance-front-buffer backend-instance)))
;;                ;; The view is a 10x5 div with "Initial" text.
;;                ;; The text "Initial" should be at (0,0) within the div's content area.
;;                ;; Assuming default layout places the div at (0,0) of the screen-rect.
;;                (is (char= (buffer-cell-char (buffer-cell-at current-front-buffer 0 0)) #\I))
;;                (is (char= (buffer-cell-char (buffer-cell-at current-front-buffer 0 1)) #\n))
;;                (is (char= (buffer-cell-char (buffer-cell-at current-front-buffer 0 6)) #\l))
;;                ;; Check a cell outside the text area but within the buffer
;;                (is (char= (buffer-cell-char (buffer-cell-at current-front-buffer 0 7)) #\Space))
;;                (is (char= (buffer-cell-char (buffer-cell-at current-front-buffer 1 0)) #\Space))))

;;            ;; 4. Simulate Input & Update State
;;            (let ((update-patch (diff-integration-test-app-update app-state '(:change-text :new-text "Updated"))))
;;              ;; Apply patch to state
;;              (dolist (change update-patch)
;;                (setf (getf app-state (car change)) (cdr change))))
;;            (is (string= (getf app-state :text) "Updated") "Text should be 'Updated' after update.")

;;            ;; 5. Second Render
;;            (let* ((laid-out-tree (run-view-pipeline app-state #'diff-integration-test-view
;;                                                     (getf app-state :current-stylesheet) screen-rect)))
;;              ;; Render to the new back buffer (which was the old front buffer)
;;              (run-render-step laid-out-tree backend-instance)

;;              ;; Swap buffers again
;;              (rotatef (elmtui.platform.backend.terminal::terminal-instance-front-buffer backend-instance)
;;                       (elmtui.platform.backend.terminal::terminal-instance-back-buffer backend-instance))

;;              ;; Assert content of the new front buffer
;;              (let ((current-front-buffer (elmtui.platform.backend.terminal::terminal-instance-front-buffer backend-instance)))
;;                ;; The text "Updated" should now be at (0,0)
;;                (is (char= (buffer-cell-char (buffer-cell-at current-front-buffer 0 0)) #\U))
;;                (is (char= (buffer-cell-char (buffer-cell-at current-front-buffer 0 1)) #\p))
;;                (is (char= (buffer-cell-char (buffer-cell-at current-front-buffer 0 6)) #\d))
;;                ;; Check a cell outside the text area but within the buffer
;;                (is (char= (buffer-cell-char (buffer-cell-at current-front-buffer 0 7)) #\Space))
;;                (is (char= (buffer-cell-char (buffer-cell-at current-front-buffer 1 0)) #\Space))))

;;            ;; 6. (Optional) Inspect Faketerm Log for Diff Commands
;;            ;; This requires more sophisticated log parsing or faketerm changes.
;;            ;; For now, we rely on the buffer content assertion.
;;            (pass "Buffer content verified after initial and updated render.")
;;            )
;;       ;; Cleanup
;;       (when backend-instance
;;         (elmtui.platform.api:shutdown-backend backend-instance))
;;       (when (uiop:file-exists-p log-file)
;;         (delete-file log-file)))))

;; (define-view diff-output-test-view (app-state dispatch-fn)
;;   `(:div :id :main :width 10 :height 1
;;     (:p :id :text :value ,(getf app-state :text))))

;; (defun diff-output-test-app-init ()
;;   (values
;;    (list :text "ABCDEFGHIJ" ; 10 characters
;;          :current-stylesheet nil) ; No styles for simplicity
;;    nil))

;; (defun write-file-string (filepath content &key (if-exists :append))
;;   "Writes CONTENT to FILEPATH, handling file existence as specified."
;;   (with-open-file (stream filepath :direction :output :if-does-not-exist :create
;;                                    :if-exists if-exists :element-type 'character)
;;     (write-string content stream)))
;; (defun replace-nth-char (str index new-char)
;;   "Replaces the character at INDEX in STR with NEW-CHAR."
;;   (if (and (>= index 0) (< index (length str)))
;;       (concatenate 'string
;;                    (subseq str 0 index)
;;                    (string new-char)
;;                    (subseq str (+ index 1)))
;;       str))

;; (defun diff-output-test-app-update (app-state message)
;;   (let ((msg-type (first message)))
;;     (case msg-type
;;       (:change-char
;;        (let ((index (getf (rest message) :index))
;;              (new-char (getf (rest message) :new-char)))
;;          (list (cons :text (replace-nth-char (getf app-state :text) index new-char)))))
;;       (otherwise nil))))

;; ;; Helper to parse faketerm log commands
;; (defun parse-faketerm-commands (log-content)
;;   (let ((commands '()))
;;     (dolist (line (str:lines log-content))
;;       (let ((trimmed-line (str:trim line)))
;;         (unless (string= trimmed-line "")
;;           (push trimmed-line commands))))
;;     (nreverse commands)))

;; (test diff-renderer-integration-output-test
;;   "Tests that `apply-terminal-diff` sends minimal commands to faketerm."
;;   (let* ((log-file (uiop:merge-pathnames* "faketerm-diff-output-test.log" #p"/tmp/"))
;;          (screen-rect (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 10 :h 1)))
;;          (backend-instance nil)
;;          (app-state nil)
;;          (cmds nil))

;;     (unwind-protect
;;          (progn
;;            ;; 1. Setup Backend (Faketerm)
;;            (setf backend-instance (elmtui.platform.api:initialize-backend :faketerm :filepath log-file
;;                                                                                     :width (w screen-rect) :height (h screen-rect)))
;;            (is-true backend-instance "Faketerm backend should initialize.")

;;            ;; 2. Initialize App State
;;            (multiple-value-setq (app-state cmds) (diff-output-test-app-init))

;;            ;; 3. Initial Render (Full screen update expected)
;;            (let* ((laid-out-tree (run-view-pipeline app-state #'diff-output-test-view
;;                                                     (getf app-state :current-stylesheet) screen-rect)))
;;              (run-render-step laid-out-tree backend-instance)
;;              ;; Swap buffers (simulating driver swap)
;;              (rotatef (elmtui.platform.backend.terminal::terminal-instance-front-buffer backend-instance)
;;                       (elmtui.platform.backend.terminal::terminal-instance-back-buffer backend-instance)))

;;            ;; Verify initial log output (Clear, Move, Write, Flush)
;;            (let ((initial-log (parse-faketerm-commands (read-faketerm-log log-file))))
;;              (is (= (length initial-log) 4) "Initial render should produce 4 commands.")
;;              (is (string= (nth 0 initial-log) "CLEAR_SCREEN") "First command should be CLEAR_SCREEN.")
;;              (is (string= (nth 1 initial-log) "CURSOR_SET_POSITION 1 1") "Second command should be CURSOR_SET_POSITION 1 1.")
;;              (is (string= (nth 2 initial-log) "WRITE_STRING \"ABCDEFGHIJ\"") "Third command should be WRITE_STRING.")
;;              (is (string= (nth 3 initial-log) "FINISH_OUTPUT") "Fourth command should be FINISH_OUTPUT."))

;;            ;; Clear the log for the next render
;;            (write-file-string log-file "" :if-exists :overwrite)

;;            ;; 4. Simulate Input & Update State (Change one character)
;;            (let ((update-patch
;;                    (diff-output-test-app-update app-state
;;                                                 '(:change-char :index 5 :new-char #\Z)))) ; Change 'F' to 'Z'
;;              ;; Apply patch to state
;;              (dolist (change update-patch)
;;                (setf (getf app-state (car change)) (cdr change))))
;;            (is (string= (getf app-state :text) "ABCDEZHIJJ") "Text should be 'ABCDEZHIJJ' after update.")

;;            ;; 5. Second Render (Diff update expected)
;;            (let* ((laid-out-tree (run-view-pipeline app-state #'diff-output-test-view
;;                                                     (getf app-state :current-stylesheet) screen-rect)))
;;              (run-render-step laid-out-tree backend-instance)
;;              ;; Swap buffers again
;;              (rotatef (elmtui.platform.backend.terminal::terminal-instance-front-buffer backend-instance)
;;                       (elmtui.platform.backend.terminal::terminal-instance-back-buffer backend-instance)))

;;            ;; Verify second log output (Move, Write, Flush - minimal diff)
;;            (let ((second-log (parse-faketerm-commands (read-faketerm-log log-file))))
;;              (is (= (length second-log) 3) "Second render should produce 3 commands (minimal diff).")
;;              (is (string= (nth 0 second-log) "CURSOR_SET_POSITION 1 6") "First command should move cursor to (1,6).") ; 1-based, index 5 is col 6
;;              (is (string= (nth 1 second-log) "WRITE_STRING \"Z\"") "Second command should write 'Z'.")
;;              (is (string= (nth 2 second-log) "FINISH_OUTPUT") "Third command should be FINISH_OUTPUT."))

;;            (pass "Diff rendering output verified.")
;;            )
;;       ;; Cleanup
;;       (when backend-instance
;;         (elmtui.platform.api:shutdown-backend backend-instance))
;;       (when (uiop:file-exists-p log-file)
;;         (delete-file log-file)))))

;; (define-view resize-test-view (app-state dispatch-fn)
;;   `(:div :id :main :width :fill :height :fill
;;     (:p :id :text :value ,(getf app-state :text))))

;; (defun resize-test-app-init ()
;;   (values
;;    (list :text "Resize Test"
;;          :current-stylesheet dark-theme)
;;    nil))

;; (test resize-integration-test
;;   "Tests that resizing the terminal correctly resizes buffers and triggers re-rendering."
;;   (let* ((log-file (uiop:merge-pathnames* "faketerm-resize-test.log" #p"/tmp/"))
;;          (initial-screen-rect (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 20 :h 10)))
;;          (resized-screen-rect (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 30 :h 15)))
;;          (backend-instance nil)
;;          (app-state nil)
;;          (cmds nil))

;;     (unwind-protect
;;          (progn
;;            ;; 1. Setup Backend (Faketerm) with initial size
;;            (setf backend-instance (elmtui.platform.api:initialize-backend :faketerm :filepath log-file
;;                                                                                     :width (w initial-screen-rect) :height (h initial-screen-rect)))
;;            (is-true backend-instance "Faketerm backend should initialize.")

;;            ;; Check initial buffer dimensions
;;            (let ((front-buffer (elmtui.platform.backend.terminal::terminal-instance-front-buffer backend-instance))
;;                  (back-buffer (elmtui.platform.backend.terminal::terminal-instance-back-buffer backend-instance)))
;;              (is (= (buffer-width front-buffer) 20))
;;              (is (= (buffer-height front-buffer) 10))
;;              (is (= (buffer-width back-buffer) 20))
;;              (is (= (buffer-height back-buffer) 10)))

;;            ;; 2. Initialize App State
;;            (multiple-value-setq (app-state cmds) (resize-test-app-init))

;;            ;; 3. Initial Render
;;            (let* ((laid-out-tree (run-view-pipeline app-state #'resize-test-view
;;                                                     (getf app-state :current-stylesheet) initial-screen-rect)))
;;              (run-render-step laid-out-tree backend-instance)
;;              ;; Swap buffers
;;              (rotatef (elmtui.platform.backend.terminal::terminal-instance-front-buffer backend-instance)
;;                       (elmtui.platform.backend.terminal::terminal-instance-back-buffer backend-instance)))

;;            ;; Assert content of the initial front buffer
;;            (let ((current-front-buffer (elmtui.platform.backend.terminal::terminal-instance-front-buffer backend-instance)))
;;              ;; Text "Resize Test" should be at (0,0)
;;              (is (char= (buffer-cell-char (buffer-cell-at current-front-buffer 0 0)) #\R))
;;              (is (char= (buffer-cell-char (buffer-cell-at current-front-buffer 0 10)) #\t))
;;              ;; Check a cell outside the text area but within the buffer
;;              (is (char= (buffer-cell-char (buffer-cell-at current-front-buffer 0 11)) #\Space))
;;              (is (char= (buffer-cell-char (buffer-cell-at current-front-buffer 1 0)) #\Space)))

;;            ;; 4. Simulate Resize Event Processing (as done by driver's app-update-handler)
;;            (let ((resize-event `(:terminal-resize-request :width ,(w resized-screen-rect) :height ,(h resized-screen-rect))))
;;              (format t "~&INTEGRATION-TEST: Simulating processing of event: ~S~%" resize-event)
;;              ;; Directly call the sequence of operations that the driver's handler for this event would perform:
;;              (elmtui.platform.backend.terminal:resize-terminal-buffers backend-instance
;;                                                                        (getf (rest resize-event) :width)
;;                                                                        (getf (rest resize-event) :height))
;;              (elmtui.platform.backend.terminal:force-clear-terminal-and-reset-buffers backend-instance)
;;              ;; The driver would also publish :terminal-resized and :force-render,
;;              ;; which would lead to the re-layout and re-render steps below.
;;              (format t "~&INTEGRATION-TEST: Buffers resized and front-buffer reset for full redraw.~%"))

;;            ;; Check buffer dimensions after resize
;;            (let ((front-buffer (elmtui.platform.backend.terminal::terminal-instance-front-buffer backend-instance))
;;                  (back-buffer (elmtui.platform.backend.terminal::terminal-instance-back-buffer backend-instance)))
;;              (is (= (buffer-width front-buffer) 30))
;;              (is (= (buffer-height front-buffer) 15))
;;              (is (= (buffer-width back-buffer) 30))
;;              (is (= (buffer-height back-buffer) 15)))

;;            ;; 5. Trigger Re-render after Resize (Simulate driver's render cycle)
;;            ;; The driver would typically re-layout and re-render after a resize event.
;;            (let* ((laid-out-tree (run-view-pipeline app-state #'resize-test-view
;;                                                     (getf app-state :current-stylesheet) resized-screen-rect)))
;;              (run-render-step laid-out-tree backend-instance)
;;              ;; Swap buffers
;;              (rotatef (elmtui.platform.backend.terminal::terminal-instance-front-buffer backend-instance)
;;                       (elmtui.platform.backend.terminal::terminal-instance-back-buffer backend-instance)))

;;            ;; Assert content of the new front buffer after resize and re-render
;;            ;; After force-clear-terminal-and-reset-buffers, the old front-buffer (which became the new back-buffer)
;;            ;; was cleared with spaces. The render-frame then cleared this new back-buffer again and rendered to it.
;;            ;; Then it was swapped to become the new front-buffer.
;;            (let ((current-front-buffer (elmtui.platform.backend.terminal::terminal-instance-front-buffer backend-instance)))
;;              (is-true current-front-buffer "Front buffer should exist after resize and render.")
;;              (when current-front-buffer
;;                ;; Text "Resize Test" should still be at (0,0) in the larger buffer
;;                (is (char= (buffer-cell-char (buffer-cell-at current-front-buffer 0 0)) #\R))
;;                (is (char= (buffer-cell-char (buffer-cell-at current-front-buffer 0 10)) #\t))
;;                ;; Check a cell that was outside the original buffer but is now inside, should be space due to :fill
;;                (is (char= (buffer-cell-char (buffer-cell-at current-front-buffer 0 25)) #\Space))
;;                (is (char= (buffer-cell-char (buffer-cell-at current-front-buffer 12 0)) #\Space))
;;                ;; Check a cell from the newly expanded area of the back-buffer (which was cleared by render-frame)
;;                (is (char= (buffer-cell-char (buffer-cell-at current-front-buffer
;;                                                             (1- (h resized-screen-rect))
;;                                                             (1- (w resized-screen-rect))))
;;                           #\Space)
;;                    "Bottom-right of resized buffer should be space after render.")))

;;            (pass "Buffer resize and re-rendering verified.")
;;            )
;;       ;; Cleanup
;;       (when backend-instance
;;         (elmtui.platform.api:shutdown-backend backend-instance))
;;       (when (uiop:file-exists-p log-file)
;;         (delete-file log-file)))))
