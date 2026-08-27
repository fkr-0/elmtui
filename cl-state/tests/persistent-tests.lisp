(uiop:define-package :cl-state-tests.persistent (:use :cl :fiveam :cl-state.api) (:export #:persistent-suite #:run-persistent-tests))

(in-package :cl-state-tests.persistent)

(def-suite persistent-suite :description "Persistent structurally shared state tests")

(in-suite persistent-suite)

(test shared-commit-path-copies-changed-branch-and-shares-untouched-branch (let* ((source (make-state :initial ' (:changed (:left 1 :right 2) :untouched (:value 7)))) (changed-before (state-ref source :changed)) (untouched-before (state-ref source :untouched)) (next (cl-state.patch::apply-patches-shared source ' (((:changed :left) 9))))) (is-false (eq source next)) (is (= 1 (state-ref source ' (:changed :left)))) (is (= 9 (state-ref next ' (:changed :left)))) (is-false (eq changed-before (state-ref next :changed))) (is (eq untouched-before (state-ref next :untouched))) (is-false (cl-state.core::application-state-frozen-p source)) (is-true (cl-state.core::application-state-frozen-p next))))

(defun run-persistent-tests () (run! 'persistent-suite))

(test frozen-shared-snapshot-rejects-state-api-mutation (let* ((source (make-state :initial ' (:untouched (:value 7)))) (next (cl-state.patch::apply-patches-shared source ' ((:count 1))))) (signals cl-state.core:state-mutation-forbidden (state-set next ' (:untouched :value) 99)) (is (= 7 (state-ref source ' (:untouched :value)))) (is (= 7 (state-ref next ' (:untouched :value))))))

(test shared-and-eager-cover-all-ops (let* ((source (make-state :initial (quote (:count 3 :items (3 4) :nested (:value 5) :gone :yes)))) (patches (list (make-patch :path (quote (:nested :value)) :op :set :value 11) (make-patch :path :items :op :merge :value (quote (1 2))) (make-patch :path :count :op :update :value (function 1+)) (make-patch :path :gone :op :remove))) (eager (apply-patches-persistent source patches :name :oracle)) (shared (cl-state.patch::apply-patches-shared source patches :name :shared))) (dolist (path (quote (:count :items (:nested :value) :gone))) (is (equal (state-ref eager path :missing) (state-ref shared path :missing)))) (is (= (application-state-version eager) (application-state-version shared))) (is (= (length (tx-changes (first (application-state-history eager)))) (length (tx-changes (first (application-state-history shared)))))) (is (= 3 (state-ref source :count))) (is (eq :yes (state-ref source :gone)))))

(test deterministic-256-step-trace-matches-all-engines (let ((fast (make-state :initial (quote (:count 0 :bucket (:a 1 :b 2) :items (3 4))))) (eager (make-state :initial (quote (:count 0 :bucket (:a 1 :b 2) :items (3 4))))) (shared (make-state :initial (quote (:count 0 :bucket (:a 1 :b 2) :items (3 4)))))) (dotimes (step 256) (let* ((kind (mod (+ (* step 7) 3) 5)) (patch (case kind (0 (make-patch :path (quote (:bucket :a)) :op :set :value step)) (1 (make-patch :path :count :op :update :value (function 1+))) (2 (make-patch :path :items :op :merge :value (list step))) (3 (make-patch :path :flag :op :set :value (if (evenp step) :even :odd))) (otherwise (make-patch :path :flag :op :remove)))) (old-shared shared) (old-count (state-ref old-shared :count)) (old-a (state-ref old-shared (quote (:bucket :a)))) (old-items (copy-list (state-ref old-shared :items))) (old-flag (state-ref old-shared :flag :missing))) (apply-patches fast (list patch)) (setf eager (apply-patches-persistent eager (list patch) :name :oracle-step)) (setf shared (cl-state.patch::apply-patches-shared shared (list patch) :name :shared-step)) (dolist (path (quote (:count (:bucket :a) (:bucket :b) :items :flag))) (is (equal (state-ref fast path :missing) (state-ref eager path :missing))) (is (equal (state-ref eager path :missing) (state-ref shared path :missing)))) (is (= (application-state-version fast) (application-state-version eager))) (is (= (application-state-version eager) (application-state-version shared))) (is (= old-count (state-ref old-shared :count))) (is (= old-a (state-ref old-shared (quote (:bucket :a))))) (is (equal old-items (state-ref old-shared :items))) (is (equal old-flag (state-ref old-shared :flag :missing))) (is-true (cl-state.core::application-state-frozen-p shared))))))

(test shared-update-copies-input-and-result-around-destructive-function (let* ((source (make-state :initial (quote (:payload (:value 1))))) (original (state-ref source :payload)) (patch (make-patch :path :payload :op :update :value (lambda (value) (setf (gethash :value value) 9) value))) (next (cl-state.patch::apply-patches-shared source (list patch)))) (is (= 1 (state-ref source (quote (:payload :value))))) (is (= 9 (state-ref next (quote (:payload :value))))) (is (eq original (state-ref source :payload))) (is-false (eq original (state-ref next :payload)))))

(test shared-remove-history-does-not-alias-source (let* ((source (make-state :initial (quote (:gone (:value 1))))) (source-value (state-ref source :gone)) (patch (make-patch :path :gone :op :remove)) (next (cl-state.patch::apply-patches-shared source (list patch))) (change (first (tx-changes (first (application-state-history next))))) (history-old (second change))) (is-false (eq source-value history-old)) (setf (gethash :value history-old) 9) (is (= 1 (state-ref source (quote (:gone :value))))) (is (= 9 (gethash :value history-old)))))

(defstruct protocol-mutable-leaf payload)

(defstruct protocol-frozen-leaf payload)

(defmethod copy-state-value ((value protocol-mutable-leaf))
  (make-protocol-mutable-leaf
   :payload (copy-state-value (protocol-mutable-leaf-payload value))))

(defmethod copy-state-value ((value protocol-frozen-leaf))
  (make-protocol-frozen-leaf
   :payload (copy-state-value (protocol-frozen-leaf-payload value))))

(defmethod freeze-state-value ((value protocol-mutable-leaf))
  (make-protocol-frozen-leaf
   :payload (freeze-state-value (protocol-mutable-leaf-payload value))))

(defmethod persistent-state-value-p ((value protocol-mutable-leaf))
  (declare (ignore value))
  nil)

(defmethod persistent-state-value-p ((value protocol-frozen-leaf))
  (persistent-state-value-p (protocol-frozen-leaf-payload value)))

(test custom-mutable-leaf-protocol-controls-copy-and-strict-freeze
  (let* ((leaf (make-protocol-mutable-leaf :payload (vector 1 2 3)))
         (source (make-state :initial (list :leaf leaf)))
         (owned (state-value source :leaf))
         (next (cl-state.patch::apply-patches-shared
                source
                (list (make-patch :path :leaf :op :set :value leaf))))
         (strict-leaf (state-ref next :leaf)))
    (is-false (eq leaf (state-ref source :leaf)))
    (is-false (eq owned (state-ref source :leaf)))
    (is-false (persistent-state-value-p leaf))
    (is (typep strict-leaf 'protocol-frozen-leaf))
    (is-true (persistent-state-value-p strict-leaf))
    (setf (aref (protocol-mutable-leaf-payload leaf) 0) 99)
    (is (= 1 (aref (protocol-frozen-leaf-payload strict-leaf) 0)))
    (is (= 1 (aref (protocol-mutable-leaf-payload owned) 0)))))

(test shared-commit-observer-failure-is-post-commit-and-source-safe
  (let* ((source (make-state :initial '(:count 0)))
         (failing (lambda (old new)
                    (declare (ignore old new))
                    (error "persistent observer boom")))
         (committed nil))
    (add-observer source :count failing)
    (handler-case
        (progn
          (cl-state.patch::apply-patches-shared
           source (list (make-patch :path :count :op :set :value 1)))
          (fail "Expected persistent observer failure."))
      (observer-notification-error (condition)
        (setf committed (observer-notification-error-state condition))
        (is (eq :persistent-commit
                (observer-notification-error-phase condition)))))
    (is (= 0 (state-ref source :count)))
    (is (= 1 (state-ref committed :count)))
    (is-true (state-frozen-p committed))
    (is (= 1 (length (application-state-history committed))))))
