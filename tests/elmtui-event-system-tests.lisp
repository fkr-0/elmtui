;;;===============================================================
;;; File: tests/elmtui-event-system-tests.lisp
;;; Integration Tests for the Event System Implementation
;;;===============================================================

(uiop:define-package :elmtui-event-system-tests
  (:use :cl :fiveam :alexandria)
  ;; Import event system components
  (:import-from :elmtui.core.event-types
                #:ui-event
                #:make-ui-event
                #:ui-event-p
                #:ui-event-type
                #:ui-event-target
                #:ui-event-timestamp
                #:ui-event-consumed-p
                #:ui-event-original-event
                #:ui-event-stop-propagation
                #:key-event
                #:make-key-event
                #:key-event-p
                #:key-event-type
                #:key-event-key
                #:key-event-code
                #:key-event-modifiers
                #:mouse-event
                #:make-mouse-event
                #:mouse-event-p
                #:mouse-event-type
                #:mouse-event-x
                #:mouse-event-y
                #:mouse-event-button)
  (:import-from :elmtui.view.styled #:make-styled-node)
  (:import-from :elmtui.core.event-propagation
                #:capture-phase
                #:target-phase
                #:bubble-phase
                #:dispatch-event
                #:traverse-ui-tree-up
                #:traverse-ui-tree-down)
  (:import-from :elmtui.core.focus
                #:make-focus-manager
                #:focus-manager-current-focus
                #:focus-manager-focusable-elements
                #:focus-manager-focus-history
                #:set-focus
                #:get-next-focusable
                #:get-previous-focusable
                #:recalculate-focusable-elements)
  (:import-from :elmtui.core.event-async
                #:debounce
                #:throttle
                #:delay-event
                #:schedule-repeating-event)
  (:import-from :elmtui.view.dsl #:define-view) ; Using DSL for test view
  (:import-from :elmtui.core.conditions
                #:event-validation-error))

(in-package :elmtui-event-system-tests)

(def-suite event-system-tests
  :description "Tests for the event system implementation")

(in-suite event-system-tests)

;;;-----------------------------------------------------------------------------
;;; Event Type Tests
;;;-----------------------------------------------------------------------------

(test create-ui-event
  "Test creation and access of base UI events"
  (let ((event (make-ui-event :type :test-event
                              :target :test-widget
                              :timestamp 12345)))
    (is (ui-event-p event) "Should be a UI event")
    (is (eq (ui-event-type event) :test-event) "Type should match")
    (is (eq (ui-event-target event) :test-widget) "Target should match")
    (is (= (ui-event-timestamp event) 12345) "Timestamp should match")
    (is (not (ui-event-consumed-p event)) "Event should not be consumed by default")))

(test create-key-event
  "Test creation and access of key events"
  (let ((key-event (make-key-event :type :key-down
                                   :key :enter
                                   :code 13
                                   :modifiers '(:control))))
    (is (key-event-p key-event) "Should be a key event")
    (is (eq (key-event-type key-event) :key-down) "Type should match")
    (is (eq (key-event-key key-event) :enter) "Key should match")
    (is (= (key-event-code key-event) 13) "Code should match")
    (is (equal (key-event-modifiers key-event) '(:control)) "Modifiers should match")))

(test create-mouse-event
  "Test creation and access of mouse events"
  (let ((mouse-event (make-mouse-event :type :mouse-down
                                       :x 100
                                       :y 200
                                       :button :left
                                       :click-count 1)))
    (is (mouse-event-p mouse-event) "Should be a mouse event")
    (is (eq (mouse-event-type mouse-event) :mouse-down) "Type should match")
    (is (= (mouse-event-x mouse-event) 100) "X coordinate should match")
    (is (= (mouse-event-y mouse-event) 200) "Y coordinate should match")
    (is (eq (mouse-event-button mouse-event) :left) "Button should match")))

(test event-validation
  "Test event validation functions"
  (let ((valid-key (make-key-event :type :key-down :key :a))
        (valid-mouse (make-mouse-event :type :mouse-move :x 0 :y 0))
        (invalid-key (make-key-event :type :invalid-type :key :a)))
    (is-true (elmtui.core.event-types::valid-key-event-p valid-key)
             "Valid key event should pass validation")
    (is-true (elmtui.core.event-types::valid-mouse-event-p valid-mouse)
             "Valid mouse event should pass validation")))

;;;-----------------------------------------------------------------------------
;;; Event Propagation Tests
;;;-----------------------------------------------------------------------------
;; (make-styled-node :type :button
;;                   :props '(:id :button-1 :focusable t)
;;                   :children nil)
(defun create-test-ui-tree ()
  "Create a simple UI tree for testing event propagation"
  (let* ((leaf1 (make-styled-node :type :button

                                  :props '(:id :button1 :focusable t)
                                  :children nil))
         (leaf2 (make-styled-node :type :button
                                  :props '(:id :button2 :focusable t)
                                  :children nil))
         (container (make-styled-node :type :div
                                      :props '(:id :container)
                                      :children (list leaf1 leaf2)))
         (root (make-styled-node :type :div
                                 :props '(:id :root)
                                 :children (list container))))
    (values root container leaf1 leaf2)))

(test traverse-ui-tree
  "Test UI tree traversal functions"
  (multiple-value-bind (root container button1 button2)
      (create-test-ui-tree)

    ;; Test downward traversal
    (let ((path (traverse-ui-tree-down root :button1)))
      (is (= (length path) 3) "Path should include three nodes")
      (is (eq (getf (first path) :id) :root) "First node should be root")
      (is (eq (getf (second path) :id) :container) "Second node should be container")
      (is (eq (getf (third path) :id) :button1) "Third node should be button1"))

    ;; Test upward traversal
    (let ((path (traverse-ui-tree-up button1 root)))
      (is (= (length path) 3) "Path should include three nodes")
      (is (eq (getf (first path) :id) :button1) "First node should be button1")
      (is (eq (getf (second path) :id) :container) "Second node should be container")
      (is (eq (getf (third path) :id) :root) "Third node should be root"))))

(defun make-test-handler (phase name consumed)
  "Create a test event handler that tracks execution"
  (let ((called nil))
    (lambda (event)
      (setf called t)
      (when consumed
        (ui-event-stop-propagation event))
      (list :handler name :phase phase :called called))))

(test event-propagation-phases
  "Test event capturing, target, and bubbling phases"
  (multiple-value-bind (root container button1 button2)
      (create-test-ui-tree)

    ;; Set up handlers
    (let ((root-capture (make-test-handler :capture :root nil))
          (container-capture (make-test-handler :capture :container nil))
          (button-capture (make-test-handler :capture :button nil))
          (button-target (make-test-handler :target :button nil))
          (container-bubble (make-test-handler :bubble :container nil))
          (root-bubble (make-test-handler :bubble :root nil))
          (event (make-ui-event :type :test-event :target :button1))
          (execution-order nil))

      ;; Attach handlers to nodes
      (setf (getf root :on-capture) root-capture)
      (setf (getf container :on-capture) container-capture)
      (setf (getf button1 :on-capture) button-capture)
      (setf (getf button1 :on-event) button-target)
      (setf (getf container :on-bubble) container-bubble)
      (setf (getf root :on-bubble) root-bubble)

      ;; Dispatch event through all phases
      (dispatch-event root event)

      ;; Check that handlers were called in correct order
      (is-true (first (funcall root-capture nil)) "Root capture handler should be called")
      (is-true (first (funcall container-capture nil)) "Container capture handler should be called")
      (is-true (first (funcall button-capture nil)) "Button capture handler should be called")
      (is-true (first (funcall button-target nil)) "Button target handler should be called")
      (is-true (first (funcall container-bubble nil)) "Container bubble handler should be called")
      (is-true (first (funcall root-bubble nil)) "Root bubble handler should be called"))))

(test stop-propagation
  "Test that stop-propagation works correctly"
  (multiple-value-bind (root container button1 button2)
      (create-test-ui-tree)

    ;; Set up handlers with one that stops propagation
    (let ((root-capture (make-test-handler :capture :root nil))
          (container-capture (make-test-handler :capture :container t)) ; This one stops propagation
          (button-target (make-test-handler :target :button nil))
          (event (make-ui-event :type :test-event :target :button1)))

      ;; Attach handlers to nodes
      (setf (getf root :on-capture) root-capture)
      (setf (getf container :on-capture) container-capture)
      (setf (getf button1 :on-event) button-target)

      ;; Dispatch event
      (dispatch-event root event)

      ;; Root capture should be called, container capture should stop propagation,
      ;; button target should not be called
      (is-true (first (funcall root-capture nil)) "Root capture handler should be called")
      (is-true (first (funcall container-capture nil)) "Container capture handler should be called")
      (is-false (first (funcall button-target nil)) "Button target handler should not be called"))))

;;;-----------------------------------------------------------------------------
;;; Focus Management Tests
;;;-----------------------------------------------------------------------------

(test focus-manager-creation
  "Test creation of the focus manager"
  (let ((fm (make-focus-manager)))
    (is (null (focus-manager-current-focus fm)) "Initial focus should be nil")
    (is (null (focus-manager-focusable-elements fm)) "Initial focusable elements list should be empty")
    (is (null (focus-manager-focus-history fm)) "Initial focus history should be empty")))

(test focus-management
  "Test focus operations"
  (multiple-value-bind (root container button1 button2)
      (create-test-ui-tree)
    (let ((fm (make-focus-manager)))

      ;; Calculate focusable elements
      (recalculate-focusable-elements fm root)
      (is (= (length (focus-manager-focusable-elements fm)) 2) "Should have found 2 focusable elements")

      ;; Set focus to first button
      (set-focus fm :button1)
      (is (eq (focus-manager-current-focus fm) :button1) "Focus should be set to button1")

      ;; Move to next focusable
      (let ((next (get-next-focusable fm :button1)))
        (is (eq next :button2) "Next focusable after button1 should be button2")
        (set-focus fm next))
      (is (eq (focus-manager-current-focus fm) :button2) "Focus should be set to button2")

      ;; Move back to previous
      (let ((prev (get-previous-focusable fm :button2)))
        (is (eq prev :button1) "Previous focusable before button2 should be button1")
        (set-focus fm prev))
      (is (eq (focus-manager-current-focus fm) :button1) "Focus should be set back to button1")

      ;; Check focus history
      (is (= (length (focus-manager-focus-history fm)) 2) "Focus history should have 2 entries"))))

;;;-----------------------------------------------------------------------------
;;; Async Infrastructure Tests
;;;-----------------------------------------------------------------------------

(test debounce
  "Test debounce function"
  (let* ((counter 0)
         (increment (lambda () (incf counter)))
         (debounced (debounce increment 100))) ; 100ms debounce

    ;; Call multiple times in rapid succession
    (funcall debounced)
    (funcall debounced)
    (funcall debounced)

    ;; Should not have incremented yet
    (is (= counter 0) "Counter should not increment immediately")

    ;; Wait for debounce period
    (sleep 0.2) ; 200ms

    ;; Should have incremented once
    (is (= counter 1) "Counter should increment once after debounce period")))

(test throttle
  "Test throttle function"
  (let* ((counter 0)
         (increment (lambda () (incf counter)))
         (throttled (throttle increment 100))) ; 100ms throttle

    ;; Call multiple times in rapid succession
    (funcall throttled)
    (funcall throttled)
    (funcall throttled)

    ;; Should have incremented once
    (is (= counter 1) "Counter should increment once immediately")

    ;; Wait for throttle period
    (sleep 0.2) ; 200ms

    ;; Call again after throttle period
    (funcall throttled)

    ;; Should have incremented again
    (is (= counter 2) "Counter should increment again after throttle period")))

(test delay-and-schedule
  "Test delay-event and schedule-repeating-event"
  (let* ((events '())
         (event-handler (lambda (event) (push event events)))
         (test-event (make-ui-event :type :test-event)))

    ;; Schedule delayed event
    (delay-event test-event 100 )
    (is (= (length events) 0) "No events should be handled immediately")

    ;; Wait for delay
    (sleep 0.2) ; 200ms

    ;; Event should be handled
    (is (= (length events) 1) "One event should be handled after delay")

    ;; Clear events
    (setf events '())

    ;; Schedule repeating event (3 repetitions, 100ms apart)
    (schedule-repeating-event test-event 100 3 event-handler)

    ;; Wait for all repetitions
    (sleep 0.5) ; 500ms

    ;; Should have 3 events
    (is (= (length events) 3) "Three events should be handled from repeating schedule")))

;;;-----------------------------------------------------------------------------
;;; Run Tests
;;;-----------------------------------------------------------------------------
