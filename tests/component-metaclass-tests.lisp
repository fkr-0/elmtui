;;;; Component Metaclass Tests
;;;; Tests for the component-class metaclass that stores metadata in class metaobjects

(uiop:define-package :elmtui-tests.component-metaclass
  (:use :cl :fiveam)
  (:import-from :sb-mop
                #:class-of)
  (:export #:component-metaclass-suite))

(in-package :elmtui-tests.component-metaclass)

(def-suite component-metaclass-suite
  :in elmtui.tests:elmtui-test
  :description "Test suite for component metaclass")

(in-suite component-metaclass-suite)

(test component-class-metaclass-creation
  "Test that component-class metaclass can be created and used"
  (finishes
    (defclass test-component-class ()
      ()
      (:metaclass elmtui.ui.component-metaclass:component-class)))
  (is (eq (class-of (find-class 'test-component-class))
          (find-class 'elmtui.ui.component-metaclass:component-class))
      "component-class should be a metaclass")
  ;; Clean up
  (setf (find-class 'test-component-class) nil))

(test metadata-can-be-stored-and-retrieved
  "Test that metadata can be stored and retrieved from class metaobject"
  ;; First define a class without metadata
  (finishes
    (defclass test-metadata-component ()
      ()
      (:metaclass elmtui.ui.component-metaclass:component-class)))
  ;; Then set the metadata on the class metaobject
  (let* ((metadata (elmtui.ui.component-metaclass:make-metadata
                    :props '(:label "Test" :value 42)
                    :documentation "A test component"
                    :examples '((:test-component :label "Example")))))
    (setf (elmtui.ui.component-metaclass:class-metadata (find-class 'test-metadata-component))
          metadata))
  ;; Now retrieve and verify the metadata
  (let* ((test-class (find-class 'test-metadata-component))
         (retrieved-metadata (elmtui.ui.component-metaclass:class-metadata test-class)))
    (is (not (null retrieved-metadata))
        "Metadata should be retrievable from class")
    (is (equalp (getf retrieved-metadata :props) '(:label "Test" :value 42))
        "Props should be stored correctly")
    (is (string= (getf retrieved-metadata :documentation) "A test component")
        "Documentation should be stored correctly")
    (is (equalp (getf retrieved-metadata :examples) '((:test-component :label "Example")))
        "Examples should be stored correctly"))
  ;; Clean up
  (setf (find-class 'test-metadata-component) nil))

(test make-metadata-creates-proper-structures
  "Test that make-metadata creates proper metadata structures"
  (let ((metadata1 (elmtui.ui.component-metaclass:make-metadata
                    :props '(:width 100 :height 200)))
        (metadata2 (elmtui.ui.component-metaclass:make-metadata
                    :documentation "A simple component"))
        (metadata3 (elmtui.ui.component-metaclass:make-metadata
                    :props '(:enabled t)
                    :documentation "Complex component"
                    :examples '((:comp :enabled t)))))
    ;; Test metadata with props only
    (is (listp metadata1)
        "make-metadata should return a list")
    (is (equalp (getf metadata1 :props) '(:width 100 :height 200))
        "Props should be stored in metadata")
    ;; Test metadata with documentation only
    (is (listp metadata2)
        "make-metadata should return a list")
    (is (string= (getf metadata2 :documentation) "A simple component")
        "Documentation should be stored in metadata")
    ;; Test metadata with all fields
    (is (listp metadata3)
        "make-metadata should return a list")
    (is (equalp (getf metadata3 :props) '(:enabled t))
        "Props should be stored")
    (is (string= (getf metadata3 :documentation) "Complex component")
        "Documentation should be stored")
    (is (equalp (getf metadata3 :examples) '((:comp :enabled t)))
        "Examples should be stored")))
