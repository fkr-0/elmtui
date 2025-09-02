(uiop:define-package :cl-styles.tests/engine
  (:use :cl :fiveam)
  (:import-from :cl-styles.api)
  (:export))

(in-package :cl-styles.tests/engine)

(def-suite cl-styles/engine
  :in cl-styles.tests:cl-styles-test)

(in-suite cl-styles/engine)

(defclass enode ()
  ((id :initarg :id :accessor id)
   (classes :initarg :classes :initform nil :accessor classes)
   (snodetype :initarg :snodetype :accessor snodetype)
   (style :initarg :style :initform nil :accessor style)
   (kids :initarg :children :initform nil :accessor kids)
   (parent :accessor parent)
   (computed :initform nil :accessor computed)))
;; simply print all members as print-object
(defmethod print-object ((n enode) stream)
  (print-unreadable-object (n stream :type t)
    (format stream "id=~a type=~a classes=~a style=~a computed=~a kids=~a"
            (id n) (snodetype n) (classes n) (style n) (computed n) (kids n))))
(flet ((->sel (x)
         (etypecase x
           (null nil)
           (string (string-downcase x))
           (symbol (string-downcase (symbol-name x))))))
  ;; ID as string
  (defmethod cl-styles.protocols:stylable-id ((n enode))
    (->sel (id n)))
  ;; TYPE as string
  (defmethod cl-styles.protocols:stylable-type ((n enode))
    (->sel (snodetype n)))
  ;; CLASSES as list of strings
  (defmethod cl-styles.protocols:stylable-classes ((n enode))
    (mapcar #'->sel (or (classes n) ))))

;; (defmethod cl-styles.protocols:stylable-id ((n enode)) (id n))
;; (defmethod cl-styles.protocols:stylable-classes ((n enode)) (classes n))
;; (defmethod cl-styles.protocols:stylable-type ((n enode)) (snodetype n))
(defmethod cl-styles.protocols:stylable-inline-style ((n enode)) (style n))
(defmethod cl-styles.protocols:stylable-children ((n enode)) (kids n))
(defmethod cl-styles.protocols:stylable-parent ((n enode)) (parent n))
(defmethod cl-styles.protocols:set-computed-style ((n enode) computed)
  (setf (computed n) computed)
  computed)
(defmethod cl-styles.protocols:get-computed-style ((n enode)) (computed n))

(test cascade-and-specificity
  (let* ((n (make-instance 'enode :id :x :snodetype :box :style '(:color :blue)))
         (sheet (cl-styles.sheet:make-stylesheet
                 :rules (list (cl-styles.rule:defrule (cl-styles.selector:type> :box)
                                :color :red) ; lower specificity
                              (cl-styles.rule:defrule (cl-styles.selector:id> :x)
                                :color :green))))) ; higher specificity
    (cl-styles.engine:apply-stylesheet-to-tree n sheet :return :patches)
    (is (eql :green (getf (computed n) :color)))))

(test variables-and-inheritance
  (let* ((child (make-instance 'enode :id :c :snodetype :text))
         (root (make-instance 'enode :id :r :snodetype :container :children (list child)
                                     :style '(:color (cl-styles.tokens:var "--accent"))))
         (sheet (cl-styles.sheet:make-stylesheet :rules nil :variables '(("--accent" . :orange)))))
    (setf (parent child) root)
    (cl-styles.engine:apply-stylesheet-to-tree root sheet :return :objects)
    ;; (let ((patches (cl-styles.engine:apply-stylesheet-to-tree root sheet :return :objects)))
    ;;   cl-styles.engine:apply-stylesheet
    ;; (list root patches)))
    (is (eql :orange (getf (computed child) :color)))))
