(uiop:define-package :elmtui.dev.benchmark.tests (:use :cl :fiveam) (:import-from :elmtui.dev.benchmark #:benchmark-thunk #:compare-benchmark-results #:write-benchmark-baseline #:read-benchmark-baseline #:stress-event-pipeline) (:export #:run-benchmark-tests))

(in-package :elmtui.dev.benchmark.tests)

(def-suite benchmark-test-suite :description "Tests for maintained optional benchmark tooling.")

(in-suite benchmark-test-suite)

(test benchmark-result-has-stable-shape (let ((result (benchmark-thunk :noop (lambda () 42) :iterations 20 :warmup-iterations 2))) (is (eq :noop (getf result :name))) (is (= 20 (getf result :iterations))) (is (numberp (getf result :elapsed-seconds))) (is (numberp (getf result :ops-per-second))) (is (numberp (getf result :ns-per-op)))))

(test benchmark-baseline-roundtrips
  (let* ((output-dir (merge-pathnames #p"test-output/"
                                      (asdf:system-source-directory "elmtui")))
         (path (merge-pathnames
                (format nil "elmtui-~A.sexp" (symbol-name (gensym "BENCH-")))
                output-dir))
         (value (list (list :name :sample :ops-per-second 10.0d0))))
    (ensure-directories-exist path)
    (unwind-protect
         (progn
           (write-benchmark-baseline path value)
           (is (equal value (read-benchmark-baseline path))))
      (when (probe-file path)
        (delete-file path)))))

(test benchmark-comparison-reports-ratio (let ((result (compare-benchmark-results (list :name :sample :ops-per-second 100.0d0) (list :name :sample :ops-per-second 95.0d0) :minimum-ratio 0.90d0))) (is (= 0.95d0 (getf result :ratio))) (is-true (getf result :passes))))

(test benchmark-stress-is-bounded (let ((result (stress-event-pipeline :rounds 2 :iterations 20))) (is (= 2 (getf result :rounds))) (is (= 2 (length (getf result :results)))) (is (numberp (getf result :median-ops-per-second)))))

(defun run-benchmark-tests () "Run optional benchmark-tool tests." (run! 'benchmark-test-suite))
