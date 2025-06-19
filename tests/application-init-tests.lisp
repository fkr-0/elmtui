;;;; Minimal application initialization tests
;;;; Tests basic application setup functionality

(uiop:define-package :elmtui.tests.application-init
  (:use :cl :fiveam)
  (:import-from :elmtui.app.api
                #:app-config
                #:app-config-name)
  (:export #:application-init-tests))
(in-package :elmtui.tests.application-init)

(def-suite application-init-tests
  :description "Basic tests for application initialization")

(in-suite application-init-tests)

;; Basic smoke test
(test app-config-creation
  "Test that app-config can be created"
  (let ((config (make-instance 'app-config :name 'test-app)))
    (is (eq 'test-app (app-config-name config)))))

(defmethod elmtui.ui.api:view ((component test-component) &key id-path app-state)
  (declare (ignore id-path app-state))
  `(:test-component))

(defmethod elmtui.ui.api:update ((component test-component) &key id-path app-state message)
  (declare (ignore id-path app-state message))
  (elmtui.ui.api:make-update-result))

(defclass test-parent-component (elmtui.ui.api:component) ())

(defmethod elmtui.ui.api:init ((component test-parent-component) &key id-path (child-initial-state nil) &allow-other-keys)
  (let* ((parent-id (elmtui.ui.api:id-from-path id-path))
         (child-id (elmtui.app.application::generate-child-id parent-id :child1)) ; Consistent child ID generation
         (child-instance (make-instance 'test-component :id child-id))
         ;; The id-path for the child's init is its own canonical state path
         (child-id-path-for-child-init `(:components ,child-id)))
    (multiple-value-bind (initialized-child child-patches child-commands)
        (elmtui.ui.api:init child-instance
                            :id-path child-id-path-for-child-init
                            :initial-state child-initial-state)
      (declare (ignore initialized-child))
      (values component
              (append `(,(elmtui.ui.api:make-state-patch 
                          id-path ; This is `(:components <parent-id>)`
                          `(:type ,(type-of component) 
                            :id ,parent-id 
                            :state :parent-default 
                            :children-ids (,child-id)))) ; Store child ID
                      child-patches)
              child-commands))))

(defmethod elmtui.ui.api:view ((component test-parent-component) &key id-path app-state)
  (let* ((parent-map (elmtui.state:get-path app-state id-path))
         (child-id (first (getf parent-map :children-ids)))
         (child-id-path `(:components ,child-id)))
    `(:test-parent-component
      (:child ,(elmtui.ui.api:view (elmtui.app.application::get-component-instance child-id-path app-state)
                                   :id-path child-id-path
                                   :app-state app-state)))))

(defmethod elmtui.ui.api:update ((component test-parent-component) &key id-path app-state message)
  (declare (ignore id-path app-state message))
  (elmtui.ui.api:make-update-result))


;;; Test application
(elmtui.app.application:defapplication test-init-app
  :initial-state `((:counter . 0)
                   (:text . "hello"))
  :view (lambda (app-state)
          `(:column
            ((test-component :id :comp1 :initial-state "comp1 state"))
            ((test-parent-component :id :parent1 :child-initial-state "child state"))))
  :update (lambda (message app-state)
            (declare (ignore message app-state))
            (elmtui.ui.api:make-update-result))
  :event-sources ())

(test basic-application-initialization
  (let ((app-state (elmtui.app.application::initialize-application-state #'test-init-app)))
    (is (equal (elmtui.state:get-path app-state '(:application :counter)) 0))
    (is (equal (elmtui.state:get-path app-state '(:application :text)) "hello"))

    (let ((comp1-map (elmtui.state:get-path app-state '(:components :comp1))))
      (is (not (null comp1-map)) "Component comp1 should be initialized.")
      (is (equal (getf comp1-map :state) "comp1 state"))
      (is (typep (elmtui.app.application::get-component-instance '(:components :comp1) app-state) 'test-component)))

    (let* ((parent1-map (elmtui.state:get-path app-state '(:components :parent1)))
           (child1-id (first (getf parent1-map :children-ids))))
      (is (not (null parent1-map)) "Component parent1 should be initialized.")
      (is (equal (getf parent1-map :state) :parent-default))
      (is (typep (elmtui.app.application::get-component-instance '(:components :parent1) app-state) 'test-parent-component))
      (is (not (null child1-id)) "Parent1 should have a child ID.")
      (is (equal child1-id (elmtui.app.application::generate-child-id :parent1 :child1)) "Child ID should match expected generated ID.")

      (let ((child1-map (elmtui.state:get-path app-state `(:components ,child1-id))))
        (is (not (null child1-map)) "Child component parent1:child1 should be initialized.")
        (is (equal (getf child1-map :state) "child state"))
        (is (typep (elmtui.app.application::get-component-instance `(:components ,child1-id) app-state) 'test-component))))))

(test view-resolution-with-initialized-state
  (let* ((app-state (elmtui.app.application::initialize-application-state #'test-init-app))
         (view-tree (elmtui.app.application::resolve-view #'test-init-app app-state)))
    (is (equal view-tree
               '(:column
                 ((:test-component))
                 ((:test-parent-component (:child (:test-component)))))))))
