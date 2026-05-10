;;;===============================================================
;;; tests/base-elements-tests.lisp
;;; FiveAM tests for the CLOS-backed Base-DSL implementation
;;;===============================================================
(uiop:define-package :elmtui.tests.base-elements
  (:use :cl :fiveam
        :elmtui.view.base-elements)               ; public helpers
                                        ; concrete classes
  (:import-from :alexandria #:ensure-list))

(in-package :elmtui.tests.base-elements)

(def-suite elmtui/bs-elements
  :in elmtui.tests:elmtui-test
  :description "Unit tests for Base-DSL CLOS classes")

(in-suite elmtui/bs-elements)

;; (defsuite elmtui/bs-elements
;;   :description "Unit tests for Base-DSL CLOS classes")
;; (in-suite elmtui/bs-elements)

;;; ---------------------------------------------------------------
;;; 1. Normalisation → correct class & defaults
;;; ---------------------------------------------------------------
(test base-elements-label-normalisation
  (let ((obj (normalize-base-dsl '(:label :id :greet :content "Hi"))))
    (is (typep obj 'elmtui.view.base-elements::label-element))
    (is (string= "Hi" (elmtui.view.base-elements::label-content obj)))
    (is (eq :greet (element-id obj)))
    (is (eq :label (elmtui.view.base-elements::element-type obj)))))

(test base-elements-checkbox-defaults
  (let ((obj (normalize-base-dsl '(:checkbox :id :agree :label "I agree"))))
    (is (typep obj 'elmtui.view.base-elements::checkbox-element))
    (is (not (elmtui.view.base-elements::checkbox-checked-p obj)))
    (is (elmtui.view.base-elements::checkbox-focusable-p obj))
    (is (not (elmtui.view.base-elements::checkbox-disabled-p obj)))))

;;; ---------------------------------------------------------------
;;; 2. Traversal helpers
;;; ---------------------------------------------------------------
(test base-elements-traversal-and-find
  (let* ((tree (normalize-base-dsl
                '(:container :id :root
                  :children ((:label  :id :lbl1 :content "A")
                             (:container :id :inner
                                         :children ((:label  :id :lbl2 :content "B")
                                                    (:button :id :btn  :content "Go")))))))
         (labels (find-elements-by-type tree :label))
         (btn    (find-element-by-id tree :btn)))
    (is (= 2 (length labels)))
    (is (every (lambda (n) (typep n 'elmtui.view.base-elements::label-element)) labels))
    (is (typep btn 'elmtui.view.base-elements::button-element))
    (is (string= "Go" (elmtui.view.base-elements::button-content btn)))))

;;; ---------------------------------------------------------------
;;; 3. map-dsl-elements can mutate / transform nodes
;;; ---------------------------------------------------------------
(test base-elements-map-transform-uppercase-labels
  (let* ((tree  (normalize-base-dsl '(:label :id :l1 :content "hello")))
         (upper (map-dsl-elements
                 (lambda (node)
                   (if (typep node 'elmtui.view.base-elements::label-element)
                       (update-dsl-element node
                                           :content
                                           (string-upcase
                                            (elmtui.view.base-elements::label-content node)))
                       node))
                 tree)))
    (is (string= "HELLO" (elmtui.view.base-elements::label-content upper)))))

;;; ---------------------------------------------------------------
;;; 4. base-dsl-p recognises invalid element types
;;; ---------------------------------------------------------------
(test base-elements-invalid-type-detected
  (is (not (base-dsl-p '(:unknown-element :id :x)))))

;;; ---------------------------------------------------------------
;;; 5. make-dsl-element & update-dsl-element round-trip
;;; ---------------------------------------------------------------
(test base-elements-constructor-and-update
  (let* ((btn (make-dsl-element :button :id :ok :content "OK"))
         (btn* (update-dsl-element btn :content "Confirm" :disabled t)))
    (is (typep btn* 'elmtui.view.base-elements::button-element))
    (is (string= "Confirm" (elmtui.view.base-elements::button-content btn*)))
    (is-true (elmtui.view.base-elements::button-disabled-p btn*))))

(test base-elements-constructor-unknown-type-errors
  (signals error
    (make-dsl-element :unknown-widget :id :x)))

(test base-elements-validate-children-through-object-path
  (signals error
    (validate-base-dsl
      '(:container :id :root
        :children ((:label :id :ok :content "ok")
                    (:unknown-widget :id :bad))))))

(test base-elements-computed-props-concurrency-regression
  "Regression test for concurrent access to computed props used by element-changed-p."
  (let* ((elements (loop for i from 0 below 48
                         collect (make-instance 'container-element
                                                :id (intern (format nil "E~D" i) :keyword))))
         (errors '())
         (errors-lock (bordeaux-threads:make-lock "base-elements-errors"))
         (threads
           (loop repeat 8
                 collect (bordeaux-threads:make-thread
                          (lambda ()
                            (dotimes (i 4000)
                              (let* ((el (nth (mod i (length elements)) elements))
                                     (p (elmtui.view.base-elements::element-props el)))
                                (handler-case
                                    (progn
                                      (setf (getf p :size) (mod i 7))
                                      (setf (getf p :layout) (mod i 11))
                                      (elmtui.view.base-elements::snapshot-props-for-diff el)
                                      (setf (elmtui.view.base-elements::element-dirty-p el) (oddp i))
                                      (elmtui.view.base-elements::element-changed-p el))
                                  (condition (c)
                                    (bordeaux-threads:with-lock-held (errors-lock)
                                      (push c errors)))))))))))
    (dolist (th threads)
      (bordeaux-threads:join-thread th))
    (is (null errors)
        "Concurrent computed-props access should not signal conditions; got: ~S" errors)))

;;; --- End of file ------------------------------------------------
