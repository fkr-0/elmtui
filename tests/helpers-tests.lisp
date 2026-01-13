(uiop:define-package :elmtui.tests.helpers
  (:use :cl :fiveam)
  (:import-from :elmtui.view.dsl #:dsl->ui-node)
  (:import-from :elmtui.view.core #:ui-node #:ui-node-p #:ui-node-type #:ui-node-props #:ui-node-children)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.ui.defcomponent #:defcomponent)
  (:import-from :elmtui.state #:make-state)
  (:import-from :elmtui.ui.api #:update #:view)
  (:import-from :elmtui.state #:state-ref #:get-path)
  ;; (:import-from :elmtui.state  #:get-path)
  (:export #:helpers-tests))

(in-package :elmtui.tests.helpers)

(def-suite helpers-tests
  :in elmtui.tests:elmtui-test
  :description "Tests for helper functions and macros.")

(in-suite helpers-tests)

;; Test for dsl->ui-node
(test dsl-ui-node-children-wrapping
  "Test that dsl->ui-node wraps children in individual lists"
  (let* ((dsl '(:container :id :main :style (:width 10 :height 10) :classes '("test-class")
                 :children ((:text :id :child1 :content "a")
                             (:text :id :child2 :content "b"))))
          (app-state (elmtui.state.api:plist-to-application-state  '(:components (:main (:children (:child1 nil :child2 nil)))))))
    (let ((ui-node (dsl->ui-node dsl app-state)))
      ;; (list ui-node dsl)))
      ;; (elmtui.utils:as :styled-ui-node ui-node)
      ;; (elmtui.view.base-elements:dsl-properties
      ;; ;; )
      ;; ui-node
      ;; )
      ;; ))
      (let ((children (elmtui.view.element:el/children ui-node)))
        (is (listp children))
        (is (= 2 (length children)))
        (is (elmtui.view.element:element-p (first children)))
        (is (elmtui.view.element:element-p (second children)))))))

;; Test for defapplication initial state
(defun test-app-for-state-view (state)
  (declare (ignore state))
  '(:container :id :root))

(defun test-app-for-state-update (msg state)
  (declare (ignore msg state))
  (make-instance 'elmtui.state:update-result))

(defapplication test-app-for-state
  :initial-state-plist '(:counter 99)
  :root-component-dsl '(:container :id :root)
  :view-fn 'test-app-for-state-view
  :update-fn 'test-app-for-state-update
  :root-viewport-id :root)

(test defapplication-initial-state-preservation
  "Test that defapplication preserves numeric types in initial state"
  (multiple-value-bind (app-state commands)
    (initialize-app-state-test-app-for-state)
    (declare (ignore commands))
    (is (numberp (elmtui.utils:get-path '(:counter) app-state)))
    (is (= 99 (elmtui.utils:get-path '(:counter) app-state)))))

;; Test for defcomponent view
(defcomponent test-component-for-view-helper ()
  (:state
    (message "hello"))
  (:view (state app-state id-path children)
    ;; (declare (ignore app-state id-path))
    `(:text :content ,(getf state :message "default"))))

;; test mutating the message in the state
(test defcomponent-view-defaults-to-state
  "Test that defcomponent's view method uses the state by default"
  (let* ((instance (make-instance 'test-component-for-view-helper))
          (app-state (elmtui.state.api:plist-to-application-state '(:components (:test1 (:message "hello")))))
          (id-path '(:components :test1))
          (view (view instance app-state :id-path id-path)))
    (cddr view) view;)
    ;; (state-ref app-state (append id-path (list :message)))
    ;; )
                                        ;(is (string= "hello" (state-ref app-state (append id-path (list :message)))))
    ;; mutate the state
    (setf (state-ref app-state (append id-path (list :message))) "custom")
    (is (equalp '(:text :content "custom")(view instance app-state :id-path id-path)))
    (is (string= "custom" (state-ref app-state (append id-path (list :message)))))))

;; (test children-split
;;   (let* ((dsl-1 '(:viewport :id :main
;;                   :children ((:text :id :c1 :content "a")
;;                              (:text :id :c2 :content "b"))
;;                   (:text :id :c3 :content "c")))
;;          ;;          (dsl '(:container :id :main
;;          ;;                 :children ((:text :id :c1 :content "a")
;;          ;;                            (:text :id :c2 :content "b"))))
;;          (app-state (elmtui.state.api:plist-to-application-state
;;                      '(:components (:main (:message "hello")))))
;;          ;; :c1 (list :content "a" )
;;          ;;            :c2 (list :content "a"))))))
;;          ;; (tree (elmtui.view.dsl:render-dsl-to-resolved-tree dsl app-state))
;;          (tree-1 (elmtui.view.dsl:render-dsl-to-resolved-tree dsl-1 app-state)))
;;     tree-1)
;; ;;     (is ;; (every #'ui-node-p (ui-node-children tree))
;; ;;      (equalp '(:CONTAINER :ID :MAIN :CHILDREN
;; ;;                ((:TEXT :ID :C1 :CONTENT "a" :children nil) (:TEXT :ID :C2 :CONTENT "b" :children nil)))
;; ;;              tree)
;; ;;      )
;;     ))

(test defcomponent-view-honors-custom-view
  "Test that defcomponent's view method uses the custom view"
  (let* ((instance (make-instance 'test-component-for-view-helper))
          (app-state (elmtui.state.api:plist-to-application-state '(:components (:test1 (:message "custom")))))
          (id-path '(:components :test1))
          (view (view instance app-state :id-path id-path)))
    ;; (cddr view) view)

    (is (string= "custom"  (getf (cdr view)
                             :content)))))

;; Test for defcomponent update
(defcomponent test-component-for-update-helper ()
  (:state (count 0))
  (:update (msg state app-state id-path)
    (:increment ()
      ;; (declare (ignore app-state id-path))
      (values `(:count ,(1+ (getf state :count))) nil))))

(test defcomponent-update-merges-patches
  "Test that defcomponent's update method merges patches"
  (let* ((instance (make-instance 'test-component-for-update-helper))
          (app-state (elmtui.state.api:plist-to-application-state '(:components (:test1 (:count 5)))))
          (id-path '(:components :test1))
          (result (update instance app-state '(:increment) :id-path id-path)))
    (let ((patches (elmtui.state:ur-patches result)))
      (is (= 1 (length patches)))
      (is (= 6 (second (first patches)))))))
