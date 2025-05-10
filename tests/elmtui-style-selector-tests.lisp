;;;===============================================================
;;; File: tests/elmtui-style-selector-tests.lisp
;;; Unit Tests for Style Selectors
;;;===============================================================

(uiop:define-package :elmtui-style-selector-tests
  (:use :cl :fiveam)
  ;; Import selector types and macros
  (:import-from :elmtui.style-lib.selector
                #:selector #:type-selector #:class-selector #:id-selector
                #:combined-selector #:or-selector #:child-selector #:desc-selector
                #:type> #:cls> #:id> #:and> #:or> #:child> #:descendant>
                #:selects #:specificity)
  ;; Import stylable node and related functions
  (:import-from :elmtui.view.styled #:styled-ui-node #:make-styled-node)
  (:import-from :elmtui.view.core #:ui-node-type #:ui-node-props #:ui-node-children)
  (:import-from :elmtui.style-lib.api #:stylable-id #:classes #:parents-of))

(in-package :elmtui-style-selector-tests)

;;; Define a Test Suite
(def-suite elmtui-style-selector-suite
  :description "Unit tests for the Elmtui style selector engine.")

(in-suite elmtui-style-selector-suite)

;;; Helper to create test nodes
(defun make-test-node (&key (type :div) (id nil) (classes nil) (props nil) (children nil) (parent nil))
  (make-styled-node :type type
                    :props (append (when id `(:id ,id))
                                   (when classes `(:classes ,classes))
                                   props)
                    :children children
                    :parent parent))

;;; Test Cases

(test type-selector-test
  "Test the type selector (type>)"
  (let ((node-div (make-test-node :type :div))
        (node-span (make-test-node :type :span)))
    (is-true (selects (type> :div) node-div))
    (is-false (selects (type> :span) node-div))
    (is-true (selects (type> :span) node-span))
    (is-false (selects (type> :div) node-span))
    (is (= 1 (specificity (type> :div))))))

(test class-selector-test
  "Test the class selector (cls>)"
  (let ((node1 (make-test-node :classes "foo"))
        (node2 (make-test-node :classes '("foo" "bar")))
        (node3 (make-test-node :classes "baz")))
    (is-true (selects (cls> "foo") node1))
    (is-true (selects (cls> "foo") node2))
    (is-true (selects (cls> "bar") node2))
    (is-false (selects (cls> "baz") node1))
    (is-false (selects (cls> "foo") node3))
    (is (= 10 (specificity (cls> "foo"))))))

(test id-selector-test
  "Test the ID selector (id>)"
  (let ((node1 (make-test-node :id "my-id"))
        (node2 (make-test-node :id "other-id")))
    (is-true (selects (id> "my-id") node1))
    (is-false (selects (id> "other-id") node1))
    (is-false (selects (id> "my-id") node2))
    (is (= 100 (specificity (id> "my-id"))))))

(test universal-selector-test
  "Test the universal selector (:*)"
  (let ((node1 (make-test-node :type :div))
        (node2 (make-test-node :id "foo")))
    (is-true (selects :* node1))
    (is-true (selects :* node2))
    (is-true (selects :* nil)) ; Should match anything
    (is (= 0 (specificity :*)))))

(test combined-selector-test
  "Test the combined selector (and>)"
  (let ((node1 (make-test-node :type :button :id "btn1" :classes "primary"))
        (node2 (make-test-node :type :button :classes "primary"))
        (node3 (make-test-node :type :label :classes "primary")))
    (is-true (selects (and> (type> :button) (cls> "primary")) node1))
    (is-true (selects (and> (type> :button) (cls> "primary")) node2))
    (is-false (selects (and> (type> :button) (cls> "primary")) node3))
    (is-false (selects (and> (type> :button) (id> "btn1")) node2))
    (is (= (+ (specificity (type> :button)) (specificity (cls> "primary")))
           (specificity (and> (type> :button) (cls> "primary")))))
    (is (= (+ (specificity (type> :button)) (specificity (id> "btn1")))
           (specificity (and> (type> :button) (id> "btn1")))))))

(test or-selector-test
  "Test the OR selector (or>)"
  (let ((node-btn (make-test-node :type :button))
        (node-lbl (make-test-node :type :label))
        (node-div (make-test-node :type :div)))
    (is-true (selects (or> (type> :button) (type> :label)) node-btn))
    (is-true (selects (or> (type> :button) (type> :label)) node-lbl))
    (is-false (selects (or> (type> :button) (type> :label)) node-div))
    (is (= (max (specificity (type> :button)) (specificity (type> :label)))
           (specificity (or> (type> :button) (type> :label)))))))

;; TODO: Add tests for child> and descendant> selectors - requires setting up parent links.
;; These might be better suited for the integration test where a tree exists.
