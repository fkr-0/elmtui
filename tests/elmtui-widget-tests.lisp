;;;===============================================================
;;; File: tests/elmtui-widget-tests.lisp
;;; Basic Tests for Elm-style Widgets
;;;===============================================================
(defpackage :elmtui-widget-tests
  (:use :cl :fiveam :alexandria)
  (:import-from :elmtui.view.core #:ui-node #:ui-node-p)
  ;; Import widget packages
  (:import-from :elmtui.ui.widgets.button
                #:init-button #:update-button #:view-button #:button-model)
  (:import-from :elmtui.ui.widgets.label
                #:init-label #:update-label #:view-label #:label-model)
  (:import-from :elmtui.ui.widgets.textinput
                #:init-textinput #:update-textinput #:view-textinput #:textinput-model
                #:msg-textinput-key-press #:msg-textinput-focus #:msg-textinput-blur)
  (:import-from :elmtui.ui.widgets.form
                #:init-form #:update-form #:view-form #:form-model
                #:msg-form-child-update #:msg-form-submit)
  (:import-from :elmtui.ui.widgets.listbox
                #:init-listbox #:update-listbox #:view-listbox #:listbox-model
                #:msg-listbox-key-press #:msg-listbox-select-index #:msg-listbox-focus #:msg-listbox-blur))

(in-package :elmtui-widget-tests)

(def-suite widget-tests :description "Basic tests for Elm-style widgets.")
(in-suite widget-tests)

;; Dummy dispatch function for view tests
(defun dummy-dispatch (msg)
  (format t "~&[Dummy Dispatch] Received: ~S~%" msg))

;;;--- Button Tests ---
(test button-widget-basic
  (multiple-value-bind (model cmd) (init-button :my-button :label "Click Me" :on-click-msg '(:button-clicked))
    (is (typep model 'button-model))
    (is (null cmd))
    (let ((view-node (view-button model #'dummy-dispatch)))
      (is (ui-node-p view-node))
      (is (eq (getf (ui-node-props view-node) :widget-id) :my-button)))
    (multiple-value-bind (new-model cmd) (update-button :click model)
      (is (typep new-model 'button-model))
      (is (listp cmd)) ; Expecting a command list like '((:async #'send-message (:button-clicked)))
      )))

;;;--- Label Tests ---
(test label-widget-basic
  (multiple-value-bind (model cmd) (init-label :my-label :text "Hello World")
    (is (typep model 'label-model))
    (is (null cmd))
    (let ((view-node (view-label model #'dummy-dispatch)))
      (is (ui-node-p view-node))
      (is (eq (getf (ui-node-props view-node) :widget-id) :my-label))
      (is (string= (getf (ui-node-props view-node) :value) "Hello World")))
    (multiple-value-bind (new-model cmd) (update-label :some-message model) ; Labels ignore messages
      (is (eq new-model model)) ; Should return the same model
      (is (null cmd)))))

;;;--- TextInput Tests ---
(test textinput-widget-basic
  (multiple-value-bind (model cmd) (init-textinput :my-input :placeholder "Enter text" :on-change '(:input-changed))
    (is (typep model 'textinput-model))
    (is (null cmd))
    (let ((view-node (view-textinput model #'dummy-dispatch)))
      (is (ui-node-p view-node))
      (is (eq (getf (ui-node-props view-node) :widget-id) :my-input)))
    ;; Test focus/blur
    (multiple-value-bind (focused-model cmd1) (update-textinput msg-textinput-focus model)
      (is (textinput-model-is-focused focused-model))
      (is (null cmd1))
      (multiple-value-bind (blurred-model cmd2) (update-textinput msg-textinput-blur focused-model)
        (is (not (textinput-model-is-focused blurred-model)))
        (is (null cmd2))))
    ;; Test key press (requires focus)
    (multiple-value-bind (focused-model) (update-textinput msg-textinput-focus model)
      (multiple-value-bind (updated-model cmd) (update-textinput (list msg-textinput-key-press :key '(:char #\a :key-sym :a)) focused-model)
        (is (string= (textinput-model-value updated-model) "a"))
        (is (= (textinput-model-cursor-pos updated-model) 1))
        (is (equalp cmd '((:input-changed :value "a")))))))) ; Check on-change command

;;;--- Form Tests ---
(test form-widget-basic
  (let* ((child-specs `((:id :name :type :textinput :init-args (:placeholder "Name"))
                       (:id :submit :type :button :init-args (:label "Go" :on-click-msg msg-form-submit))))
         (form-id :my-form))
    (multiple-value-bind (model cmd) (init-form form-id :child-specs child-specs :on-submit '(:form-submitted))
      (is (typep model 'form-model))
      (is (null cmd)) ; Assuming child inits don't produce commands here
      (is (= (hash-table-count (form-model-children-models model)) 2))
      (is (typep (gethash :name (form-model-children-models model)) 'textinput-model))
      (is (typep (gethash :submit (form-model-children-models model)) 'button-model))

      (let ((view-node (view-form model #'dummy-dispatch)))
        (is (ui-node-p view-node))
        (is (eq (getf (ui-node-props view-node) :widget-id) form-id))
        (is (= (length (ui-node-children view-node)) 2)))

      ;; Test child update delegation
      (let ((child-msg (list msg-textinput-key-press :key '(:char #\x :key-sym :x))))
        (multiple-value-bind (updated-model commands) (update-form (list msg-form-child-update :child-id :name :child-msg child-msg) model)
          (is (string= (textinput-model-value (gethash :name (form-model-children-models updated-model))) "x"))
          (is (null commands)))) ; Assuming textinput on-change is nil for this test init

      ;; Test form submit via button message
      (let ((button-click-msg '(:click))) ; Button's internal message for click
        (multiple-value-bind (updated-model commands) (update-form (list msg-form-child-update :child-id :submit :child-msg button-click-msg) model)
          (is (equal commands '((:form-submitted))))))))) ; Check form's on-submit command

;;;--- ListBox Tests ---
(test listbox-widget-basic
  (multiple-value-bind (model cmd) (init-listbox :my-list :items '("A" "B" "C") :on-select '(:item-selected))
    (is (typep model 'listbox-model))
    (is (null cmd))
    (is (equal (listbox-model-items model) '("A" "B" "C")))

    (let ((view-node (view-listbox model #'dummy-dispatch)))
      (is (ui-node-p view-node))
      (is (eq (getf (ui-node-props view-node) :widget-id) :my-list))
      (is (= (length (ui-node-children view-node)) 3)))

    ;; Test selection update
    (multiple-value-bind (updated-model commands) (update-listbox (list msg-listbox-select-index :index 1) model)
      (is (= (listbox-model-selected-index updated-model) 1))
      (is (equal commands '((:item-selected :index 1 :item "B")))))

    ;; Test keyboard navigation (requires focus)
    (multiple-value-bind (focused-model) (update-listbox msg-listbox-focus model)
      (multiple-value-bind (updated-model commands) (update-listbox (list msg-listbox-key-press :key '(:key-sym :down)) focused-model)
        (is (= (listbox-model-selected-index updated-model) 0)) ; Selects first item if none selected
        (is (equal commands '((:item-selected :index 0 :item "A"))))))))

;;; Run tests (if running file directly)
;;; (run! 'widget-tests)