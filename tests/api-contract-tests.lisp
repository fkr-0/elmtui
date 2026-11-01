(uiop:define-package :elmtui.tests.api-contract
  (:use :cl :fiveam)
  (:export #:run-api-contract-tests))

(in-package :elmtui.tests.api-contract)

(def-suite api-contract-tests
  :description "Nonbreaking ElmTUI application and utility API behavior")
(in-suite api-contract-tests)

(test memo-per-function-invalidation
  "A named original function invalidates all wrappers, not an unrelated one."
  (elmtui.view.memo:clear-memoization-cache)
  (let ((calls 0) (other-calls 0))
    (flet ((compute (n) (incf calls) (* n 2))
           (other (n) (incf other-calls) (+ 10 n)))
      (let ((fn-a (elmtui.view.memo:memo #'compute))
            (fn-b (elmtui.view.memo:memo #'compute))
            (unrelated (elmtui.view.memo:memo #'other)))
        (is (= 8 (funcall fn-a 4)))
        (is (= 8 (funcall fn-a 4)))
        (is (= 8 (funcall fn-b 4)))
        (is (= 11 (funcall unrelated 1)))
        (is (= 2 calls))
        (is (= 1 other-calls))
        (elmtui.view.memo:clear-memoization-cache #'compute)
        (is (= 8 (funcall fn-a 4)))
        (is (= 8 (funcall fn-b 4)))
        (is (= 11 (funcall unrelated 1)))
        (is (= 4 calls))
        (is (= 1 other-calls))
        (elmtui.view.memo:clear-memoization-cache)
        (is (= 8 (funcall fn-a 4)))
        (is (= 11 (funcall unrelated 1)))
        (is (= 5 calls))
        (is (= 2 other-calls))))))

(test memo-wrapper-invalidation-and-cached-nil
  (elmtui.view.memo:clear-memoization-cache)
  (let ((calls 0))
    (let ((original (lambda (n) (declare (ignore n)) (incf calls) nil)))
      (let ((cached (elmtui.view.memo:memo original)))
        (is (null (funcall cached 1)))
        (is (null (funcall cached 1)))
        (is (= calls 1))
        (elmtui.view.memo:clear-memoization-cache cached)
        (is (null (funcall cached 1)))
        (is (= calls 2))))))

(test memo-component-preserves-props-argument
  (elmtui.view.memo:clear-memoization-cache)
  (let* ((calls 0)
         (original (lambda (props &optional suffix)
                    (incf calls)
                    (list props suffix))))
    (let* ((wrapper (elmtui.view.memo:memoize-component original))
           (props '(:label "OK")))
      (is (equal (list props :end) (funcall wrapper props :end)))
      (is (equal (list props :end) (funcall wrapper props :end)))
      (is (= calls 1))
      (elmtui.view.memo:clear-memoization-cache wrapper)
      (is (equal (list props :end) (funcall wrapper props :end)))
      (is (= calls 2)))))

(test memoize-disabled-always-computes
  (elmtui.view.memo:clear-memoization-cache)
  (let* ((calls 0)
         (fn (lambda (props) (incf calls) (copy-list props))))
    (let ((elmtui.view.memo::*memoization-enabled* nil))
      (is (equal '(1 2) (elmtui.view.memo:memoize fn '(1 2))))
      (is (equal '(1 2) (elmtui.view.memo:memoize fn '(1 2))))
      (is (= calls 2)))
    (is (equal '(1 2) (elmtui.view.memo:memoize fn '(1 2))))
    (is (equal '(1 2) (elmtui.view.memo:memoize fn '(1 2))))
    (is (= calls 3))
    (elmtui.view.memo:clear-memoization-cache)
    (is (equal '(1 2) (elmtui.view.memo:memoize fn '(1 2))))
    (is (= calls 4))))

(test memoize-selective-component-invalidation
  (elmtui.view.memo:clear-memoization-cache)
  (let ((calls-a 0) (calls-b 0))
    (let ((a (lambda (props) (incf calls-a) props))
          (b (lambda (props) (incf calls-b) props)))
      (loop repeat 2 do
        (is (equal '(1) (elmtui.view.memo:memoize a '(1))))
        (is (equal '(2) (elmtui.view.memo:memoize b '(2)))))
      (is (= 1 calls-a))
      (is (= 1 calls-b))
      (elmtui.view.memo:clear-memoization-cache a)
      (is (equal '(1) (elmtui.view.memo:memoize a '(1))))
      (is (equal '(2) (elmtui.view.memo:memoize b '(2))))
      (is (= 2 calls-a))
      (is (= 1 calls-b)))))

(test loop-legacy-options-retain-event-driven-behavior
  "Historically ignored options must not become source-incompatible errors."
  (let ((shutdown elmtui.core.loop:*shutdown-requested*)
        (sender elmtui.core.globals:*app-sender*))
    (unwind-protect
         (progn
           (is-true (elmtui.core.loop:start-loop :fps 30 :wait nil))
           (is-true (bt:thread-alive-p elmtui.core.loop:*consumer-thread*)))
      (elmtui.core.loop:elm-stop-loop)
      (setf elmtui.core.loop:*shutdown-requested* shutdown
            elmtui.core.globals:*app-sender* sender))))

#+sbcl
(defun discarded-memo-value (original)
  ;; A terminated thread avoids conservative stale roots on the test stack.
  (bt:join-thread
   (bt:make-thread
    (lambda ()
      (let ((wrapper (elmtui.view.memo:memo original)))
        (sb-ext:make-weak-pointer (funcall wrapper 123)))))))

#+sbcl
(test discarded-wrappers-release-cached-values
  (let* ((original (lambda (x) (list x)))
         (weak-value (discarded-memo-value original)))
    (sb-ext:gc :full t)
    (sb-ext:gc :full t)
    (is (null (sb-ext:weak-pointer-value weak-value)))
    ;; The original remains usable and must not keep discarded caches alive.
    (is (equal '(123) (funcall original 123)))))

(test view-diff-is-whole-tree-replacement
  (let ((old '(:node :a))
        (new '(:node :b)))
    (is (eq new (elmtui.view.core:apply-diff
                 old (elmtui.view.core:view-diff old new))))))

(defun %key (&key key char modifiers)
  (elmtui.core.event-types:make-key-event :type :key-down :key key :char char
                                          :modifiers modifiers))

(test key-pressed-p-matches-chars-keys-and-modifiers
  (let ((q (%key :key #\q :char #\q))
        (up (%key :key :up))
        (ctrl-s (%key :key #\s :modifiers '(:ctrl))))
    (is-true (elmtui.app:key-pressed-p q :char #\q))
    (is-false (elmtui.app:key-pressed-p q :char #\Q))
    (is-true (elmtui.app:key-pressed-p up :key :up))
    (is-true (elmtui.app:key-pressed-p up :key '(:down :up)))
    (is-false (elmtui.app:key-pressed-p up :key :down))
    (is-true (elmtui.app:key-pressed-p ctrl-s :char #\s :modifiers '(:ctrl)))
    (is-true (elmtui.app:key-pressed-p ctrl-s :char #\s :modifiers '(:control)))
    (is-false (elmtui.app:key-pressed-p q :char #\q :modifiers '(:ctrl)))
    ;; The wrapped form the runtime unwraps for DEFAPPLICATION updates.
    (is-true (elmtui.app:key-pressed-p (list :keyevent :event q) :char #\q))
    (is-false (elmtui.app:key-pressed-p '(:terminalresized :width 80) :char #\q))
    (is-false (elmtui.app:key-pressed-p q))))

(test quit-requested-p-recognises-only-quit-requests
  (is-true (elmtui.app:quit-requested-p '(:app-quit-requested)))
  (is-false (elmtui.app:quit-requested-p '(:appshutdown)))
  (is-false (elmtui.app:quit-requested-p (%key :key #\q :char #\q))))

(test api-package-names-are-the-working-symbols
  "Re-exporting packages must export the bound symbols, not same-named
fresh ones (UIOP :REEXPORT only exports by name)."
  (is (eq 'elmtui.app:defapplication 'elmtui.app.api:defapplication))
  (is-true (macro-function 'elmtui.app.api:defapplication))
  (dolist (name '("SREF" "SAPPLY" "SDELETE" "DEFUPDATE" "CMD" "SEND-COMMAND"
                  "MAKE-UPDATE-CONTEXT" "PROCESS-UPDATE-RESULT"))
    (is (eq (find-symbol name :elmtui.state.update) (find-symbol name :elmtui.state.api))
        "elmtui.state.api:~A is not elmtui.state.update:~A" name name)
    (is (eq (find-symbol name :elmtui.state.update) (find-symbol name :elmtui.state))
        "elmtui.state:~A is not elmtui.state.update:~A" name name))
  (is-true (fboundp 'elmtui.state.api:sapply)))

(test deftea-app-lowers-onto-defapplication
  (let ((expansion (macroexpand-1
                    '(elmtui.app.tea-core:deftea-app contract-tea-app
                      :init (lambda () (values '(:n 0) nil))
                      :transition (lambda (m s) (declare (ignore m)) s)
                      :view (lambda (s) (declare (ignore s)) '(:text :content "x"))))))
    (labels ((mentions (form symbol)
               (or (eq form symbol)
                   (and (consp form) (or (mentions (car form) symbol)
                                         (mentions (cdr form) symbol))))))
      (is-true (mentions expansion 'elmtui.app:defapplication))
      (is-true (mentions expansion 'elmtui.app.api:make-runtime-app-spec)))))

(test deftea-view-unwraps-root-viewport
  (is (equal '(:text :id :a)
             (elmtui.app.tea-core::%unwrap-root-viewport
              '(:root-viewport :id :r :children ((:text :id :a))))))
  (is (equal '(:container :id :tea-view :children ((:text :id :a) (:text :id :b)))
             (elmtui.app.tea-core::%unwrap-root-viewport
              '(:root-viewport :id :r :children ((:text :id :a) (:text :id :b))))))
  (is (equal '(:text :id :a)
             (elmtui.app.tea-core::%unwrap-root-viewport '(:text :id :a)))))

(defun run-api-contract-tests ()
  (let ((result (run 'api-contract-tests)))
    (explain! result)
    (results-status result)))
