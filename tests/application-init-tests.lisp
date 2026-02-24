;;;; Minimal application initialization tests
;;;; Tests basic application setup functionality

(uiop:define-package :elmtui.tests.application-init
  (:use :cl :fiveam)
  (:import-from :elmtui.app
    #:app-config
    #:app-config-name)
  (:import-from :elmtui.ui.defcomponent #:defcomponent)
  (:import-from :elmtui.ui.dsl-resolution #:dsl-type)
  (:import-from #:elmtui.state #:get-path #:state-ref)
  (:import-from :elmtui.view.geo #:=?)
  (:export #:application-init-tests #:app-init-test-component #:app-init-test-parent-component
    #:initialize-app-state-test-init-app))
(in-package :elmtui.tests.application-init)
;; Register the test components with the DSL type registry

(defparameter +app-init-test-component-dsl+ :app-init-test-component)
(defparameter +app-init-test-parent-component-dsl+ :app-init-test-parent-component)

;;; Test application
(defun test-init-app-view (app-state)
  (declare (ignore app-state))
  '(:column :id :main-column
     :children
     ((:app-init-test-component :id :comp1 :initial-state "comp1 state")
      (:app-init-test-parent-component :id :parent1 :child-initial-state "child state"))))

(defun test-init-app-update (message app-state)
  (declare (ignore message app-state))
  (elmtui.ui.api:make-update-result))

(defun test-init-app-subscriptions (model)
  (declare (ignore model))
  nil)
(elmtui.ui.defcomponent:defcomponent app-init-test-component (elmtui.ui.api:component)
  (:state
    (state nil))
  (:view (local-state-map app-state id-path children)
    ;; (declare (ignore app-state))
    `(:text :id ,(elmtui.ui.api:id-from-path id-path)
       :content ,(format nil "State: ~A" (gethash :state local-state-map)))))

(elmtui.ui.defcomponent:defcomponent app-init-test-parent-component (elmtui.ui.api:component)
  (:state
    (state :parent-default)
    (children-ids nil))
  (:init (props self-id-path)
    (let* ((parent-id (elmtui.ui.api:id-from-path self-id-path))
            (child-id (elmtui.app::generate-child-id parent-id :child1))
            (child-initial-state (getf props :child-initial-state))
            (child-component (make-instance 'app-init-test-component :id child-id))
            (child-id-path `(:components ,child-id)))
      (multiple-value-bind (instance child-patches child-commands)
        (elmtui.ui.api:init child-component :id-path child-id-path :initial-state child-initial-state)
        (declare (ignore instance))
        (values
          `(:state :parent-default :children-ids (,child-id))
          child-patches
          child-commands))))
  (:view (local-state-map app-state id-path children)
    (let* ((parent-map (elmtui.state:get-path id-path app-state))
            (child-id (first (gethash :children-ids parent-map)))
            ;; (child-id-path `(:components ,child-id))
            )
      `(:test-parent-component
         :id ,(elmtui.ui.api:id-from-path id-path)
         :children ((:app-init-test-component :id ,child-id))))))
(eval-when (:compile-toplevel :load-toplevel :execute)

  (elmtui.app:defapplication test-init-app
    :initial-state-plist `(:counter 0
                            :text "hello")
    :root-component-dsl '(;; :root-viewport :id :main-column passes
                           :root-viewport :id :main-column ;; fails
                           :initial-terminal-dimensions (1 1)
                           :initial-cursor-pos (1 1)
                           :children
                           ((:app-init-test-component :id :comp1 :initial-state "comp1 state")
                            (:app-init-test-parent-component :id :parent1 :child-initial-state "child state")))
    :view-fn test-init-app-view
    :update-fn test-init-app-update
    :root-viewport-id :rv
    :subscriptions-fn test-init-app-subscriptions)

  ;; (elmtui.ui.api:initialize-components-from-dsl
  ;;   '(:root-viewport :id :main-column :initial-terminal-dimensions (1 1)
  ;;      :initial-cursor-pos (1 1) :children
  ;;      ((:test-component :id :comp1 :initial-state "comp1 state")
  ;;        (:test-parent-component :id :parent1 :child-initial-state
  ;;          "child state"))))

  ;; Register DSL types for test components using the new polymorphic system
  (defmethod dsl-type ((type (eql :app-init-test-component)) &optional props)
    (values 'app-init-test-component props))
  (defmethod dsl-type ((type (eql :app-init-test-parent-component)) &optional props)
    (values 'app-init-test-parent-component props)))
(def-suite application-init-tests

  :in elmtui.tests:elmtui-test
  :description "Basic tests for application initialization")

(in-suite application-init-tests)

;; Basic smoke test
(test app-config-creation
  "Test that app-config can be created"
  (let ((config (elmtui.app:make-app-config :name 'test-app :message-queue (elmtui.core.event-channels:make-message-channel))))
    (is (eq 'test-app (app-config-name config)))))





;; (elmtui.ui.api:initialize-components-from-dsl
;;  '(:root-viewport :id :rv :initial-terminal-dimensions (1 1)
;;    :initial-cursor-pos (1 1) :children
;;    (:container :id :main-column :initial-terminal-dimensions (1 1)
;;                :initial-cursor-pos (1 1) :initial-child-spec
;;     ((:test-component :id :comp1 :initial-state "comp1 state")
;;      (:test-parent-component :id :parent1 :child-initial-state
;;       "child state"))
;;     :children
;;     ((:test-component :id :comp1 :initial-state "comp1 state")
;;      (:test-parent-component :id :parent1 :child-initial-state
;;       "child state")))))
;; (elmtui.ui.api:initialize-components-from-dsl
;;  '(:root-viewport :id :rv :initial-terminal-dimensions (1 1)
;;    :initial-cursor-pos (1 1) :children
;;    (:container :id :main-column :initial-terminal-dimensions (1 1)
;;                :initial-cursor-pos (1 1) :initial-child-spec
;;     ((:test-component :id :comp1 :initial-state "comp1 state")
;;      (:test-parent-component :id :parent1 :child-initial-state
;;       "child state"))
;;     :children
;;     ((:test-component :id :comp1 :initial-state "comp1 state")
;;      (:test-parent-component :id :parent1 :child-initial-state
;;       "child state")))))
(elmtui.app:defapplication test-init-app-2
  :initial-state-plist `(:counter 0
                          :text "hello")
  :root-component-dsl '(;;:root-viewport :id :main-column
                         ;; :viewport :id :main-column ;; fails
                         :container :id :main-column ;; fails
                         :initial-terminal-dimensions (1 1)
                         :initial-cursor-pos (1 1)
                         :initial-child-spec
                         ((:app-init-test-component :id :comp1 :initial-state "comp1 state")
                          (:app-init-test-parent-component :id :parent1 :child-initial-state "child state"))
                         :children
                         ((:app-init-test-component :id :comp1 :initial-state "comp1 state")
                          (:app-init-test-parent-component :id :parent1 :child-initial-state "child state")))
  :view-fn test-init-app-view
  :update-fn test-init-app-update
  :root-viewport-id :rv
  :subscriptions-fn test-init-app-subscriptions)
;; (let ((app-state (initialize-app-state-test-init-app)))
;;   ;; (is (= (elmtui.ui.api:get-path '(:counter) app-state) 0))
;;   ;; (is (string= (elmtui.ui.api:get-path '(:text) app-state) "hello"))

;;   (let ((comp1-map2 (elmtui.ui.api:get-path '(:components :comp1)) app-state)
;;         (comp1-map3 (elmtui.state.api:get-component-state app-state '(:components :comp1)))
;;         (comp1-map (elmtui.state.api:get-component-state app-state :comp1)))
;;     ;; (is (not (null comp1-map)) "Component comp1 should be initialized.")
;;     ;; comp1-map
;;     ;; (is (typep (elmtui.app:get-component-instance '(:components :comp1) app-state) 'test-component))
;;     ;; (typep (elmtui.app:get-component-instance :comp1 app-state) 'test-component)
;;     ;; (elmtui.app:get-component-instance 'comp1 app-state)
;;     ;app-state
;;                                       ;(elmtui.ui.api:get-path '(:components :parent1) app-state)
;;     ))
;; (elmtui.ui.api:component-state-path)
;; (elmtui.ui.api:component-state-map-path)

(test basic-application-initialization-2
  (multiple-value-bind (app-state commands)
    (initialize-app-state-test-init-app-2)
    (declare (ignore commands))
    (let ((app-data (elmtui.state:application-state-data app-state)))
      ;; app-data))
      (is (= (gethash :counter app-data) 0))
      (is (string= (gethash :text app-data) "hello")))))

(test basic-application-initialization
  (multiple-value-bind (app-state commands)
    (initialize-app-state-test-init-app)
    (declare (ignore commands))
    ;; (print app-state)
    (let ((app-data (elmtui.state:application-state-data app-state)))
      ;; app-data))
      ;; (print (elmtui.state.api:pprinc-application-state app-state))))
      ;; app-state))
      ;; app-state))
      ;; (elmtui.app:get-component-instance '(:main-column :comp1) app-state)))
      ;; (state-ref app-state (list :components :components :main-column )) app-state))
      (is (= (gethash :counter app-data) 0))
      (is (string= (gethash :text app-data) "hello"))

      (let ((comp1-map (elmtui.state:get-path '(:components :main-column :comp1) (elmtui.state:application-state-data app-state))))
        (is (not (null comp1-map)))
        (is (equal (get-path :state comp1-map) "comp1 state"))
        (is (typep (elmtui.app:get-component-instance '(:main-column :comp1) app-state) 'app-init-test-component)))

      (let* ((parent1-map (elmtui.state:get-path '(:components :main-column :parent1) (elmtui.state:application-state-data app-state)))
              (child1-id (first (gethash :children-ids parent1-map))))
        (is (not (null parent1-map)))
        (is (equal (gethash :state parent1-map) :parent-default))
        (is (typep (elmtui.app:get-component-instance '(:main-column :parent1) app-state) 'app-init-test-parent-component))
        (is (not (null child1-id)))

        (let ((child1-map (elmtui.state:get-path (list :components child1-id) (elmtui.state:application-state-data app-state))))
          (is (not (null child1-map)))
          (is (equal (gethash :state child1-map) "child state"))
          (is (typep (elmtui.app:get-component-instance (list child1-id) app-state) 'app-init-test-component)))))))


(test view-resolution-with-initialized-state
  (multiple-value-bind (app-state commands) (initialize-app-state-test-init-app)
    (declare (ignore commands))
    (let* ((view-tree (test-init-app-view app-state)))
      (is (equalp view-tree
            '(:column :id :main-column
               :children
               ((:app-init-test-component :id :comp1 :initial-state "comp1 state")
                (:app-init-test-parent-component :id :parent1 :child-initial-state "child state"))))))))

(elmtui.app:defapplication my-test-app
  :root-component-dsl '(elmtui.ui.widgets.label:label :id :root-label :text "Hello")
  :root-viewport-id   :rv)
(test my-test-app-initialization
  (is (fboundp 'initialize-app-state-my-test-app))
  (is (fboundp 'process-message-my-test-app))
  (is (fboundp 'run-my-test-app)))

;; (test missing-arg
;;   (signals error
;;     (macroexpand
;;      (elmtui.app:defapplication bad-app
;;        :root-component-dsl
;;        '(elmtui.ui.widgets.label:label
;;          :id :root-label :text "Hello")))))

(elmtui.app:defapplication my-state-test-app
  :root-component-dsl '(:layout :id :main)
  :root-viewport-id :my-root
  :initial-state-plist '(:foo "bar"))
(test state-initialization

  (multiple-value-bind (state commands)
    (initialize-app-state-my-state-test-app)
    (declare (ignore commands))
    (is (typep state 'elmtui.state:application-state))
    (is (string= "bar" (elmtui.state:get-path '(:foo) state)))
    (is (not (null (elmtui.state:get-path '(:components :my-root) state))))
    (is (eq :layout (elmtui.state:get-path '(:components :my-root :main :type) state)))
    (is (eq :main (elmtui.state:get-path '(:components :my-root :main :id) state)))))

;; TODO test non-component
