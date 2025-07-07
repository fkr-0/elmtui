;;;; Minimal application initialization tests
;;;; Tests basic application setup functionality

(uiop:define-package :elmtui.tests.application-init
  (:use :cl :fiveam)
  (:import-from :elmtui.app
                #:app-config
                #:app-config-name)
  (:import-from :elmtui.ui.defcomponent #:defcomponent)
  (:import-from :elmtui.view.geo #:=?)
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
         (declare (ignore app-state))
         `(:text :id ,(elmtui.ui.api:id-from-path id-path)
                 :content ,(format nil "State: ~A" (getf local-state-map :state)))))

(elmtui.ui.defcomponent:defcomponent test-parent-component (elmtui.ui.api:component)
  (:state
   (state :parent-default)
   (children-ids nil))
  (:init (props self-id-path)
         (let* ((parent-id (elmtui.ui.api:id-from-path self-id-path))
                (child-id (elmtui.app::generate-child-id parent-id :child1))
                (child-initial-state (getf props :child-initial-state))
                (child-component (make-instance 'test-component :id child-id))
                (child-id-path `(:components ,child-id)))
           (multiple-value-bind (instance child-patches child-commands)
               (elmtui.ui.api:init child-component :id-path child-id-path :initial-state child-initial-state)
             (declare (ignore instance))
             (values
              `(:state :parent-default :children-ids (,child-id))
              child-patches
              child-commands))))
  (:view (local-state-map app-state id-path)
         (let* ((parent-map (elmtui.state:get-path app-state id-path))
                (child-id (first (getf parent-map :children-ids)))
                (child-id-path `(:components ,child-id)))
           `(:test-parent-component
             :id ,(elmtui.ui.api:id-from-path id-path)
             :children ((:test-component :id ,child-id))))))

;; Register the test components with the DSL type registry
(eval-when (:compile-toplevel :load-toplevel :execute)
  (elmtui.app.api:register-dsl-component-type :test-component 'test-component)
  (elmtui.app.api:register-dsl-component-type :test-parent-component 'test-parent-component))


;;; Test application
(defun test-init-app-view (app-state)
  (declare (ignore app-state))
  `(:column :id :main-column
            :children
            ((:test-component :id :comp1 :initial-state "comp1 state"))
            ((:test-parent-component :id :parent1 :child-initial-state "child state"))))

(defun test-init-app-update (message app-state)
  (declare (ignore message app-state))
  (elmtui.ui.api:make-update-result))

(defun test-init-app-subscriptions (model)
  (declare (ignore model))
  nil)

(elmtui.app:defapplication test-init-app
  :initial-state-plist `(:counter 0
                         :text "hello")
  :root-component-dsl `(:viewport :id :main-column
                                  :children
                                  ((:test-component :id :comp1 :initial-state "comp1 state")
                                   (:test-parent-component :id :parent1 :child-initial-state "child state")))
  :view-fn test-init-app-view
  :update-fn test-init-app-update
  :root-viewport-id :rv
  :subscriptions-fn test-init-app-subscriptions)

(test basic-application-initialization

  ;; (let ((app-state (initialize-app-state-test-init-app)))
  ;;   ;; (is (= (elmtui.ui.api:get-path app-state '(:counter)) 0))
  ;;   ;; (is (string= (elmtui.ui.api:get-path app-state '(:text)) "hello"))

  ;;   (let ((comp1-map2 (elmtui.ui.api:get-path app-state '(:components :comp1)))
  ;;         (comp1-map3 (elmtui.state.api:get-component-state app-state '(:components :comp1)))
  ;;         (comp1-map (elmtui.state.api:get-component-state app-state :comp1)))
  ;;     ;; (is (not (null comp1-map)) "Component comp1 should be initialized.")
  ;;     ;; comp1-map
  ;;     ;; (is (typep (elmtui.app:get-component-instance '(:components :comp1) app-state) 'test-component))
  ;;     ;; (typep (elmtui.app:get-component-instance :comp1 app-state) 'test-component)
  ;;     ;; (elmtui.app:get-component-instance 'comp1 app-state)
  ;;     ;app-state
  ;;                                       ;(elmtui.ui.api:get-path app-state '(:components :parent1))
  ;;     ))

  (let ((app-state (initialize-app-state-test-init-app)))
    (is (= (elmtui.ui.api:get-path app-state '(:counter)) 0))
    (is (string= (elmtui.ui.api:get-path app-state '(:text)) "hello"))

    (let ((comp1-map (elmtui.ui.api:get-path app-state '(:components :comp1))))
      (is (not (null comp1-map)) "Component comp1 should be initialized.")
      (is (equal (elmtui.ui.api:get-path comp1-map '(:state)) "comp1 state"))
      (is (typep (elmtui.app:get-component-instance '(:components :comp1) app-state) 'test-component)))

    (let* ((parent1-map (elmtui.ui.api:get-path app-state '(:components :parent1)))
           (child1-id (first (elmtui.ui.api:get-path parent1-map '(:children-ids)))))
      (is (not (null parent1-map)) "Component parent1 should be initialized.")
      (is (equal (elmtui.ui.api:get-path parent1-map '(:state)) :parent-default))
      (is (typep (elmtui.app:get-component-instance '(:components :parent1) app-state) 'test-parent-component))
      (is (not (null child1-id)) "Parent1 should have a child ID.")

      (let ((child1-map (elmtui.ui.api:get-path app-state `(:components ,child1-id))))
        (is (not (null child1-map)) "Child component parent1:child1 should be initialized.")
        (is (equal (elmtui.ui.api:get-path child1-map '(:state)) "child state"))
        (is (typep (elmtui.app:get-component-instance `(:components ,child1-id) app-state) 'test-component))))))

(test view-resolution-with-initialized-state
  (let* ((app-state (initialize-app-state-test-init-app))
         (view-tree (test-init-app-view app-state)))
    (is (equalp view-tree
                '(:column :id :main-column
                  :children
                  ((:test-component :id :comp1 :initial-state "comp1 state"))
                  ((:test-parent-component :id :parent1 :child-initial-state "child state")))))))
