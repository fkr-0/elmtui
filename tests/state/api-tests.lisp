;;;===============================================================
;;; File: tests/state/api-tests.lisp
;;; Unit tests for elmtui.state.api
;;;===============================================================

(uiop:define-package :elmtui-tests.state.api
  (:use :cl :fiveam :elmtui.state.api)
  (:export :run-state-api-tests))

(in-package :elmtui-tests.state.api)

;; Define a test suite
(def-suite elmtui-state-api-suite
  :description "Tests for elmtui.state.api package.")

(in-suite elmtui-state-api-suite)

;; Test case for UPDATE-RESULT struct
(test update-result-creation
  (let ((ur (make-update-result :patches '((:foo 1)) :commands '((:bar)))))
    (is (typep ur 'update-result))
    (is (equal (ur-patches ur) '((:foo 1))))
    (is (equal (ur-commands ur) '((:bar))))))

;; Test case for UR-HAS-COMMAND-P
(test ur-has-command-p-basic
  (let ((ur (make-update-result :commands '((:cmd1) (:cmd2 "arg")))))
    (is-true (ur-has-command-p ur '(:cmd1)))
    (is-true (ur-has-command-p ur '(:cmd2 "arg")))
    (is-false (ur-has-command-p ur '(:cmd3)))
    (is-false (ur-has-command-p ur '(:cmd2 "wrong-arg")))))

;; Test case for UR-ADD-COMMAND
(test ur-add-command-basic
  (let ((ur (make-update-result :commands '((:initial-cmd)))))
    (ur-add-command ur '(:new-cmd))
    (is (equal (ur-commands ur) '((:new-cmd) (:initial-cmd)))) ; Commands are consed to the front
    (ur-add-command ur '(:another-cmd "val"))
    (is (equal (ur-commands ur) '((:another-cmd "val") (:new-cmd) (:initial-cmd))))))

;; Test case for APPLICATION-STATE struct
(test application-state-creation
  (let ((as (make-application-state)))
    (is (typep as 'application-state))
    (is (hash-table-p (application-state-data as)))
    (is (eq (application-state-backend as) :hash-table))
    (is (listp (application-state-observers as)))
    (is (application-state-lock as))
    (is (listp (application-state-log as)))
    (is (listp (application-state-history as)))
    (is (listp (application-state-undone as)))))

;; Test case for GET-PATH and SET-PATH (from elmtui.state, re-exported by api)
;; These functions are implemented in src/state/state.lisp, but exposed via api.lisp
;; Need to ensure they work as expected through the API.
(test get-set-path-basic
  (let* ((app-state (make-application-state))
         (initial-data (application-state-data app-state)))
    (set-path initial-data '(:user :name) "Alice")
    (is (equal (get-path '(:user :name) (application-state-data app-state)) "Alice"))

    (set-path (application-state-data app-state) '(:settings :theme) :dark)
    (is (equal (get-path '(:settings :theme) (application-state-data app-state)) :dark))

    (set-path (application-state-data app-state) '(:user :name) "Bob")
    (is (equal (get-path '(:user :name) (application-state-data app-state)) "Bob"))

    (is (null (get-path '(:user :age) (application-state-data app-state))))
    (is (equal (get-path '(:user :age) (application-state-data app-state) :not-found) :not-found))))

;; Test case for REMOVE-PATH
(test remove-path-basic
  (let* ((app-state (make-application-state))
         (initial-data (application-state-data app-state)))
    (set-path initial-data '(:user :name) "Alice")
    (set-path (application-state-data app-state) '(:user :age) 30)
    (set-path (application-state-data app-state) '(:settings :theme) :dark)

    (remove-path (application-state-data app-state) '(:user :age))
    (is (null (get-path '(:user :age) (application-state-data app-state))))
    (is (equal (get-path '(:user :name) (application-state-data app-state)) "Alice"))

    (let ((original-data (application-state-data app-state)))
      (remove-path (application-state-data app-state) '(:user :email))
      (is (equal (application-state-data app-state) original-data)))

    (remove-path (application-state-data app-state) '(:settings :theme))
    (is (null (get-path '(:settings :theme) (application-state-data app-state))))))

;; Test case for MERGE-PATCH and MERGE-PATCHES
(test merge-patches-basic
  (let* ((app-state (make-application-state))
         (initial-data (application-state-data app-state)))
    (set-path initial-data '(:user :name) "Alice")
    (set-path (application-state-data app-state) '(:user :age) 30)

    (merge-patch (application-state-data app-state) '((:user :name) "Bob"))
    (is (equal (get-path '(:user :name) (application-state-data app-state)) "Bob"))

    (merge-patches (application-state-data app-state)
                   '(((:user :age) 31)
                     ((:settings :theme) :light)))
    (is (equal (get-path '(:user :age) (application-state-data app-state)) 31))
    (is (equal (get-path '(:settings :theme) (application-state-data app-state)) :light))

    (merge-patch (application-state-data app-state) '((:user :age) :elmtui-delete-path))
    (is (null (get-path '(:user :age) (application-state-data app-state))))))

;; Test case for GET-COMPONENT-BY-PATH and STORE-COMPONENT-AT-PATH
(test component-path-management
  (let ((app-state (make-application-state)))
    ;; Store a component
    (elmtui.state:store-component-at-path app-state '(:my-component) "ComponentInstance1")
    (is (equal (elmtui.state:get-component-by-path app-state '(:my-component)) "ComponentInstance1"))

    ;; Store another component nested
    (elmtui.state:store-component-at-path app-state '(:parent :child) "NestedComponent")
    (is (equal (elmtui.state:get-component-by-path app-state '(:parent :child)) "NestedComponent"))

    ;; Overwrite a component
    (elmtui.state:store-component-at-path app-state '(:my-component) "NewComponentInstance")
    (is (equal (elmtui.state:get-component-by-path app-state '(:my-component)) "NewComponentInstance"))

    ;; Get non-existent component
    (is (null (elmtui.state:get-component-by-path app-state '(:non-existent))))))

;; Test case for REMOVE-COMPONENT-AT-PATH
(test remove-component-at-path-basic
  (let ((app-state (make-application-state)))
    (elmtui.state:store-component-at-path app-state '(:my-component) "ComponentInstance1")
    (elmtui.state:store-component-at-path app-state '(:parent :child) "NestedComponent")

    ;; Remove a component
    (remove-component-at-path app-state '(:my-component))
    (is (null (elmtui.state:get-component-by-path app-state '(:my-component))))

    ;; Remove a nested component
    (remove-component-at-path app-state '(:parent :child))
    (is (null (elmtui.state:get-component-by-path app-state '(:parent :child))))

    ;; Try to remove a non-existent component (should not error)
    (remove-component-at-path app-state '(:non-existent))
    (is (null (elmtui.state:get-component-by-path app-state '(:non-existent))))))

;; Function to run all tests in this suite
(defun run-state-api-tests ()
  (run! 'elmtui-state-api-suite))
