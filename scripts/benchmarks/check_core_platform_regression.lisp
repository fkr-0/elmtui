#!/usr/bin/env sbcl --script

(require 'asdf)

(defun iso8601-now ()
  (multiple-value-bind (sec min hour day month year)
      (decode-universal-time (get-universal-time) 0)
    (format nil "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0DZ"
            year month day hour min sec)))

(defun date-stamp ()
  (multiple-value-bind (_sec _min _hour day month year)
      (decode-universal-time (get-universal-time) 0)
    (declare (ignore _sec _min _hour))
    (format nil "~4,'0D-~2,'0D-~2,'0D" year month day)))

(defun load-sexp-file (path)
  (with-open-file (in path :direction :input)
    (read in nil nil)))

(defun metric (artifact section key)
  (getf (getf artifact section) key))

(defun evaluate-thresholds (artifact thresholds)
  (let* ((idle-cpu (metric artifact :idle :idle-cpu-percent))
         (throughput (metric artifact :throughput :events-per-second))
         (p95 (metric artifact :throughput :p95-latency-ms))
         (idle-max (getf thresholds :idle-cpu-max-percent))
         (throughput-min (getf thresholds :throughput-min-events-per-second))
         (p95-max (getf thresholds :p95-latency-max-ms))
         (checks (list
                  (list :name :idle-cpu
                        :actual idle-cpu
                        :threshold idle-max
                        :operator :<=
                        :pass (<= idle-cpu idle-max))
                  (list :name :throughput
                        :actual throughput
                        :threshold throughput-min
                        :operator :>=
                        :pass (>= throughput throughput-min))
                  (list :name :p95-latency
                        :actual p95
                        :threshold p95-max
                        :operator :<=
                        :pass (<= p95 p95-max)))))
    (list :checks checks
          :pass (every (lambda (c) (getf c :pass)) checks))))

(defun write-json-report (path baseline candidate thresholds evaluation)
  (with-open-file (out path :direction :output :if-exists :supersede :if-does-not-exist :create)
    (format out "{~%")
    (format out "  \"captured_at_iso\": \"~A\",~%" (iso8601-now))
    (format out "  \"thresholds\": {\"idle_cpu_max_pct\": ~,4F, \"throughput_min_events_per_s\": ~,3F, \"p95_latency_max_ms\": ~,3F},~%"
            (getf thresholds :idle-cpu-max-percent)
            (getf thresholds :throughput-min-events-per-second)
            (getf thresholds :p95-latency-max-ms))
    (format out "  \"baseline\": {\"idle_cpu_pct\": ~,4F, \"events_per_s\": ~,3F, \"p95_latency_ms\": ~,3F},~%"
            (metric baseline :idle :idle-cpu-percent)
            (metric baseline :throughput :events-per-second)
            (metric baseline :throughput :p95-latency-ms))
    (format out "  \"candidate\": {\"idle_cpu_pct\": ~,4F, \"events_per_s\": ~,3F, \"p95_latency_ms\": ~,3F},~%"
            (metric candidate :idle :idle-cpu-percent)
            (metric candidate :throughput :events-per-second)
            (metric candidate :throughput :p95-latency-ms))
    (format out "  \"result\": {\"pass\": ~:[false~;true~]}~%" (getf evaluation :pass))
    (format out "}~%")))

(defun write-markdown-report (path baseline candidate thresholds evaluation)
  (with-open-file (out path :direction :output :if-exists :supersede :if-does-not-exist :create)
    (format out "# Core+Platform Regression Check (~A)~%~%" (date-stamp))
    (format out "- Captured at (ISO UTC): ~A~%" (iso8601-now))
    (format out "- Result: **~A**~%~%" (if (getf evaluation :pass) "PASS" "FAIL"))
    (format out "## Thresholds~%")
    (format out "- Idle CPU max: ~,4F%~%" (getf thresholds :idle-cpu-max-percent))
    (format out "- Throughput min: ~,3F events/s~%" (getf thresholds :throughput-min-events-per-second))
    (format out "- p95 latency max: ~,3F ms~%~%" (getf thresholds :p95-latency-max-ms))
    (format out "## Baseline~%")
    (format out "- Idle CPU: ~,4F%~%" (metric baseline :idle :idle-cpu-percent))
    (format out "- Throughput: ~,3F events/s~%" (metric baseline :throughput :events-per-second))
    (format out "- p95 latency: ~,3F ms~%~%" (metric baseline :throughput :p95-latency-ms))
    (format out "## Candidate~%")
    (format out "- Idle CPU: ~,4F%~%" (metric candidate :idle :idle-cpu-percent))
    (format out "- Throughput: ~,3F events/s~%" (metric candidate :throughput :events-per-second))
    (format out "- p95 latency: ~,3F ms~%~%" (metric candidate :throughput :p95-latency-ms))
    (format out "## Checks~%")
    (dolist (check (getf evaluation :checks))
      (format out "- ~A: ~A (actual ~,4F vs threshold ~,4F)~%"
              (getf check :name)
              (if (getf check :pass) "PASS" "FAIL")
              (getf check :actual)
              (getf check :threshold)))))

(defun usage ()
  (format t "Usage: sbcl --script scripts/benchmarks/check_core_platform_regression.lisp [baseline.sexp candidate.sexp [thresholds.sexp]]~%")
  (format t "Defaults: docs/benchmarks/core-platform-baseline-2026-03-06.sexp docs/benchmarks/core-platform-baseline-latest.sexp docs/benchmarks/core-platform-thresholds.sexp~%"))

(let* ((args (uiop:command-line-arguments))
       (baseline-path (or (first args)
                          "docs/benchmarks/core-platform-baseline-2026-03-06.sexp"))
       (candidate-path (or (second args)
                           "docs/benchmarks/core-platform-baseline-latest.sexp"))
       (thresholds-path (or (third args)
                            "docs/benchmarks/core-platform-thresholds.sexp")))
  (unless (probe-file baseline-path)
    (usage)
    (error "Missing baseline artifact: ~A" baseline-path))
  (unless (probe-file candidate-path)
    (usage)
    (error "Missing candidate artifact: ~A" candidate-path))
  (unless (probe-file thresholds-path)
    (usage)
    (error "Missing thresholds file: ~A" thresholds-path))

  (let* ((baseline (load-sexp-file baseline-path))
         (candidate (load-sexp-file candidate-path))
         (thresholds (load-sexp-file thresholds-path))
         (evaluation (evaluate-thresholds candidate thresholds))
         (stamp (date-stamp))
         (json-path (format nil "docs/benchmarks/core-platform-regression-~A.json" stamp))
         (md-path (format nil "docs/benchmarks/core-platform-regression-~A.md" stamp))
         (latest-json-path "docs/benchmarks/core-platform-regression-latest.json")
         (latest-md-path "docs/benchmarks/core-platform-regression-latest.md"))
    (write-json-report json-path baseline candidate thresholds evaluation)
    (write-markdown-report md-path baseline candidate thresholds evaluation)
    (write-json-report latest-json-path baseline candidate thresholds evaluation)
    (write-markdown-report latest-md-path baseline candidate thresholds evaluation)
    (format t "Regression result: ~A~%" (if (getf evaluation :pass) "PASS" "FAIL"))
    (format t "Artifacts written:~%  ~A~%  ~A~%" json-path md-path)
    (uiop:quit (if (getf evaluation :pass) 0 1))))
