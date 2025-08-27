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
