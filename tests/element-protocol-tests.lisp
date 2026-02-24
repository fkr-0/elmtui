;;; ===============================================================
;;; File: tests/element-protocol-tests.lisp
;;; Unit Tests for elmtui.view.element
;;; ===============================================================
(uiop:define-package :elmtui.tests.element-protocol
  (:use :cl :fiveam :alexandria)
  (:import-from :elmtui.view.element
    #:element-p
    #:el/children
    #:el/props
    #:el/styles
    #:el/type
    #:el/id
    #:el/layout-rect
    #:el/display
    #:el/content
    #:el/size
    #:el/styles-of
    #:intrinsic-size-of
    #:ensure-element
    #:with-element)
  (:import-from :elmtui.view.base-elements
    #:normalize-base-dsl)
  (:import-from :elmtui.view.geo
    #:make-size
    #:size-w
    #:size-h)
  (:export #:element-protocol-tests))

(in-package :elmtui.tests.element-protocol)

(def-suite element-protocol-tests
  :in elmtui.tests:elmtui-test
  :description "Tests for element protocol")

(in-suite element-protocol-tests)

(defun plist-p (x)
  (and (listp x) (evenp (length x))))

;;;=============================================================================
;;; element-p Tests
;;;=============================================================================

(test element-p-returns-t-for-base-element
  "Test element-p returns t for base elements"
  (let ((e (normalize-base-dsl '(:label :id :test :content "Test"))))
    (is-true (element-p e))))

(test element-p-returns-nil-for-non-element
  "Test element-p returns nil for non-elements"
  (is-false (element-p "not an element"))
  (is-false (element-p 42))
  (is-false (element-p nil))
  (is-false (element-p :keyword)))

;;;=============================================================================
;;; el/type Tests
;;;=============================================================================

(test el/type-returns-element-type
  "Test el/type returns the element type"
  (let ((e (normalize-base-dsl '(:label :id :test :content "Test"))))
    (is (eq :label (el/type e)))))

;;;=============================================================================
;;; el/id Tests
;;;=============================================================================

(test el/id-returns-element-id
  "Test el/id returns the element id"
  (let ((e (normalize-base-dsl '(:label :id :my-label :content "Test"))))
    (is (eq :my-label (el/id e)))))

;;;=============================================================================
;;; el/children Tests
;;;=============================================================================

(test el/children-returns-children
  "Test el/children returns element children"
  (let ((e (normalize-base-dsl '(:container :id :root
                                  :children ((:label :id :c1 :content "A")
                                              (:button :id :b1 :content "Click"))))))
    (let ((children (el/children e)))
      (is (= 2 (length children)))
      (is (eq :label (el/type (first children))))
      (is (eq :button (el/type (second children)))))))

(test el/children-returns-nil-for-no-children
  "Test el/children returns nil for elements with no children"
  (let ((e (normalize-base-dsl '(:label :id :test :content "Test"))))
    (is-false (el/children e))))

;;;=============================================================================
;;; el/content Tests
;;;=============================================================================

(test el/content-returns-text-for-text-element
  "Test el/content returns text content for text elements"
  (let ((e (normalize-base-dsl '(:label :id :test :content "Hello"))))
    (is (string= "Hello" (el/content e)))))

(test el/content-returns-nil-for-non-text-element
  "Test el/content returns nil for non-text elements"
  (let ((e (normalize-base-dsl '(:container :id :test))))
    (is-false (el/content e))))

;;;=============================================================================
;;; el/size Tests
;;;=============================================================================

(test el/size-returns-element-size
  "Test el/size returns element size"
  (let ((e (normalize-base-dsl '(:label :id :test :content "Test"))))
    (let ((size (el/size e)))
      (is-true (typep size 'elmtui.view.geo::size)))))

(test el/size-setter-accepts-list
  "Test (setf el/size) accepts a two-element list"
  (let ((e (normalize-base-dsl '(:label :id :test :content "Test"))))
    (setf (el/size e) '(10 20))
    (is (= 10 (size-w (el/size e))))
    (is (= 20 (size-h (el/size e))))))

(test el/size-setter-accepts-size
  "Test (setf el/size) accepts a size struct"
  (let ((e (normalize-base-dsl '(:label :id :test :content "Test")))
         (size (make-size :w 30 :h 40)))
    (setf (el/size e) size)
    (is (= 30 (size-w (el/size e))))
    (is (= 40 (size-h (el/size e))))))

;;;=============================================================================
;;; el/display Tests
;;;=============================================================================

(test el/display-defaults-to-block
  "Test el/display defaults to :block"
  (let ((e (normalize-base-dsl '(:container :id :test))))
    (is (eq :block (el/display e)))))

(test el/display-returns-style-value
  "Test el/display returns style value when set"
  (let ((e (normalize-base-dsl '(:container :id :test :style (:display :inline)))))
    (is (eq :inline (el/display e)))))

;;;=============================================================================
;;; el/styles Tests
;;;=============================================================================

(test el/styles-returns-style-plist
  "Test el/styles returns the style plist"
  (let ((e (normalize-base-dsl '(:container :id :test :style (:fg :red :bg :blue)))))
    (let ((styles (el/styles e)))
      (is-true (plist-p styles))
      (is (eq :red (getf styles :fg)))
      (is (eq :blue (getf styles :bg))))))

;;;=============================================================================
;;; el/styles-of Tests
;;;=============================================================================

(test el/styles-of-gets-specific-style
  "Test el/styles-of gets a specific style value"
  (let ((e (normalize-base-dsl '(:container :id :test :style (:fg :red :bg :blue)))))
    (is (eq :red (el/styles-of e :fg)))
    (is (eq :blue (el/styles-of e :bg)))))

(test el/styles-of-returns-default-when-not-set
  "Test el/styles-of returns default when style not set"
  (let ((e (normalize-base-dsl '(:container :id :test :style (:fg :red)))))
    (is (eq :red (el/styles-of e :fg)))
    (is-false (el/styles-of e :bg nil))
    (is (eq :default (el/styles-of e :bg :default)))))

(test el/styles-of-setter-modifies-style
  "Test (setf el/styles-of) modifies style value"
  (let ((e (normalize-base-dsl '(:container :id :test :style (:fg :red)))))
    (setf (el/styles-of e :fg) :green)
    (is (eq :green (el/styles-of e :fg)))
    (is-false (el/styles-of e :bg))))

;;;=============================================================================
;;; el/props Tests
;;;=============================================================================

(test el/props-returns-props-plist
  "Test el/props returns the props plist"
  (let ((e (normalize-base-dsl '(:checkbox :id :test :label "Agree"))))
    (let ((props (el/props e)))
      (is-true (plist-p props))
      (is (string= "Agree" (getf props :label))))))

;;;=============================================================================
;;; intrinsic-size-of Tests
;;;=============================================================================

(test intrinsic-size-of-text-element
  "Test intrinsic-size-of for text element returns size based on text length"
  (let ((e (normalize-base-dsl '(:label :id :test :content "Hello"))))
    (let ((size (intrinsic-size-of e nil)))
      (is-true (typep size 'elmtui.view.geo::size))
      (is (= 5 (size-w size)))  ; "Hello" has 5 characters
      (is (= 1 (size-h size))))))

(test intrinsic-size-of-base-element-returns-zero
  "Test intrinsic-size-of for base element returns zero size"
  (let ((e (normalize-base-dsl '(:container :id :test))))
    (let ((size (intrinsic-size-of e nil)))
      (is-true (typep size 'elmtui.view.geo::size))
      (is (= 0 (size-w size)))
      (is (= 0 (size-h size))))))

;;;=============================================================================
;;; ensure-element Tests
;;;=============================================================================

(test ensure-element-returns-element-for-base-element
  "Test ensure-element returns the element for base elements"
  (let ((e (normalize-base-dsl '(:label :id :test :content "Test"))))
    (is (eq e (ensure-element e)))))

;;;=============================================================================
;;; with-element Macro Tests
;;;=============================================================================

(test with-element-binds-and-executes
  "Test with-element binds var and executes body"
  (let ((e (normalize-base-dsl '(:label :id :test :content "Test"))))
    (with-element (v e)
      (is (eq v e))
      (is (eq :label (el/type v))))))

(test with-element-calls-ensure-element
  "Test with-element calls ensure-element on the object"
  (let ((e (normalize-base-dsl '(:label :id :test :content "Test"))))
    (with-element (v e)
      (is-true (element-p v)))))

;;;=============================================================================
;;; el/layout-rect Tests
;;;=============================================================================

(test el/layout-rect-returns-rectangle
  "Test el/layout-rect returns the layout rectangle"
  (let ((e (normalize-base-dsl '(:label :id :test :content "Test"))))
    (let ((rect (el/layout-rect e)))
      (is-true (typep rect 'elmtui.view.geo::rectangle)))))
