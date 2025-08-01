
;;;; ---------------------------
;;;;  FiveAM Test Suite
;;;; ---------------------------

(uiop:define-package :elmtui.tests.update-dsl
  (:use :cl :fiveam #:elmtui.update-dsl.api))
(in-package :elmtui.tests.update-dsl)

(def-suite update-dsl-tests

  :in elmtui.tests:elmtui-test
  :description "Basic tests for application initialization")

(in-suite update-dsl-tests)

(defun make-empty-state () '())


(test with-cycle-basic
  "Mutating global state pushes a single patch."
  (multiple-value-bind (st patches cmds)
    (with-cycle (ctx (make-empty-state))
      (setf (state> :foo) 42)
      (is (= (state> :foo) 42)))
    (is (= 42 (getf st :foo)))
    (is (= 1  (length patches)))
    (is (null cmds))
    (is (equal '(:path (:foo) :value 42) (elmtui.utils:as :plist (first patches))))))
                                        ;(struct->plist (first patches))))))

(test component-state
  "Component-scoped accessor builds correct path."
  (multiple-value-bind (st patches *)
    (with-cycle
      (ctx (make-empty-state)
        :component-path '(:timer))
      (setf (cstate> :ctr) 3)
      (setf (state> :itr) 222))
    (declare (ignore *))
    (is (= 3 (getf (getf st :timer) :ctr)))
    (is (= 222 (getf st :itr)))
    (is (= 2 (length patches)))
    (is (equal '(:timer :ctr) (elmtui.update-dsl.api::patch-path (first patches))))
    (is (equal '(:itr) (elmtui.update-dsl.api::patch-path (second patches))))))

(test command-collection
  "cmd> registers thunk + continuations."
  (multiple-value-bind (a b cmds)
    (with-cycle (ctx (make-empty-state))
      (cmd> (lambda () 1)
        :then (lambda (x) (+ x 1))
        :err  (lambda (e) e)))
    (declare (ignore a b))
    (let ((c (first cmds)))
      (is (elmtui.update-dsl.api::command-p c))
      (is (functionp (elmtui.update-dsl.api::command-thunk c)))
      (is (functionp (elmtui.update-dsl.api::command-then  c)))
      (is (functionp (elmtui.update-dsl.api::command-err   c)))
      (is (null (elmtui.update-dsl.api::command-who c))))))

(test mid-cycle-harvest
  ">> returns and clears accumulators without leaving with-cycle."
  (multiple-value-bind (st p1 c1)
    (with-cycle (ctx (make-empty-state))
      (setf (state> :a) 1)
      (>>)
      (cmd> (lambda () :ok))
      (setf (state> :b) 2))
    (is (= 2 (getf st :b)))
    (is (= 1 (length p1)))
    (is (= 1 (length c1)))))

(test nested-components
  "Entering a child component resets local tracking."
  (multiple-value-bind (st patches cmds)
    (with-cycle (ctx (make-empty-state))
      (setf (state> :root) 1)
      (<< '(:child))
      (setf (cstate> :leaf) :x)
      (multiple-value-bind (p c) (>>)
        (is (= 1 (length p)))
        (is (null c))
        (is (equal '(:child :leaf) (elmtui.update-dsl.api::patch-path (first p))))))
    (declare (ignore st cmds))
    (is (= 2 (length patches)))))

;;;; ---------------------------
;;;;  FiveAM Test for merge-patch
;;;; ---------------------------

(test merge-patch-basic
  "merge-patch applies single and nested patches correctly."
  (let* ((st (list :foo 1))
          (patches
            (list
              (elmtui.update-dsl.api::make-patch :path '(:foo) :value 42)
              (elmtui.update-dsl.api::make-patch :path '(:bar :baz) :value "ok")))
          (new-st (elmtui.update-dsl.api:state-patch st patches)))
    (is (= 42 (getf new-st :foo)))
    (is (equal "ok" (getf (getf new-st :bar) :baz)))))

;;;; ---------------------------
;;;;  FiveAM Test for process-commands
;;;; ---------------------------



(test process-commands-basic
  "process-commands executes thunks and handles continuations/errors."
  (let* ((cmds (list
                 (elmtui.update-dsl.api::make-command :thunk (lambda () 1)
                   :then (lambda (x) (+ x 10)))
                 (elmtui.update-dsl.api::make-command :thunk (lambda () (error "fail"))
                   :err (lambda (e) (list :caught e)))))
          (results (elmtui.update-dsl.api::process-commands cmds)))
    (is (= 11 (first results)))
    (is (equal :caught (car (second results))))))


;;;; ---------------------------
;;;;  FiveAM Test for check-state-access
;;;; ---------------------------

;; (test check-state-access-warns
;;   "check-state-access warns on improper global state access."
;;   (let ((warned nil))
;;     (handler-bind ((warning (lambda (c) (setf warned t) (muffle-warning))))
;;       (check-state-access
;;         '(with-cycle (ctx (make-empty-state) :component-path '(:comp))
;;            (setf (state> :foo) 42))))
;;     (is (not (null warned)))))


;;;; ---------------------------
;;;;  FiveAM Test for setfn and #P
;;;; ---------------------------

(test setfn-functional-update
  "setfn applies function to value at place."
  (multiple-value-bind (st patches cmds)
    (with-cycle (ctx (make-empty-state))
      (setf (state> :foo) 5)
      (setfn (state> :foo) (lambda (x) (+ x 10)))
      (is (= 15 (state> :foo))))
    (is (= 15 (getf st :foo)))
    (is (null cmds))
    (is (= 2 (length patches)))))

;; (test path-reader-macro
;;   "#P expands to path list."
;;   (is (equal '(:foo :bar) #P(:foo :bar))))
