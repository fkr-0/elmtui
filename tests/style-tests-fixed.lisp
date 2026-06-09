;;;; STYLE Module Tests
;;;; Test suite for elmtui styling system using cl-styles

(uiop:define-package :elmtui.style.tests
  (:use :cl :fiveam)
  (:import-from :cl-styles.api 
    #:make-stylesheet #:defrule #:apply-stylesheet #:apply-stylesheet-to-tree
    #:type> #:id> #:cls> #:attr> #:state> #:sel-and #:sel-or
    #:var #:rgb #:rgba #:px #:em #:percent
    #:add-rule #:remove-rule
    #:get-computed-style #:set-computed-style
    #:stylable-id #:stylable-classes #:stylable-type #:stylable-inline-style
    #:stylable-parent #:stylable-children)
  (:export #:run-style-tests #:style-test-suite))

(in-package :elmtui.style.tests)

(def-suite style-test-suite
  :description "Test suite for elmtui styling system using cl-styles")

(in-suite style-test-suite)

;; Simple test node class implementing cl-styles protocols
(defclass test-node ()
  ((id :initarg :id :accessor node-id :initform nil)
   (classes :initarg :classes :accessor node-classes :initform nil)
   (element-type :initarg :type :accessor node-type :initform :div)
   (inline-style :initarg :style :accessor node-style :initform nil)
   (computed-style :accessor node-computed-style :initform nil)
   (parent :accessor node-parent :initform nil)
   (children :accessor node-children :initform nil)))

;; Implement cl-styles protocols
(defmethod stylable-id ((obj test-node)) (node-id obj))
(defmethod stylable-classes ((obj test-node)) (node-classes obj))
(defmethod stylable-type ((obj test-node)) (node-type obj))
(defmethod stylable-inline-style ((obj test-node)) (node-style obj))
(defmethod stylable-parent ((obj test-node)) (node-parent obj))
(defmethod stylable-children ((obj test-node)) (node-children obj))
(defmethod set-computed-style ((obj test-node) style) 
  (setf (node-computed-style obj) style) obj)
(defmethod get-computed-style ((obj test-node)) (node-computed-style obj))

;; Test for basic stylesheet functionality
(test style-sheet-basic
  "Test basic stylesheet creation and rule application"
  (let* ((sheet (make-stylesheet
                  :rules (list
                    (defrule (type> :button)
                      :color :red :background :blue)
                    (defrule (id> :header)
                      :font-size 16)
                    (defrule (cls> "primary")
                      :border 1))))
         (button (make-instance 'test-node :id :my-btn :type :button))
         (header (make-instance 'test-node :id :header :type :div))
         (primary-btn (make-instance 'test-node :type :button :classes '("primary"))))
    
    (is (not (null sheet)) "Stylesheet should be created")
    
    ;; Apply stylesheet to objects
    (apply-stylesheet sheet (list button header primary-btn))
    
    ;; Test button styling
    (let ((button-style (get-computed-style button)))
      (is (not (null button-style)) "Button should have computed style")
      (is (eql :red (getf button-style :color)) "Button should have red color")
      (is (eql :blue (getf button-style :background)) "Button should have blue background"))
    
    ;; Test header styling  
    (let ((header-style (get-computed-style header)))
      (is (not (null header-style)) "Header should have computed style")
      (is (eql 16 (getf header-style :font-size)) "Header should have font-size 16"))
    
    ;; Test primary button (should get both button and primary styles)
    (let ((primary-style (get-computed-style primary-btn)))
      (is (not (null primary-style)) "Primary button should have computed style")
      (is (eql :red (getf primary-style :color)) "Primary button should have button color")
      (is (eql 1 (getf primary-style :border)) "Primary button should have primary border"))))

(test style-sheet-selectors
  "Test various selector types"
  (let* ((sheet (make-stylesheet
                  :rules (list
                    (defrule (type> :button) :color :blue)
                    (defrule (id> :special) :background :green)
                    (defrule (cls> "large") :font-size 20)
                    (defrule (sel-and (type> :button) (cls> "primary"))
                      :color :white :background :red))))
         (button (make-instance 'test-node :type :button))
         (special-div (make-instance 'test-node :id :special :type :div))
         (large-text (make-instance 'test-node :type :text :classes '("large")))
         (primary-button (make-instance 'test-node :type :button :classes '("primary"))))
    
    (apply-stylesheet sheet (list button special-div large-text primary-button))
    
    ;; Test type selector
    (let ((button-style (get-computed-style button)))
      (is (eql :blue (getf button-style :color)) "Button should match type selector"))
    
    ;; Test ID selector  
    (let ((special-style (get-computed-style special-div)))
      (is (eql :green (getf special-style :background)) "Special div should match ID selector"))
    
    ;; Test class selector
    (let ((large-style (get-computed-style large-text)))
      (is (eql 20 (getf large-style :font-size)) "Large text should match class selector"))
    
    ;; Test compound selector (should override simple type selector)
    (let ((primary-style (get-computed-style primary-button)))
      (is (eql :white (getf primary-style :color)) "Primary button should match compound selector")
      (is (eql :red (getf primary-style :background)) "Primary button should have red background"))))

(test style-inheritance
  "Test style inheritance between parent and child"
  (let* ((sheet (make-stylesheet
                  :rules (list
                    (defrule (type> :container)
                      :font-family "Arial" :color :black)
                    (defrule (type> :text)
                      :font-weight :bold))))
         (container (make-instance 'test-node :type :container))
         (text (make-instance 'test-node :type :text)))
    
    ;; Set up parent-child relationship
    (setf (stylable-parent text) container)
    (setf (stylable-children container) (list text))
    
    ;; Apply with inheritance
    (apply-stylesheet-to-tree container sheet)
    
    ;; Test parent styles
    (let ((container-style (get-computed-style container)))
      (is (equal "Arial" (getf container-style :font-family)) "Container should have Arial font")
      (is (eql :black (getf container-style :color)) "Container should have black color"))
    
    ;; Test child inheritance
    (let ((text-style (get-computed-style text)))
      (is (equal "Arial" (getf text-style :font-family)) "Text should inherit Arial font")
      (is (eql :black (getf text-style :color)) "Text should inherit black color")
      (is (eql :bold (getf text-style :font-weight)) "Text should have own bold weight"))))

(test style-variables
  "Test CSS variables functionality"
  (let* ((sheet (make-stylesheet
                  :rules (list
                    (defrule (type> :button)
                      :color (var "--text-color")
                      :background (var "--button-bg")))
                  :variables '(("--text-color" . :white)
                               ("--button-bg" . :blue))))
         (button (make-instance 'test-node :type :button)))
    
    (apply-stylesheet sheet (list button))
    
    (let ((button-style (get-computed-style button)))
      (is (eql :white (getf button-style :color)) "Variable should resolve to white")
      (is (eql :blue (getf button-style :background)) "Variable should resolve to blue"))))

(test inline-style-priority
  "Test that inline styles have highest priority"
  (let* ((sheet (make-stylesheet
                  :rules (list
                    (defrule (type> :button) :color :blue :background :gray))))
         (button (make-instance 'test-node 
                                :type :button 
                                :style '(:color :red :padding 10))))
    
    (apply-stylesheet sheet (list button))
    
    (let ((button-style (get-computed-style button)))
      (is (eql :red (getf button-style :color)) "Inline style should override rule")
      (is (eql :gray (getf button-style :background)) "Rule style should apply when not overridden")
      (is (eql 10 (getf button-style :padding)) "Inline style should be preserved"))))

(test dynamic-stylesheet-modification
  "Test adding and removing rules dynamically"
  (let* ((sheet (make-stylesheet
                  :rules (list (defrule (type> :button) :color :blue))))
         (button (make-instance 'test-node :type :button)))
    
    ;; Apply initial stylesheet
    (apply-stylesheet sheet (list button))
    (is (eql :blue (getf (get-computed-style button) :color)) "Initial color should be blue")
    
    ;; Add new rule
    (add-rule sheet (defrule (type> :button) :color :red :background :yellow))
    (apply-stylesheet sheet (list button))
    (let ((style (get-computed-style button)))
      (is (eql :red (getf style :color)) "New rule should override color")
      (is (eql :yellow (getf style :background)) "New rule should add background"))))

(defun run-style-tests ()
  "Run all style module tests"
  (run! 'style-test-suite))