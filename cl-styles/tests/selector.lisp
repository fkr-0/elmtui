(uiop:define-package :cl-styles.tests/selector
  (:use :cl :fiveam)
  (:import-from :cl-styles.api)
  (:export))

(in-package :cl-styles.tests/selector)

(def-suite cl-styles/selector
  :in cl-styles.tests:cl-styles-test)

(in-suite cl-styles/selector)

;; Reuse the test node from smoke
(defclass snode ()
  ((id :initarg :id :accessor id)
   (classes :initarg :classes :initform nil :accessor classes)
   (snodetype :initarg :snodetype :accessor snodetype)
   (kids :initarg :children :initform nil :accessor kids)
   (parent :accessor parent)))

(defmethod cl-styles.protocols:stylable-id ((n snode)) (id n))
(defmethod cl-styles.protocols:stylable-classes ((n snode)) (classes n))
(defmethod cl-styles.protocols:stylable-type ((n snode)) (snodetype n))
(defmethod cl-styles.protocols:stylable-children ((n snode)) (kids n))
(defmethod cl-styles.protocols:stylable-parent ((n snode)) (parent n))
(defmethod cl-styles.protocols:stylable-index ((n snode))
  (let* ((p (parent n)) (sibs (and p (kids p))))
    (or (position n sibs :test #'eq) 0)))

(test simple-selectors
      (let ((n (make-instance 'snode :id :a :snodetype :box :classes '(:red :big))))
        (is (cl-styles.selector:match-selector-p (cl-styles.selector:type> :box) n))
        (is (cl-styles.selector:match-selector-p (cl-styles.selector:id> :a) n))
        (is (cl-styles.selector:match-selector-p (apply #'cl-styles.selector:cls> '(:red :big)) n))
        (is (not (cl-styles.selector:match-selector-p (apply #'cl-styles.selector:cls> '(:blue)) n)))))

(test combinators
      (let* ((c (make-instance 'snode :id :c :snodetype :leaf))
             (b (make-instance 'snode :id :b :snodetype :mid :children (list c)))
             (a (make-instance 'snode :id :a :snodetype :root :children (list b))))
        (setf (parent b) a (parent c) b)
        (is (cl-styles.selector:match-selector-p (cl-styles.selector:child> (cl-styles.selector:type> :root)
                                                                            (cl-styles.selector:type> :mid)) b))
        (is (cl-styles.selector:match-selector-p (cl-styles.selector:descendant> (cl-styles.selector:type> :root)
                                                                                 (cl-styles.selector:type> :leaf)) c))
        (is (cl-styles.selector:match-selector-p (cl-styles.selector:has (cl-styles.selector:type> :leaf)) b))
        (is (cl-styles.selector:match-selector-p (cl-styles.selector:sel-not (cl-styles.selector:type> :foo)) a))))

(test specificity-order
      (let ((id (cl-styles.selector:selector-specificity (cl-styles.selector:id> :x)))
            (cls (cl-styles.selector:selector-specificity (apply #'cl-styles.selector:cls> '(:x))))
            (typ (cl-styles.selector:selector-specificity (cl-styles.selector:type> :x))))
        (flet ((gt (a b)
                 (or (> (first a) (first b))
                     (and (= (first a) (first b)) (> (second a) (second b)))
                     (and (= (first a) (first b)) (= (second a) (second b)) (> (third a) (third b))))))
          (is (gt id cls))
          (is (gt cls typ)))))
