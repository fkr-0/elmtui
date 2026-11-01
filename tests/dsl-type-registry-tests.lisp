;;;; DSL Type Registry Tests
;;;; Tests for the extensible DSL type registry that allows defcomponent-defined
;;;; types to be recognized as valid child nodes by split-props/children.

(uiop:define-package :elmtui-tests.dsl-type-registry
  (:use :cl :fiveam)
  (:import-from :elmtui.ui.dsl-resolution
    #:*dsl-type-registry*
    #:register-dsl-type
    #:known-dsl-type-p
    #:resolve-dsl-type)
  (:import-from :elmtui.view.base-elements
    #:element-class)
  (:import-from :elmtui.ui.defcomponent
    #:defcomponent)
  (:export #:dsl-type-registry-suite))

(in-package :elmtui-tests.dsl-type-registry)

(def-suite dsl-type-registry-suite
  :in elmtui.tests:elmtui-test
  :description "Test suite for DSL type registry extensibility")

(in-suite dsl-type-registry-suite)

;;; ---------------------------------------------------------------
;;; Registry API tests
;;; ---------------------------------------------------------------

(test register-dsl-type-basic
  "register-dsl-type stores a keyword-to-class mapping"
  (let ((test-kw (gensym-keyword "REG-BASIC")))
    (is (null (known-dsl-type-p test-kw)))
    (register-dsl-type test-kw 'test-class-basic)
    (is (eq 'test-class-basic (known-dsl-type-p test-kw)))
    ;; Clean up
    (remhash test-kw *dsl-type-registry*)))

(test register-dsl-type-without-class
  "register-dsl-type with no class stores T as a truthy sentinel"
  (let ((test-kw (gensym-keyword "REG-NO-CLASS")))
    (register-dsl-type test-kw)
    (is-true (known-dsl-type-p test-kw))
    (remhash test-kw *dsl-type-registry*)))

(test register-dsl-type-idempotent
  "Repeated registration with the same keyword and class is harmless"
  (let ((test-kw (gensym-keyword "REG-IDEMP")))
    (register-dsl-type test-kw 'idemp-class)
    (register-dsl-type test-kw 'idemp-class)
    (is (eq 'idemp-class (known-dsl-type-p test-kw)))
    (remhash test-kw *dsl-type-registry*)))

(test register-dsl-type-returns-keyword
  "register-dsl-type returns the registered keyword"
  (let ((test-kw (gensym-keyword "REG-RET")))
    (is (eq test-kw (register-dsl-type test-kw 'ret-class)))
    (remhash test-kw *dsl-type-registry*)))

(test known-dsl-type-p-nil-for-unknown
  "known-dsl-type-p returns NIL for unregistered keywords"
  (is (null (known-dsl-type-p :this-keyword-is-never-registered-xyzzy-42))))

;;; ---------------------------------------------------------------
;;; Built-in types are registered
;;; ---------------------------------------------------------------

(test builtin-types-registered
  "Built-in types from dsl-type-builtins are in the registry"
  (is-true (known-dsl-type-p :root-viewport)
           ":root-viewport should be registered")
  (is-true (known-dsl-type-p :viewport)
           ":viewport should be registered")
  (is-true (known-dsl-type-p :text)
           ":text should be registered"))

(test builtin-types-have-correct-class
  "Built-in type registry entries map to the correct class"
  (is (eq 'elmtui.ui.widgets.root-viewport:root-viewport
          (known-dsl-type-p :root-viewport)))
  (is (eq 'elmtui.ui.widgets.viewport:viewport
          (known-dsl-type-p :viewport)))
  (is (eq 'elmtui.ui.widgets.label:label
          (known-dsl-type-p :text))))

;;; ---------------------------------------------------------------
;;; Base element types are recognized via element-class fallback
;;; ---------------------------------------------------------------

(test base-element-types-via-element-class
  "Base element types like :container, :button are recognized via element-class"
  (is-true (element-class :container)
           ":container should be in element-class registry")
  (is-true (element-class :row)
           ":row should be in element-class registry")
  (is-true (element-class :column)
           ":column should be in element-class registry")
  (is-true (element-class :button)
           ":button should be in element-class registry")
  (is-true (element-class :label)
           ":label should be in element-class registry")
  (is-true (element-class :input)
           ":input should be in element-class registry"))

;;; ---------------------------------------------------------------
;;; defcomponent auto-registration
;;; ---------------------------------------------------------------

;; Define a test component to verify auto-registration
(defcomponent registry-test-widget (elmtui.ui.api:component)
  (:state (value 0 :type integer))
  (:view (local-state app-state self-id-path children)
    `(:text :id ,(elmtui.ui.api:id-from-path self-id-path)
       :content ,(format nil "~D" (getf local-state :value 0)))))

(test defcomponent-auto-registers-dsl-type
  "defcomponent automatically registers the component's DSL type keyword"
  (is-true (known-dsl-type-p :registry-test-widget)
           "defcomponent should auto-register :registry-test-widget"))

(test defcomponent-registers-correct-class
  "defcomponent registers the correct class name for the DSL type"
  (is (eq 'registry-test-widget (known-dsl-type-p :registry-test-widget))))

(test defcomponent-dsl-type-method-consistent
  "The registry entry is consistent with the dsl-type generic method"
  (multiple-value-bind (class props) (resolve-dsl-type :registry-test-widget)
    (is (eq class 'registry-test-widget))
    (is (null props))))

;;; ---------------------------------------------------------------
;;; split-props/children disambiguation
;;; ---------------------------------------------------------------

(test split-props-recognizes-builtin-element-child
  "split-props/children recognizes :container as a child node type"
  (multiple-value-bind (props children)
      (elmtui.view.dsl::split-props/children
       '(:id :parent :container (:text :content "hello")))
    (is (eq :parent (getf props :id)))
    ;; :container should be recognized as a child, not consumed as a property
    (is (not (null children)))
    (is (eq :container (first children)))))

(test split-props-recognizes-registered-component-child
  "split-props/children recognizes a defcomponent-defined type as a child"
  (multiple-value-bind (props children)
      (elmtui.view.dsl::split-props/children
       '(:id :parent :registry-test-widget (:text :content "nested")))
    (is (eq :parent (getf props :id)))
    ;; :registry-test-widget should be recognized as a child node
    (is (not (null children)))
    (is (eq :registry-test-widget (first children)))))

(test split-props-unknown-keyword-stays-property
  "Unknown keywords are consumed as properties, not treated as children"
  (multiple-value-bind (props children)
      (elmtui.view.dsl::split-props/children
       '(:id :parent :unknown-thing (:text :content "val")))
    (is (eq :parent (getf props :id)))
    ;; :unknown-thing should be consumed as a property key
    (is (equal '(:text :content "val") (getf props :unknown-thing)))
    (is (null children))))

(test split-props-explicit-children-still-works
  "Explicit :children property overrides positional children"
  (multiple-value-bind (props children)
      (elmtui.view.dsl::split-props/children
       '(:id :parent :children ((:text :content "explicit"))))
    (is (eq :parent (getf props :id)))
    (is (equal '((:text :content "explicit")) children))))

;;; ---------------------------------------------------------------
;;; End-to-end: DSL tree with user-defined component as child
;;; ---------------------------------------------------------------

;; Define a second test component that uses the first as a child
(defcomponent registry-test-parent (elmtui.ui.api:component)
  (:state (title "Parent" :type string))
  (:view (local-state app-state self-id-path children)
    `(:container :id ,(elmtui.ui.api:id-from-path self-id-path)
       :children
       ((:text :id :title :content ,(getf local-state :title))
        (:registry-test-widget :id :child-widget)))))

(test defcomponent-parent-auto-registered
  "The parent component is also auto-registered"
  (is-true (known-dsl-type-p :registry-test-parent)))

(test dsl-tree-with-user-component-child-parses
  "A DSL tree containing a user-defined component as child resolves correctly"
  ;; The DSL resolution system should handle the tree without error
  (let* ((dsl '(:container :id :root
                :children
                ((:registry-test-widget :id :my-widget)
                 (:text :content "after widget")))))
    ;; Verify the DSL form is valid by running it through split-props/children
    (multiple-value-bind (props children)
        (elmtui.view.dsl::split-props/children (rest dsl))
      (is (eq :root (getf props :id)))
      (is (= 2 (length children)))
      (is (eq :registry-test-widget (first (first children))))
      (is (eq :text (first (second children)))))))

(test positional-user-component-child-parses
  "A user-defined component type as a positional child (not via :children) parses"
  ;; This is the key ambiguity case: :registry-test-widget followed by a list
  ;; starting with a keyword. The parser must recognize it as a child, not
  ;; consume it as a property.
  (multiple-value-bind (props children)
      (elmtui.view.dsl::split-props/children
       '(:id :root :style (:display :flex)
         :registry-test-widget (:id :child :content "val")))
    (is (eq :root (getf props :id)))
    (is (not (null children)))
    ;; The children should start with :registry-test-widget
    (is (eq :registry-test-widget (first children)))))

;;; ---------------------------------------------------------------
;;; Helper
;;; ---------------------------------------------------------------

(defun gensym-keyword (prefix)
  "Generate a unique keyword for test isolation."
  (intern (symbol-name (gensym prefix)) :keyword))
