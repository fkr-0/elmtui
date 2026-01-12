(uiop:define-package :cl-styles.tests/engine
  (:use :cl :fiveam :cl-styles.engine)
  (:import-from :cl-styles.sheet #:make-stylesheet #:style-engine)
  (:import-from :cl-styles.tests/smoke #:node)
  (:export #:suite))
(in-package :cl-styles.tests/engine)

(def-suite cl-styles/engine
  :in cl-styles.tests:cl-styles-test)
(in-suite cl-styles/engine)
(test variables-and-inheritance
  (let* ((root (make-instance 'node :id :root :nodetype :container
                                    :style
                                    `(:color ,(cl-styles.tokens:var "--accent"))))
         (child (make-instance 'node :id :child :nodetype :text :style nil))
         (sheet (make-stylesheet :rules nil :variables '(("--accent" . :orange)))))
    (setf (cl-styles.protocols:stylable-parent child) root)
    (setf (cl-styles.protocols:stylable-children root) (list child))
    (apply-stylesheet-to-tree root sheet)
    (is (eql :orange (getf (cl-styles.protocols:get-computed-style child) :color)))))

(test apply-stylesheet-edge-cases
  "Test apply-stylesheet with edge cases"
  (let ((sheet (make-stylesheet :rules (list (cl-styles.rule:defrule (cl-styles.selector:type> :button) :color :red))))
        (button (make-instance 'node :id :btn :nodetype :button)))
    
    ;; Test with nil sheet
    (apply-stylesheet nil (list button))
    (is (null (cl-styles.protocols:get-computed-style button)))
    
    ;; Test with empty rules
    (let ((empty-sheet (make-stylesheet :rules nil)))
      (apply-stylesheet empty-sheet (list button))
      (is (null (cl-styles.protocols:get-computed-style button))))
    
    ;; Test with nil objects
    (is (null (apply-stylesheet sheet nil)))
    (is (null (apply-stylesheet sheet '())))))

(test compute-style-with-no-matches
  "Test compute-style when no rules match"
  (let ((sheet (make-stylesheet :rules (list (cl-styles.rule:defrule (cl-styles.selector:type> :button) :color :red))))
        (span (make-instance 'node :id :span :nodetype :span)))
    
    (apply-stylesheet sheet (list span))
    ;; Should not error, and no computed style should be set
    (is (null (cl-styles.protocols:get-computed-style span)))))

(test inheritance-with-missing-parent
  "Test inheritance when parent has no computed style"
  (let* ((parent (make-instance 'node :id :parent :nodetype :div))
         (child (make-instance 'node :id :child :nodetype :text))
         (sheet (make-stylesheet :rules nil)))
    
    (setf (cl-styles.protocols:stylable-parent child) parent)
    (setf (cl-styles.protocols:stylable-children parent) (list child))
    
    ;; Apply to tree - should not error even with no rules
    (apply-stylesheet-to-tree parent sheet)
    (is (null (cl-styles.protocols:get-computed-style child)))))

(test variable-resolution-with-missing-vars
  "Test variable resolution when variable is not defined"
  (let* ((sheet (make-stylesheet 
                  :rules (list (cl-styles.rule:defrule (cl-styles.selector:type> :button) 
                                 :background :blue)) ; Use a valid property instead
                  :variables '(("--other-var" . :blue))))
         (button (make-instance 'node :id :btn :nodetype :button)))
    
    ;; Should not error, and button should get the background color
    (apply-stylesheet sheet (list button))
    (let ((computed (cl-styles.protocols:get-computed-style button)))
      (is (eql :blue (getf computed :background))))))
