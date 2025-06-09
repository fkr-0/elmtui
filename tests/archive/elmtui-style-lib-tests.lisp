;;;===============================================================
;;; File: tests/elmtui-style-lib-tests.lisp
;;; Tests for Style Library Components
;;;===============================================================
(defpackage :elmtui-style-lib-tests
  (:use :cl :fiveam)
  (:import-from :elmtui.style-lib.api 
                #:new #:style-set-valid #:style-set-styles #:style-set-order
                #:style-set #:make-style-set #:make-default-styling
                #:valid-value-p #:group-key #:group-styles #:stylegroup-p #:sub-styles
                #:style-property-of #:make-style #:ordered-styles
                #:style-property-value-raw-value)
  (:import-from :elmtui.style-lib.util
                #:=? #:apply-after #:keyword-split #:keyword-concat
                #:kw-split #:kw-join #:ensure-list)
  (:import-from :elmtui.style-lib.style-set
                #:style-of #:value-of #:set-style #:merge-sets! #:copy-set
                #:parse-styles #:styles-list #:around-styles #:ordered-around-styles))

(in-package :elmtui-style-lib-tests)

(def-suite style-lib-tests
  :description "Tests for style library components (util, api, style-set, etc.)")

(in-suite style-lib-tests)

;;; Test apply-after function
(test apply-after-util-function
  "Test the apply-after function in util package"
  (is (not (apply-after :color nil)) "Property with no special ordering should return nil")
  (is (eq (apply-after :margin-top nil) :non-decorating) "Non-decorating property should return :non-decorating")
  (is (eq (apply-after :border-style '(:border-style :padding :margin)) :padding) 
      "Border style should apply after padding"))

;;; Test style-property-value-raw-value method
(test style-property-value-raw-value-method
  "Test the style-property-value-raw-value method in api package"
  (let ((value (elmtui.style-lib.api::make-value :value 42)))
    (is (= (style-property-value-raw-value value) 42) "Should extract raw value from value object"))
  (is (= (style-property-value-raw-value 42) 42) "Should return raw value for non-value object"))

;;; Test around-styles method
(test around-styles-method
  "Test the around-styles method that uses apply-after"
  (let ((set (make-style-set)))
    (set-style set :padding-top 5)
    (set-style set :color :blue)
    (set-style set :border-style :single)
    (set-style set :margin 2)
    
    (let ((decorator-styles (around-styles set)))
      (is (member :padding-top decorator-styles) "Padding should be in decorator styles")
      (is (member :border-style decorator-styles) "Border style should be in decorator styles")
      (is (member :margin decorator-styles) "Margin should be in decorator styles")
      (is (not (member :color decorator-styles)) "Color should not be in decorator styles"))))

;;; Test merge-sets! function
(test merge-sets-function
  "Test the merge-sets! function in style-set package"
  (let ((set1 (make-style-set))
        (set2 (make-style-set)))
    (set-style set1 :color :red)
    (set-style set1 :padding 5)
    (set-style set2 :color :blue)
    (set-style set2 :margin 2)
    
    (merge-sets! set1 set2)
    
    (is (eq (style-of set1 :color) :blue) "Color should be overridden by set2")
    (is (= (style-of set1 :padding) 5) "Padding should be preserved from set1")
    (is (= (style-of set1 :margin) 2) "Margin should be added from set2")))

;;; Test ordered-styles function
(test ordered-styles-function
  "Test the ordered-styles function in api package"
  (let ((style-keys '(:color :border-style :padding :margin)))
    (let ((ordered (ordered-styles style-keys)))
      (is (< (position :padding ordered) 
             (position :border-style ordered))
          "Padding should come before border-style in ordering")
      (is (< (position :border-style ordered)
             (position :margin ordered))
          "Border-style should come before margin in ordering"))))

;;; Run all tests
(defun run-elmtui-style-lib-tests ()
  (run! 'style-lib-tests))
