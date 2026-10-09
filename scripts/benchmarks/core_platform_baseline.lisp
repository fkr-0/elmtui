#!/usr/bin/env sbcl --script

(require 'asdf)
(asdf:load-system :elmtui)

(defparameter +default-idle-duration-seconds+ 3.0)
(defparameter +default-throughput-event-count+ 10000)
(defparameter +default-throughput-timeout-seconds+ 20.0)

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

(defun detect-cpu-model ()
  (handler-case
      (let ((result (uiop:run-program
                     '("sh" "-lc" "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//'")
                     :output :string
                     :ignore-error-status t)))
        (let ((trimmed (string-trim '(#\Space #\Tab #\Newline #\Return) (or result ""))))
          (if (plusp (length trimmed)) trimmed "unknown")))
    (error () "unknown")))

(defun benchmark-metadata ()
  (list :captured-at-iso (iso8601-now)
        :captured-at-universal (get-universal-time)
        :lisp-implementation (lisp-implementation-type)
        :lisp-version (lisp-implementation-version)
        :machine-instance (machine-instance)
        :machine-type (machine-type)
        :machine-version (machine-version)
        :software-type (software-type)
        :software-version (software-version)
        :cpu-model (detect-cpu-model)))

(defun now-ms ()
  (/ (* (get-internal-real-time) 1000.0)
     internal-time-units-per-second))

(defun wait-until (predicate timeout-seconds)
  (let ((deadline (+ (get-internal-real-time)
                     (round (* timeout-seconds internal-time-units-per-second)))))
    (loop
      (when (funcall predicate)
        (return t))
      (when (> (get-internal-real-time) deadline)
        (return nil))
      (sleep 0.001))))

(defun percentile (numbers p)
  (let* ((sorted (sort (copy-seq numbers) #'<))
         (n (length sorted)))
    (if (zerop n)
        0.0
        (let* ((idx (floor (* p (1- n)))))
          (elt sorted idx)))))

(defun benchmark-idle-cpu (&key (duration-seconds 3.0))
  (elmtui.core.loop:start-loop)
  (sleep 0.05)
  (let* ((cpu0 (get-internal-run-time))
         (real0 (get-internal-real-time)))
    (sleep duration-seconds)
    (let* ((cpu1 (get-internal-run-time))
           (real1 (get-internal-real-time))
           (cpu-seconds (/ (- cpu1 cpu0) (float internal-time-units-per-second)))
           (wall-seconds (/ (- real1 real0) (float internal-time-units-per-second)))
           (cpu-percent (* 100.0 (/ cpu-seconds (max wall-seconds 1e-9)))))
      (elmtui.core.loop:elm-stop-loop)
      (sleep 0.05)
      (list :idle-duration-seconds wall-seconds
            :idle-cpu-seconds cpu-seconds
            :idle-cpu-percent cpu-percent))))

(defun benchmark-throughput-and-latency (&key
                                           (event-count +default-throughput-event-count+)
                                           (timeout-seconds +default-throughput-timeout-seconds+))
  (let ((processed 0)
        (published 0)
        (latencies '()))
    (setf elmtui.core.globals:*app-message-processor*
          (lambda (msg)
            (when (and (consp msg) (eq (first msg) :bench))
              (let ((sent-ms (getf (rest msg) :sent-ms)))
                (push (- (now-ms) sent-ms) latencies)
                (incf processed)))))

    (elmtui.core.loop:start-loop)
    (sleep 0.05)

    (let ((start-ms (now-ms)))
      (dotimes (_ event-count)
        (declare (ignore _))
        (when (elmtui.core.loop:publish
               (list :app-message
                     (list :bench :sent-ms (now-ms))))
          (incf published)))

      (let ((completed-p (wait-until (lambda () (>= processed published)) timeout-seconds)))
        (let* ((elapsed-ms (- (now-ms) start-ms))
               (events-per-second (/ processed (/ elapsed-ms 1000.0)))
               (p95-ms (percentile latencies 0.95)))
          (elmtui.core.loop:elm-stop-loop)
          (sleep 0.05)
          (list :event-count event-count
                :published-count published
                :processed-count processed
                :timed-out (not completed-p)
                :timeout-seconds timeout-seconds
                :elapsed-ms elapsed-ms
                :events-per-second events-per-second
                :p95-latency-ms p95-ms
                :avg-latency-ms (/ (reduce #'+ latencies :initial-value 0.0)
                                   (max 1 (length latencies)))))))))

(defun write-json-artifact (path metadata idle throughput)
  (with-open-file (out path :direction :output :if-exists :supersede :if-does-not-exist :create)
    (format out "{~%")
    (format out "  \"captured_at_iso\": \"~A\",~%" (getf metadata :captured-at-iso))
    (format out "  \"captured_at_universal\": \"~A\",~%" (getf metadata :captured-at-universal))
    (format out "  \"environment\": {\"lisp\": \"~A\", \"lisp_version\": \"~A\", \"machine_instance\": \"~A\", \"machine_type\": \"~A\", \"machine_version\": \"~A\", \"software_type\": \"~A\", \"software_version\": \"~A\", \"cpu_model\": \"~A\"},~%"
            (getf metadata :lisp-implementation)
            (getf metadata :lisp-version)
            (getf metadata :machine-instance)
            (getf metadata :machine-type)
            (getf metadata :machine-version)
            (getf metadata :software-type)
            (getf metadata :software-version)
            (getf metadata :cpu-model))
    (format out "  \"idle\": {\"duration_s\": ~,6F, \"cpu_s\": ~,6F, \"cpu_pct\": ~,4F},~%"
            (getf idle :idle-duration-seconds)
            (getf idle :idle-cpu-seconds)
            (getf idle :idle-cpu-percent))
    (format out "  \"throughput\": {\"event_count\": ~D, \"published_count\": ~D, \"processed_count\": ~D, \"timed_out\": ~:[false~;true~], \"timeout_s\": ~,3F, \"elapsed_ms\": ~,3F, \"events_per_s\": ~,3F},~%"
            (getf throughput :event-count)
            (getf throughput :published-count)
            (getf throughput :processed-count)
            (getf throughput :timed-out)
            (getf throughput :timeout-seconds)
            (getf throughput :elapsed-ms)
            (getf throughput :events-per-second))
    (format out "  \"latency\": {\"p95_ms\": ~,3F, \"avg_ms\": ~,3F}~%"
            (getf throughput :p95-latency-ms)
            (getf throughput :avg-latency-ms))
    (format out "}~%")))

(defun write-sexp-artifact (path metadata idle throughput)
  (with-open-file (out path :direction :output :if-exists :supersede :if-does-not-exist :create)
    (let ((artifact (list :metadata metadata :idle idle :throughput throughput)))
      (pprint artifact out)
      (terpri out))))

(defun write-markdown-summary (path metadata idle throughput)
  (with-open-file (out path :direction :output :if-exists :supersede :if-does-not-exist :create)
    (format out "# Core+Platform Baseline (~A)~%~%" (date-stamp))
    (format out "Command: `clpm bundle exec -- sbcl --script scripts/benchmarks/core_platform_baseline.lisp`~%~%")
    (format out "## Environment~%")
    (format out "- Captured at (ISO UTC): ~A~%" (getf metadata :captured-at-iso))
    (format out "- Lisp: ~A ~A~%" (getf metadata :lisp-implementation) (getf metadata :lisp-version))
    (format out "- Machine: ~A (~A / ~A)~%" (getf metadata :machine-instance) (getf metadata :machine-type) (getf metadata :machine-version))
    (format out "- Software: ~A ~A~%" (getf metadata :software-type) (getf metadata :software-version))
    (format out "- CPU: ~A~%~%" (getf metadata :cpu-model))
    (format out "## Idle CPU~%")
    (format out "- Duration: ~,3F s~%" (getf idle :idle-duration-seconds))
    (format out "- CPU: ~,3F s~%" (getf idle :idle-cpu-seconds))
    (format out "- CPU %%: ~,3F~%~%" (getf idle :idle-cpu-percent))
    (format out "## Throughput~%")
    (format out "- Events: ~D~%" (getf throughput :event-count))
    (format out "- Published: ~D~%" (getf throughput :published-count))
    (format out "- Processed: ~D~%" (getf throughput :processed-count))
    (format out "- Timed out: ~A~%" (if (getf throughput :timed-out) "yes" "no"))
    (format out "- Timeout: ~,3F s~%" (getf throughput :timeout-seconds))
    (format out "- Elapsed: ~,3F ms~%" (getf throughput :elapsed-ms))
    (format out "- Events/s: ~,3F~%~%" (getf throughput :events-per-second))
    (format out "## Latency~%")
    (format out "- p95: ~,3F ms~%" (getf throughput :p95-latency-ms))
    (format out "- avg: ~,3F ms~%" (getf throughput :avg-latency-ms))))

(let* ((metadata (benchmark-metadata))
       (idle (benchmark-idle-cpu :duration-seconds +default-idle-duration-seconds+))
       (throughput (benchmark-throughput-and-latency))
       (stamp (date-stamp))
       (json-path (format nil "docs/benchmarks/core-platform-baseline-~A.json" stamp))
       (md-path (format nil "docs/benchmarks/core-platform-baseline-~A.md" stamp))
       (sexp-path (format nil "docs/benchmarks/core-platform-baseline-~A.sexp" stamp))
       (latest-json-path "docs/benchmarks/core-platform-baseline-latest.json")
       (latest-md-path "docs/benchmarks/core-platform-baseline-latest.md")
       (latest-sexp-path "docs/benchmarks/core-platform-baseline-latest.sexp"))
  (write-json-artifact json-path metadata idle throughput)
  (write-markdown-summary md-path metadata idle throughput)
  (write-sexp-artifact sexp-path metadata idle throughput)
  (write-json-artifact latest-json-path metadata idle throughput)
  (write-markdown-summary latest-md-path metadata idle throughput)
  (write-sexp-artifact latest-sexp-path metadata idle throughput)
  (format t "Idle CPU %%: ~,3F~%" (getf idle :idle-cpu-percent))
  (format t "Throughput events/s: ~,3F~%" (getf throughput :events-per-second))
  (format t "Latency p95 ms: ~,3F~%" (getf throughput :p95-latency-ms))
  (format t "Artifacts written:~%  ~A~%  ~A~%" json-path md-path))
