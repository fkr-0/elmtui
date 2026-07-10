(uiop:define-package :stylesheet-tests
  (:use :cl :fiveam)
  (:import-from :cl-styles.sheet #:stylesheet-rules #:add-rule #:remove-rule #:make-stylesheet)
  (:export #:stylesheet-suite))
(in-package :stylesheet-tests)

(def-suite stylesheet-suite
  :description "Tests for stylesheet rule management."
  :in cl-styles.tests:cl-styles-test)

(in-suite stylesheet-suite)

(test add-rule
  (let ((ss (make-stylesheet :rules '((:selector ".a")))))
    (add-rule ss '(:selector ".b"))
    (is (equal (stylesheet-rules ss)
          '((:selector ".b") (:selector ".a"))))))

(test remove-rule
  (let ((ss (make-stylesheet :rules '((:selector ".a") (:selector ".b")))))
    (remove-rule ss '(:selector ".a"))
    (is (equal (stylesheet-rules ss)
          '((:selector ".b"))))))

(test add-and-remove-rule
  (let ((ss (make-stylesheet :rules '((:selector ".a")))))
    (add-rule ss '(:selector ".b"))
    (remove-rule ss '(:selector ".a"))
    (is (equal (stylesheet-rules ss)
          '((:selector ".b"))))))

(test stylesheet-with-variables
  "Test creating stylesheet with variables"
  (let ((ss (make-stylesheet :variables '(("--primary" . :blue)
                                          ("--size" . 16)))))
    (is (equal (cl-styles.sheet:stylesheet-variables ss)
               '(("--primary" . :blue) ("--size" . 16))))))

(test stylesheet-with-namespace
  "Test creating stylesheet with namespace"
  (let ((ss (make-stylesheet :namespace :my-theme)))
    (is (eql (cl-styles.sheet:stylesheet-namespace ss) :my-theme))))

(test empty-stylesheet
  "Test creating empty stylesheet has proper defaults"
  (let ((ss (make-stylesheet)))
    (is (null (cl-styles.sheet:stylesheet-rules ss)))
    (is (null (cl-styles.sheet:stylesheet-variables ss)))
    (is (null (cl-styles.sheet:stylesheet-namespace ss)))))

(test stylesheet-full-creation
  "Test creating stylesheet with all parameters"
  (let ((ss (make-stylesheet :rules '((:rule1) (:rule2))
                            :variables '(("--var1" . :val1))
                            :namespace :test-ns)))
    (is (equal (cl-styles.sheet:stylesheet-rules ss) '((:rule1) (:rule2))))
    (is (equal (cl-styles.sheet:stylesheet-variables ss) '(("--var1" . :val1))))
    (is (eql (cl-styles.sheet:stylesheet-namespace ss) :test-ns))))
