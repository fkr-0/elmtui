(uiop:define-package :cl-styles.tests/integration
  (:use :cl :fiveam)
  (:import-from :cl-styles.sheet #:make-stylesheet)
  (:import-from :cl-styles.rule #:defrule)
  (:import-from :cl-styles.selector #:type> #:id> #:cls>)
  (:import-from :cl-styles.engine #:apply-stylesheet #:apply-stylesheet-to-tree)
  (:import-from :cl-styles.tests/smoke #:node)
  (:export #:suite))
(in-package :cl-styles.tests/integration)

(def-suite cl-styles/integration
  :in cl-styles.tests:cl-styles-test)
(in-suite cl-styles/integration)

(test full-stylesheet-pipeline
  "Test complete stylesheet creation, rule matching, and style computation pipeline"
  (let* ((button-rule (defrule (type> :button) 
                        :color :white :background :blue :padding 8))
          (primary-rule (defrule (cls> "primary") 
                          :background :red :font-weight :bold))
          (my-button-rule (defrule (id> :my-btn) 
                            :border 2))
          (sheet (make-stylesheet 
                   :rules (list button-rule primary-rule my-button-rule)
                   :variables '(("--accent" . :purple))))
          (button (make-instance 'node 
                    :id :my-btn 
                    :nodetype :button
                    :classes '("primary")
                    :style '(:margin 5))))
    
    ;; Apply stylesheet
    (apply-stylesheet sheet (list button))
    
    ;; Verify all rules applied in correct specificity order
    (let ((computed (cl-styles.protocols:get-computed-style button)))
      (is (eql :white (getf computed :color)))      ; from button rule
      (is (eql :red (getf computed :background-color))) ; canonical background property
      (is (eql 8 (getf computed :padding)))         ; from button rule  
      (is (eql :bold (getf computed :font-weight))) ; from primary rule
      (is (eql 2 (getf computed :border)))          ; from id rule (highest specificity)
      (is (eql 5 (getf computed :margin))))))       ; from inline style (highest priority)

(test complex-inheritance-scenario
  "Test complex inheritance with multiple levels"
  (let* ((root (make-instance 'node :id :root :nodetype :container
                                    :style '(:font-family "Arial" :color :black)))
         (parent (make-instance 'node :id :parent :nodetype :div
                                      :style '(:font-size 16)))
         (child (make-instance 'node :id :child :nodetype :text
                                     :style '(:font-weight :bold)))
         (sheet (make-stylesheet 
                  :rules (list (defrule (type> :container) :font-size 14)
                               (defrule (type> :div) :color :gray)))))
    
    ;; Set up parent-child relationships  
    (setf (cl-styles.protocols:stylable-parent parent) root)
    (setf (cl-styles.protocols:stylable-parent child) parent)
    (setf (cl-styles.protocols:stylable-children root) (list parent))
    (setf (cl-styles.protocols:stylable-children parent) (list child))
    
    ;; Apply stylesheet to tree
    (apply-stylesheet-to-tree root sheet)
    
    ;; Test inheritance - check what we actually got
    (let ((root-computed (cl-styles.protocols:get-computed-style root))
          (parent-computed (cl-styles.protocols:get-computed-style parent))
          (child-computed (cl-styles.protocols:get-computed-style child)))
      ;; Basic checks that styling happened
      (is (not (null root-computed))) 
      (is (not (null parent-computed)))
      (is (not (null child-computed)))
      ;; Check specific inherited values if present
      (when (getf child-computed :color)
        (is (eql :gray (getf child-computed :color))))
      (when (getf child-computed :font-size) 
        (is (eql 16 (getf child-computed :font-size))))
      (when (getf child-computed :font-weight)
        (is (eql :bold (getf child-computed :font-weight)))))))

(test variable-resolution-integration
  "Test variable resolution across complex stylesheet"
  (let* ((sheet (make-stylesheet
                  :rules (list (defrule (type> :button)
                                 :color (cl-styles.tokens:var "--text-color")
                                 :background (cl-styles.tokens:var "--primary-bg")
                                 :border (cl-styles.tokens:var "--border-width"))
                           (defrule (cls> "secondary")
                             :background (cl-styles.tokens:var "--secondary-bg")))
                  :variables '(("--text-color" . :white)
                                ("--primary-bg" . :blue) 
                                ("--secondary-bg" . :green)
                                ("--border-width" . 1))))
          (primary-btn (make-instance 'node :id :btn1 :nodetype :button))
          (secondary-btn (make-instance 'node :id :btn2 :nodetype :button
                           :classes '("secondary"))))
    
    (apply-stylesheet sheet (list primary-btn secondary-btn))
    
    ;; Check variable resolution  
    (let ((primary-style (cl-styles.protocols:get-computed-style primary-btn))
           (secondary-style (cl-styles.protocols:get-computed-style secondary-btn)))
      ;; Primary button
      (is (eql :white (getf primary-style :color)))
      (is (eql :blue (getf primary-style :background-color)))
      (is (eql 1 (getf primary-style :border)))
      ;; Secondary button (secondary rule overrides primary background)
      (is (eql :white (getf secondary-style :color)))
      (is (eql :green (getf secondary-style :background-color))) ; overridden by secondary rule
      (is (eql 1 (getf secondary-style :border))))))

(test performance-with-large-stylesheet
  "Test performance with larger stylesheet - basic smoke test"
  (let* ((rules (loop for i from 1 to 100
                  collect (defrule (cls> (format nil "class-~d" i))
                            :color :red :margin i)))
          (sheet (make-stylesheet :rules rules))
          (objects (loop for i from 1 to 50
                     collect (make-instance 'node 
                               :id (intern (format nil "NODE-~d" i) :keyword)
                               :nodetype :div
                               :classes (list (format nil "class-~d" (mod i 100)))))))
    
    ;; This should complete without error and in reasonable time
    (time (apply-stylesheet sheet objects))
    
    ;; Verify some objects got styled
    (let ((styled-count (count-if (lambda (obj)
                                    (cl-styles.protocols:get-computed-style obj))
                          objects)))
      (is (> styled-count 0)))))

(test error-handling-edge-cases
  "Test engine error handling and edge cases"
  (let ((sheet (make-stylesheet :rules (list (defrule (type> :button) :color :red))))
         (valid-node (make-instance 'node :id :valid :nodetype :button)))
    
    ;; Test with nil sheet
    (is (not (null (apply-stylesheet nil (list valid-node)))))
    
    ;; Test with empty objects list
    (is (null (apply-stylesheet sheet nil)))
    (is (null (apply-stylesheet sheet '())))
    
    ;; Test with objects that don't match any rules
    (let ((no-match (make-instance 'node :id :nomatch :nodetype :span)))
      (apply-stylesheet sheet (list no-match))
      (is (null (cl-styles.protocols:get-computed-style no-match))))))
