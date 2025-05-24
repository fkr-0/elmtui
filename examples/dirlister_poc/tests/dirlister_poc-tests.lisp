;;; FiveAM-based test suite for dirlister_poc
(uiop:define-package :dirlister_poc.tests
  (:use :cl :fiveam :dirlister_poc :elmtui.ui.widgets.listbox)
  (:import-from :elmtui.core.events
                #:key-event 
                #:make-key-event)
  (:export :run-dirlister-poc-tests))
(in-package :dirlister_poc.tests)

(def-suite dirlister-poc-suite
  :description "Tests for dirlister_poc application.")
(in-suite dirlister-poc-suite)

;;; Helper to extract model fields (since model is a plist)
(defun model-ref (model key)
  (getf model key))

;;; 1. Init function
(test dirlister-init
  (multiple-value-bind (model _cmds) (dirlister-init-fn)
    (is (model-ref model :listbox-state) "Listbox state should be initialized.")
    (is (model-ref model :current-path) "Current path should be initialized.")
    (is (not (model-ref model :should-quit)) "Application should not quit on init.")))

;;; 2. Directory navigation (valid directory)
(test dirlister-directory-navigation
  (multiple-value-bind (model _cmds) (dirlister-init-fn)
    (let* ((old-path (model-ref model :current-path))
           (message (list :listbox-item-selected :item ".."))
           (new-model (car (dirlister-update-fn message model))))
      (is (model-ref new-model :listbox-state) "Listbox state should update after navigation.")
      (is (not (model-ref new-model :status-message)) "Status message should be nil for valid navigation.")
      (is (not (equal (model-ref new-model :current-path) old-path)) "Path should change after navigating up."))))

;;; 3. Directory navigation (file selection)
(test dirlister-file-selection-status
  (multiple-value-bind (model _cmds) (dirlister-init-fn)
    (let* ((items (list "testfile.txt"))
           (listbox (elmtui.ui.widgets.listbox:init-listbox :main-listbox :items items :height 10 :on-select '(:listbox-item-selected)))
           (model (list :listbox-state listbox :current-path (model-ref model :current-path)))
           (message (list :listbox-item-selected :item "testfile.txt"))
           (new-model (car (dirlister-update-fn message model))))
      (is (stringp (model-ref new-model :status-message)) "Status message should be set for file selection."))))

;;; 4. Directory navigation (inaccessible item)
(test dirlister-inaccessible-item-status
  (multiple-value-bind (model _cmds) (dirlister-init-fn)
    (let* ((message (list :listbox-item-selected :item "/this/path/should/not/exist"))
           (new-model (car (dirlister-update-fn message model))))
      (is (stringp (model-ref new-model :status-message)) "Status message should be set for inaccessible item."))))

;;; 5. Terminal resize
(test dirlister-terminal-resize
  (multiple-value-bind (model _cmds) (dirlister-init-fn)
    (let* ((message (list :terminal-resized :width 100 :height 40))
           (new-model (car (dirlister-update-fn message model))))
      (is (= (model-ref new-model :terminal-width) 100) "Terminal width should update.")
      (is (= (model-ref new-model :terminal-height) 40) "Terminal height should update."))))

;;; 6. Rendering
(test dirlister-rendering
  (multiple-value-bind (model _cmds) (dirlister-init-fn)
    (is (dirlister-main-view model (lambda (&rest args) nil)) "View function should return a UI tree.")))

;;; 7. App quit logic
(test dirlister-app-quit
  (multiple-value-bind (model _cmds) (dirlister-init-fn)
    (let* ((message (list :app-quit-requested))
           (new-model (car (dirlister-update-fn message model))))
      (is (model-ref new-model :should-quit) "App should set should-quit flag on quit request."))))

;;; 8. Focus logic (focus/blur)
(test dirlister-focus-blur
  (multiple-value-bind (model _cmds) (dirlister-init-fn)
    (let* ((listbox (model-ref model :listbox-state))
           (focused (elmtui.ui.widgets.listbox:update-listbox '(:listbox-focus) listbox))
           (blurred (elmtui.ui.widgets.listbox:update-listbox '(:listbox-blur) (car focused))))
      (is (listbox-model-is-focused (car focused)) "Listbox should be focused after focus message.")
      (is (not (listbox-model-is-focused (car blurred))) "Listbox should not be focused after blur message."))))

;;; 9. Subscriptions (should return empty list)
(test dirlister-subscriptions
  (multiple-value-bind (model _cmds) (dirlister-init-fn)
    (is (equal (dirlister-subscriptions-fn model) '()) "Subscriptions function should return empty list.")))

;;; 10. Listbox key event handling (simulate up/down)
(test dirlister-listbox-key-events
  (multiple-value-bind (model _cmds) (dirlister-init-fn)
    (let* ((listbox (model-ref model :listbox-state))
           (focused-listbox (car (elmtui.ui.widgets.listbox:update-listbox '(:listbox-focus) listbox)))
           (msg-up (list :key-event :key :up))
           (msg-down (list :key-event :key :down))
           (model-focused (list :listbox-state focused-listbox :current-focus-id :main-listbox))
           (model-up (car (dirlister-update-fn msg-up model-focused)))
           (model-down (car (dirlister-update-fn msg-down model-focused))))
      (is (model-ref model-up :listbox-state) "Listbox state should update on key up.")
      (is (model-ref model-down :listbox-state) "Listbox state should update on key down."))))

;;; 11. Canonical event structure handling (struct-based key events)
(test dirlister-struct-key-events
  (multiple-value-bind (model _cmds) (dirlister-init-fn)
    (let* ((listbox (model-ref model :listbox-state))
           (focused-listbox (car (elmtui.ui.widgets.listbox:update-listbox '(:listbox-focus) listbox)))
           ;; Create canonical key event structs
           (key-up-event (make-key-event :type :key-down :key :up :modifiers nil))
           (key-down-event (make-key-event :type :key-down :key :down :modifiers nil))
           ;; Set focus and prepare model
           (model-focused (list :listbox-state focused-listbox :current-focus-id :main-listbox))
           ;; Process the key events
           (model-up (car (dirlister-update-fn key-up-event model-focused)))
           (model-down (car (dirlister-update-fn key-down-event model-focused))))
      ;; Verify the events were properly handled
      (is (model-ref model-up :listbox-state) "Listbox state should update on struct-based key up.")
      (is (model-ref model-down :listbox-state) "Listbox state should update on struct-based key down.")
      ;; Verify the results are the same as with list-based messages
      (let* ((list-msg-up (list :key-event :key :up))
             (list-model-up (car (dirlister-update-fn list-msg-up model-focused))))
        (is (equalp (model-ref model-up :listbox-state) 
                   (model-ref list-model-up :listbox-state))
            "Struct-based and list-based events should produce same results.")))))

;;; Run all tests
(defun run-dirlister-poc-tests ()
  (fiveam:run! 'dirlister-poc-suite))
