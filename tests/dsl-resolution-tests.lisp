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

(test malformed-dsl-forms-fail-boundedly
  (dolist (form (list nil '(:text . :bad) 17
                      (let ((x (list :text))) (setf (cdr x) x) x)
                      (let ((x (list nil))) (setf (car x) x) x)))
    (signals elmtui.ui.dsl-resolution::invalid-dsl-form
      (resolve-dsl-type form))))

(test direct-dsl-type-cyclic-car-and-finite-depth
  (let* ((self (list nil))
         (a (list nil))
         (b (list nil))
         (cdr-cycle (list :text)))
    (setf (car self) self
          (car a) b
          (car b) a
          (cdr cdr-cycle) cdr-cycle)
    (dolist (form (list self a cdr-cycle))
      (signals elmtui.ui.dsl-resolution::invalid-dsl-form (dsl-type form))
      (signals elmtui.ui.dsl-resolution::invalid-dsl-form (resolve-dsl-type form))))
  (let ((deep 'widget))
    (dotimes (i 520) (setf deep (list deep :k i)))
    (signals elmtui.ui.dsl-resolution::invalid-dsl-form (dsl-type deep))
    (signals elmtui.ui.dsl-resolution::invalid-dsl-form (resolve-dsl-type deep)))
  (let ((finite 'widget))
    (dotimes (i 80) (setf finite (list finite :k i)))
    (is (eq 'widget (dsl-type finite)))
    (is (eq 'widget (resolve-dsl-type finite)))))

(test dsl-list-props-precedence-and-nonmutation
  (let* ((form (list (list 'widget :a nil :b 2) :a 1))
         (snapshot (copy-tree form))
         (input '(:a 9 :c 4)))
    (multiple-value-bind (class props) (resolve-dsl-type form input)
      (is (eq class 'widget))
      (is (equal props '(:a nil :b 2 :a 1 :a 9 :c 4)))
      (is (null (getf props :a)))
      (is (equal form snapshot))
      (is (equal input '(:a 9 :c 4))))))

(test generated-finite-dsl-list-resolution
  "Deterministic seeded generator, checked against an independent spine model."
  (let ((seed 20261014))
    (labels ((next-number ()
               (setf seed (mod (+ (* seed 1103515245) 12345) 2147483648))
               seed))
      (loop repeat 32
            for depth = (1+ (mod (next-number) 24))
            for form = 'widget
            for expected = nil
            do (loop repeat depth
                     for value = (mod (next-number) 97)
                     do (setf form (list form :flag value)
                              expected (append expected (list :flag value))))
               (multiple-value-bind (class props) (resolve-dsl-type form)
                 (is (eq class 'widget))
                 (is (equal props expected)))))))

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

(test dsl-type-symbol-is-shared-across-api-packages
  "elmtui.api:dsl-type and elmtui.ui.dsl-resolution:dsl-type must be the same symbol."
  (let ((api-sym (find-symbol "DSL-TYPE" :elmtui.api))
        (ui-sym (find-symbol "DSL-TYPE" :elmtui.ui.dsl-resolution)))
    (is (eq api-sym ui-sym))))

(test resolve-dsl-type-root-viewport-builtin
  "Built-in :root-viewport alias resolves via UI-owned dsl-type method."
  (multiple-value-bind (class props)
      (resolve-dsl-type :root-viewport)
    (is (eq class 'elmtui.ui.widgets.root-viewport:root-viewport))
    (is (null props))))

(test resolve-dsl-type-text-alias-builtin
  "Built-in :text alias resolves to label component for compatibility."
  (multiple-value-bind (class props)
      (resolve-dsl-type :text)
    (is (eq class 'elmtui.ui.widgets.label:label))
    (is (null props))))
