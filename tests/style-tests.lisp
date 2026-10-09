;;;; STYLE Module Tests
;;;; Test suite for elmtui styling system using cl-styles

(uiop:define-package :elmtui.style.tests
  (:use :cl :fiveam)
  (:import-from :cl-styles.api 
    #:make-stylesheet #:rule #:make-rule #:apply-stylesheet #:apply-stylesheet-to-tree
    #:type> #:id> #:cls> #:attr> #:state> #:sel-and #:sel-or
    #:var #:rgb #:rgba #:px #:em #:percent
    #:add-rule #:remove-rule #:compute-style)
  (:import-from :cl-styles.rule
    #:defrule)
  (:import-from :cl-styles.protocols
    #:stylable-id #:stylable-classes #:stylable-type #:stylable-inline-style
    #:stylable-parent #:stylable-children #:stylable-index #:stylable-attributes
    #:set-computed-style #:get-computed-style)
  (:export #:run-style-tests #:style-test-suite))

(in-package :elmtui.style.tests)

(def-suite style-test-suite
  :description "Test suite for elmtui styling system")

(in-suite style-test-suite)

(test computed-style-merge-preserves-flat-plist-pairs
  "Computed styles may override keys, but must never exchange property values."
  (let* ((node (elmtui.view.base-elements:dsl->objects
                '(:text :id :style-merge-regression :content "Wi-Fi"
                  :style (:bold t :fg-color :cyan))))
         (sheet (cl-styles.sheet:make-stylesheet :rules nil :variables nil
                                               :namespace nil)))
    (cl-styles.engine:apply-stylesheet-to-tree node sheet :return :objects)
    (let ((style (elmtui.view.element:el/styles node)))
      (is (evenp (length style)))
      (is (every #'keywordp
                 (loop for (key value) on style by #'cddr collect key)))
      (is (eql :cyan (getf style :fg-color)))
      (is (eql :cyan (getf style :color)))
      (is (eq t (getf style :bold)))
      (is (member :bold (getf style :attributes)))
      (is (not (eq :attributes (getf style :fg-color)))))
    ;; A second style computation must not corrupt previously merged pairs.
    (cl-styles.engine:apply-stylesheet-to-tree node sheet :return :objects)
    (is (eq :cyan (getf (elmtui.view.element:el/styles node) :color)))))


;; Test class that implements stylable protocols (based on cl-styles test node)
(defclass test-node ()
  ((id :initarg :id :accessor id)
   (classes :initarg :classes :initform nil :accessor classes)
   (nodetype :initarg :nodetype :accessor nodetype)
   (style :initarg :style :initform nil :accessor style)
   (parent :accessor parent :initarg :parent)
   (kids :initarg :children :initform nil :accessor kids)
   (computed :initform nil :accessor computed)))

;; Stylable protocol implementations - convert to strings as expected by cl-styles
(defun ->sel (x)
  (etypecase x
    (null nil)
    (string (string-downcase x))
    (keyword (string-downcase (symbol-name x)))
    (symbol (string-downcase (symbol-name x)))))

;; ID as string
(defmethod stylable-id ((n test-node))
  (->sel (id n)))
;; TYPE as string
(defmethod stylable-type ((n test-node))
  (->sel (nodetype n)))
;; CLASSES as list of strings
(defmethod stylable-classes ((n test-node))
  (mapcar #'->sel (or (classes n) nil)))

(defmethod stylable-inline-style ((n test-node)) (style n))
(defmethod stylable-attributes ((n test-node)) nil)
(defmethod stylable-parent ((n test-node)) (parent n))
(defmethod stylable-children ((n test-node)) (kids n))
(defmethod (setf stylable-children) (new-value (n test-node)) (setf (kids n) new-value))
(defmethod (setf stylable-parent) (new-value (n test-node)) (setf (parent n) new-value))
(defmethod stylable-index ((n test-node))
  (let* ((p (parent n)) (sibs (and p (kids p))))
    (or (position n sibs :test #'eq) 0)))

(defstruct style-patch path computed)
(defmethod set-computed-style ((n test-node) computed)
  (setf (computed n) computed)
  (make-style-patch :path (list :by-id (id n)) :computed computed))
(defmethod get-computed-style ((n test-node)) (computed n))

;; Helper to set parent-child relationships
(defun set-parent-child (parent child)
  "Set up parent-child relationship between nodes"
  (setf (parent child) parent)
  (push child (kids parent)))

;; Test for basic stylesheet functionality
(test style-sheet-basic
  "Test basic stylesheet functionality"
  (let ((stylesheet (make-stylesheet 
                     :rules (list
                             (defrule (type> :button) :color :red :padding 8))))
        (button (make-instance 'test-node :id :btn :nodetype :button)))
    (is (not (null stylesheet)) "Stylesheet should be created")
    
    ;; Apply stylesheet
    (apply-stylesheet stylesheet (list button))
    (let ((style (get-computed-style button)))
      (is (not (null style)) "Computed style should exist")
      (is (eql (getf style :color) :red) "Color should be red"))
    (is (eql (getf (get-computed-style button) :padding) 8) "Padding should be 8")))

;; Test for selectors
(test style-sheet-selectors
  "Test different selector types"
  (let ((stylesheet (make-stylesheet 
                     :rules (list
                             (defrule (type> :div) :margin 10)
                             (defrule (id> :main) :padding 20)
                             (defrule (cls> "highlight") :color :yellow)))))
    
    ;; Test type selector
    (let ((div-node (make-instance 'test-node :id :test-div :nodetype :div)))
      (apply-stylesheet stylesheet (list div-node))
      (is (eql (getf (get-computed-style div-node) :margin) 10)
        "Type selector should apply"))
    
    ;; Test id selector  
    (let ((main-node (make-instance 'test-node :id :main :nodetype :div)))
      (apply-stylesheet stylesheet (list main-node))
      (is (eql (getf (get-computed-style main-node) :padding) 20)
        "ID selector should apply"))
    
    ;; Test class selector
    (let ((highlight-node (make-instance 'test-node :id :test-highlight :nodetype :span :classes '("highlight"))))
      (apply-stylesheet stylesheet (list highlight-node))
      (is (eql (getf (get-computed-style highlight-node) :color) :yellow)
        "Class selector should apply"))))

;; Test for inheritance
(test style-inheritance
  "Test style inheritance between parent and child"
  (let ((stylesheet (make-stylesheet 
                     :rules (list
                             (defrule (type> :div) :font-family "Arial" :color :black)
                             (defrule (type> :span) :font-size 14))))
        (container (make-instance 'test-node :id :container :nodetype :div))
        (text (make-instance 'test-node :id :text :nodetype :span)))
    
    ;; Set up parent-child relationship
    (set-parent-child container text)
    
    ;; Apply to tree
    (apply-stylesheet-to-tree container stylesheet)
    
    ;; Check that styles were applied
    (let ((container-style (get-computed-style container))
          (text-style (get-computed-style text)))
      (is (not (null container-style)) "Container should have computed style")
      (is (not (null text-style)) "Text should have computed style"))))

;; Test for variables
(test style-variables
  "Test CSS variables"
  (let ((stylesheet (make-stylesheet 
                     :variables '(("--primary-color" . :blue) ("--margin" . 10))
                     :rules (list
                             (defrule (type> :button) 
                               :color (var "--primary-color") 
                               :margin (var "--margin")))))
        (button (make-instance 'test-node :id :test-button :nodetype :button)))
    
    ;; Apply styles
    (apply-stylesheet stylesheet (list button))
    
    (let ((button-style (get-computed-style button)))
      (is (not (null button-style)) "Button should have computed style")
      (when button-style
        (is (eql (getf button-style :color) :blue) 
            "Button should use variable value for color")
        (is (eql (getf button-style :margin) 10) 
            "Button should use variable for margin")))))

;; Test for inline style priority
(test inline-style-priority
  "Test that inline styles have highest priority"
  (let ((stylesheet (make-stylesheet 
                     :rules (list
                             (defrule (type> :button) :color :red :padding 8))))
        (button (make-instance 'test-node 
                               :id :test-inline-button
                               :nodetype :button
                               :style '(:color :green))))
    (apply-stylesheet stylesheet (list button))
    
    (let ((style (get-computed-style button)))
      (is (not (null style)) "Button should have computed style")
      (when style
        (is (eql (getf style :color) :green) 
            "Inline style should override rule")
        (is (eql (getf style :padding) 8) 
            "Non-inline properties should come from rule")))))

;; Test for dynamic stylesheet modification
(test dynamic-stylesheet-modification
  "Test adding and removing rules dynamically"
  (let ((stylesheet (make-stylesheet 
                     :rules (list
                             (make-rule :selector (type> :button) :declarations '(:color :red)))))
        (button (make-instance 'test-node :id :test-dynamic :nodetype :button)))
    
    ;; Apply initial
    (apply-stylesheet stylesheet (list button))
    (is (eql (getf (get-computed-style button) :color) :red)
        "Initial color should be red")
    
    ;; Add new rule that should override
    (add-rule stylesheet (make-rule :selector (type> :button) :declarations '(:color :blue)))
    
    ;; Reapply
    (apply-stylesheet stylesheet (list button))
    (is (eql (getf (get-computed-style button) :color) :blue)
        "New rule should override color")))

;; Test runner
(defun run-style-tests ()
  "Run all style tests"
  (run! 'style-test-suite))
