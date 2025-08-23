(uiop:define-package :cl-styles.tests/smoke
  (:use :cl :fiveam)
  (:import-from :cl-styles.api)
  (:import-from :cl-styles.properties #:style-contract-violation)
  (:export #:suite))

(in-package :cl-styles.tests/smoke)

(def-suite cl-styles/smoke
  :in cl-styles.tests:cl-styles-test)

(in-suite cl-styles/smoke)

;; Minimal node type for smoke testing
(defclass node ()
  ((id :initarg :id :accessor id)
   (classes :initarg :classes :initform nil :accessor classes)
   (nodetype :initarg :nodetype :accessor nodetype)
   (style :initarg :style :initform nil :accessor style)
   (parent :accessor parent)
   (kids :initarg :children :initform nil :accessor kids)
   (computed :initform nil :accessor computed)))

(flet ((->sel (x)
         (etypecase x
           (null nil)
           (string (string-downcase x))
           (symbol (string-downcase (symbol-name x))))))
  ;; ID as string
  (defmethod cl-styles.protocols:stylable-id ((n node))
    (->sel (id n)))
  ;; TYPE as string
  (defmethod cl-styles.protocols:stylable-type ((n node))
    (->sel (nodetype n)))
  ;; CLASSES as list of strings
  (defmethod cl-styles.protocols:stylable-classes ((n node))
    (mapcar #'->sel (or (classes n) '()))))
(defmethod cl-styles.protocols:stylable-inline-style ((n node)) (style n))
(defmethod cl-styles.protocols:stylable-attributes ((n node)) nil)
(defmethod cl-styles.protocols:stylable-state ((n node)) nil)
(defmethod cl-styles.protocols:stylable-parent ((n node)) (parent n))
(defmethod cl-styles.protocols:stylable-children ((n node)) (kids n))
(defmethod cl-styles.protocols:stylable-index ((n node))
  (let* ((p (parent n)) (sibs (and p (kids p))))
    (or (position n sibs :test #'eq) 0)))

(defstruct style-patch path computed)
(defmethod cl-styles.protocols:set-computed-style ((n node) computed)
  (setf (computed n) computed)
  (make-style-patch :path (list :by-id (id n)) :computed computed))
(defmethod cl-styles.protocols:get-computed-style ((n node)) (computed n))

(test simple-match
  (let* ((a (make-instance 'node :id :a :nodetype :container :classes '("btn") :style '(:width 1)))
         (b (make-instance 'node :id :b :nodetype :text :classes '("btn" "danger")))
         (root (make-instance 'node :id :root :nodetype :container :children (list a b))))
    (setf (parent a) root (parent b) root)
    (let* ((sheet (cl-styles.sheet:make-stylesheet :rules (list (cl-styles.rule:defrule (cl-styles.selector:cls> "btn")
                                                                  :bg :blue)
                                                                (cl-styles.rule:defrule (cl-styles.selector:type> :text)
                                                                  :color :red))
                                                   :variables nil))
           (patches (cl-styles.engine:apply-stylesheet-to-tree root sheet :return :patches)))
      (is (>= (length patches) 2))
      (is (eql :blue (getf (computed a) :background-color)))
      (is (eql 1 (getf (computed a) :width)))
      (is (eql :red (getf (computed b) :color))))))

(test shorthands-and-variables
  (let* ((root (make-instance 'node :id :root :nodetype :container :style nil :children nil))
         (child (make-instance 'node :id :child :nodetype :container :style '(:padding (2 3))))
         (sheet (cl-styles.sheet:make-stylesheet
                 :rules (list (cl-styles.rule:defrule (cl-styles.selector:id> :child)
                                :gap 1
                                :color (cl-styles.tokens:var "--accent")))
                 :variables '(("--accent" . :green)))))
    (setf (kids root) (list child) (parent child) root)
    (let ((patches (cl-styles.engine:apply-stylesheet-to-tree root sheet :return :patches)))
      (declare (ignore patches))
      (is (= 2 (getf (computed child) :padding-top)))
      (is (= 3 (getf (computed child) :padding-right)))
      (is (= 2 (getf (computed child) :padding-bottom)))
      (is (= 3 (getf (computed child) :padding-left)))
      (is (= 1 (getf (computed child) :row-gap)))
      (is (eql :green (getf (computed child) :color))))))

(test inheritance
  (let* ((root (make-instance 'node :id :root :nodetype :container :style '(:color :purple)))
         (child (make-instance 'node :id :child :nodetype :text :style nil))
         (sheet (cl-styles.sheet:make-stylesheet :rules (list) :variables nil)))
    (setf (kids root) (list child) (parent child) root)
    (cl-styles.engine:apply-stylesheet-to-tree root sheet :return :patches)
    (is (eql :purple (getf (computed child) :color)))))

(test property-validation-and-groups
  (let* ((root (make-instance 'node :id :root :nodetype :container :style '(:display :flex :align-items :start :flex-wrap :wrap)))
         (sheet (cl-styles.sheet:make-stylesheet :rules (list) :variables nil)))
    (is (member :flex-grow (cl-styles.properties:properties-for-layout :flex)))
    (cl-styles.engine:apply-stylesheet-to-tree root sheet :return :patches)
    ;; :start should normalize to :flex-start for align-items
    (is (eql :flex-start (getf (computed root) :align-items)))
    ;; invalid enum should raise
    (signals cl-styles.properties:style-contract-violation
      (cl-styles.properties:ensure-declarations '(:flex-wrap :invalid)))
    ;; groups provide padding set
    (let ((pad-props (cl-styles.properties:properties-for-group :padding)))
      (is (find :padding-top pad-props))
      (is (find :padding-left pad-props)))))
