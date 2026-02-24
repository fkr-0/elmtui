;;;; DSL Resolution Tests
;;;; Tests for the DSL type resolution system using polymorphic dsl-type generic function

(uiop:define-package :elmtui-tests.dsl-resolution
  (:use :cl :fiveam)
  (:import-from :elmtui.ui.dsl-resolution
    #:dsl-type
    #:resolve-dsl-type)
  (:export #:dsl-resolution-suite))

(in-package :elmtui-tests.dsl-resolution)

(def-suite dsl-resolution-suite
  :in elmtui.tests:elmtui-test
  :description "Test suite for DSL type resolution")

(in-suite dsl-resolution-suite)

(test resolve-dsl-type-symbol-terminates
  "Direct class symbol terminates recursion"
  (multiple-value-bind (class props)
    (resolve-dsl-type 'test-widget)
    (is (eq class 'test-widget))
    (is (null props))))

(test resolve-dsl-type-list-injects-props
  "List form injects extra props"
  (defmethod dsl-type ((type (eql :base)) &optional props)
    (values 'base-widget props))
  (multiple-value-bind (class props)
    (resolve-dsl-type '(:base :extra "data"))
    (is (eq class 'base-widget))
    (is (equal (getf props :extra) "data"))))

(test dsl-type-variant-adds-default-props
  "Variant adds default props"
  (defmethod dsl-type ((type (eql :variant)) &optional props)
    (declare (ignore props))
    (values 'base-widget '(:default "value")))
  (multiple-value-bind (class props)
    (dsl-type :variant)
    (is (eq class 'base-widget))
    (is (equal (getf props :default) "value"))))

(test dsl-type-chaining
  "Variants can chain to other variants"
  (defmethod dsl-type ((type (eql :chained)) &optional props)
    (dsl-type :base (append props '(:added :value))))
  (multiple-value-bind (class props)
    (dsl-type :chained)
    (is (eq class 'base-widget))
    (is (equal (getf props :added) :value))))
