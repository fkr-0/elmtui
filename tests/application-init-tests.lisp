;;;; Minimal application initialization tests
;;;; Tests basic application setup functionality

(uiop:define-package :elmtui.tests.application-init
  (:use :cl :fiveam)
  (:import-from :elmtui.app
                #:app-config
                #:app-config-name)
  (:import-from :elmtui.ui.defcomponent #:defcomponent)
  (:export #:application-init-tests #:test-component #:test-parent-component
           #:initialize-app-state-test-init-app))
(in-package :elmtui.tests.application-init)

(def-suite application-init-tests

  :in elmtui.tests:elmtui-test
  :description "Basic tests for application initialization")

(in-suite application-init-tests)

;; Basic smoke test
(test app-config-creation
  "Test that app-config can be created"
  (let ((config (elmtui.app:make-app-config :name 'test-app :message-queue (cleve-elm.core.event-channels:make-message-channel))))
    (is (eq 'test-app (app-config-name config)))))

(elmtui.ui.defcomponent:defcomponent test-component (elmtui.ui.api:component)
  (:state
   (state nil))
  (:view (local-state-map app-state id-path)
         (declare (ignore local-state-map app-state id-path))
         `(:test-component)))

(elmtui.ui.defcomponent:defcomponent test-parent-component (elmtui.ui.api:component)
  (:state
   (state :parent-default)
   (children-ids nil))
  (:init (props self-id-path)
         (let* ((parent-id (elmtui.ui.api:id-from-path self-id-path))
                (child-id (elmtui.app::generate-child-id parent-id :child1)))
           (multiple-value-bind (initialized-child child-patches child-commands)
               (elmtui.ui.api:init (make-instance 'test-component :id child-id)
                                   :id-path `(:components ,child-id)
                                   :initial-state (getf props :child-initial-state))
             (declare (ignore initialized-child))
             (values `(:state :parent-default :children-ids (,child-id))
                     (append child-patches child-commands)))))
  (:view (local-state-map app-state id-path)
         (let* ((parent-map (elmtui.state:get-path app-state id-path))
                (child-id (first (getf parent-map :children-ids)))
                (child-id-path `(:components ,child-id)))
           `(:test-parent-component
             (:child ,(elmtui.ui.api:view (elmtui.app::get-component-instance child-id-path app-state)
                                          app-state
                                          :id-path child-id-path))))))

;; Register the test components with the DSL type registry
(eval-when (:compile-toplevel :load-toplevel :execute)
  (elmtui.app.api:register-dsl-component-type :test-component 'test-component)
  (elmtui.app.api:register-dsl-component-type :test-parent-component 'test-parent-component))


;;; Test application
(defun test-init-app-view (app-state)
  (declare (ignore app-state))
  `(:column :id :main-column
    ((test-component :id :comp1 :initial-state "comp1 state"))
    ((test-parent-component :id :parent1 :child-initial-state "child state"))))

(defun test-init-app-update (message app-state)
  (declare (ignore message app-state))
  (elmtui.ui.api:make-update-result))

(defun test-init-app-subscriptions (model)
  (declare (ignore model))
  nil)

(elmtui.app:defapplication test-init-app
  :initial-state-plist `(:counter 0
                         :text "hello")
  :root-component-dsl `(:column
                        ((test-component :id :comp1 :initial-state "comp1 state"))
                        ((test-parent-component :id :parent1 :child-initial-state "child state")))
  :view-fn test-init-app-view
  :update-fn test-init-app-update
  :root-viewport-id :rv
  :subscriptions-fn test-init-app-subscriptions)

(test basic-application-initialization
  (let ((app-state (initialize-app-state-test-init-app)))
    (is (= (getf (getf app-state :application) :counter) 0))
    (is (string= (getf (getf app-state :application) :text) "hello"))

    (let ((comp1-map (getf (getf app-state :components) :comp1)))
      (is (not (null comp1-map)) "Component comp1 should be initialized.")
      (is (equal (getf comp1-map :state) "comp1 state"))
      (is (typep (elmtui.app:get-component-instance '(:components :comp1) app-state) 'test-component)))

    (let* ((parent1-map (getf (getf app-state :components) :parent1))
           (child1-id (first (getf parent1-map :children-ids))))
      (is (not (null parent1-map)) "Component parent1 should be initialized.")
      (is (equal (getf parent1-map :state) :parent-default))
      (is (typep (elmtui.app:get-component-instance '(:components :parent1) app-state) 'test-parent-component))
      (is (not (null child1-id)) "Parent1 should have a child ID.")

      (let ((child1-map (getf (getf app-state :components) child1-id)))
        (is (not (null child1-map)) "Child component parent1:child1 should be initialized.")
        (is (equal (getf child1-map :state) "child state"))
        (is (typep (elmtui.app:get-component-instance `(:components ,child1-id) app-state) 'test-component))))))

(test view-resolution-with-initialized-state
  (let* ((app-state (initialize-app-state-test-init-app))
         (view-tree (test-init-app-view app-state)))
    (is (equal view-tree
               '(:column :id :main-column
                 ((test-component :id :comp1 :initial-state "comp1 state"))
                 ((test-parent-component :id :parent1 :child-initial-state "child state")))))))
