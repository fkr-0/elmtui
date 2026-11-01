(uiop:define-package :elmtui.dev.benchmark
  (:use :cl)
  (:import-from :elmtui.core.event-pipeline #:make-pipeline #:process-event #:transform-pipe)
  (:import-from :elmtui.core.event-types #:normalize-key-event)
  (:export #:benchmark-thunk #:benchmark-event-throughput #:benchmark-input-normalization
           #:compare-benchmark-results #:stress-event-pipeline #:write-benchmark-baseline
           #:read-benchmark-baseline #:print-benchmark-result #:run-benchmark-suite))
(in-package :elmtui.dev.benchmark)

(defun %bytes-consed ()
  "Return the implementation allocation counter, or NIL when unavailable."
  #+sbcl (sb-ext:get-bytes-consed)
  #-sbcl nil)

(defun benchmark-thunk (name thunk &key (iterations 10000) (warmup-iterations 1000))
  "Warm up and time THUNK; return timings, allocation and host context as a plist.
Zero elapsed ticks mean insufficient clock resolution, not zero operation cost.
Counters include loop overhead and other process activity; no GC is forced."
  (check-type iterations (integer 1 *))
  (check-type warmup-iterations (integer 0 *))
  (dotimes (index warmup-iterations) (declare (ignorable index)) (funcall thunk))
  (let ((bytes-before (%bytes-consed)) (cpu-start (get-internal-run-time))
        (started (get-internal-real-time)))
    (dotimes (index iterations) (declare (ignorable index)) (funcall thunk))
    (let* ((ticks (- (get-internal-real-time) started))
           (cpu-ticks (- (get-internal-run-time) cpu-start))
           (bytes-after (%bytes-consed))
           (seconds (/ ticks (float internal-time-units-per-second 1.0d0)))
           (valid (plusp ticks))
           (ops (if valid (/ iterations seconds) 0.0d0))
           (bytes (and bytes-before bytes-after (- bytes-after bytes-before))))
      (list :name name :iterations iterations :warmup-iterations warmup-iterations
            :elapsed-ticks ticks :elapsed-seconds seconds
            :cpu-seconds (/ cpu-ticks (float internal-time-units-per-second 1.0d0))
            :clock-resolution-seconds (/ 1.0d0 internal-time-units-per-second)
            :measurement-valid-p valid :ops-per-second ops
            :ns-per-op (if valid (/ 1.0d9 ops) 0.0d0)
            :bytes-consed bytes :bytes-per-op (and bytes (/ bytes (float iterations 1.0d0)))
            :lisp-implementation (format nil "~A ~A" (lisp-implementation-type) (lisp-implementation-version))
            :machine-type (machine-type) :software-type (software-type)
            :software-version (software-version)))))

(defun benchmark-event-throughput (&key (iterations 100000) (warmup-iterations 5000))
  "Measure two pure event transforms; this does not measure mailbox or UI latency."
  (let ((pipeline (make-pipeline :pipes
                                (list (make-instance 'transform-pipe :transform (lambda (event) (1+ event)))
                                      (make-instance 'transform-pipe :transform (lambda (event) (* event 2)))))))
    (benchmark-thunk :event-pipeline (lambda () (process-event pipeline 41))
                     :iterations iterations :warmup-iterations warmup-iterations)))

(defun benchmark-input-normalization (&key (iterations 100000) (warmup-iterations 5000))
  "Measure pure key normalization; this does not read input devices."
  (let ((event '(:type :key-down :key :arrow-down :code 0 :modifiers (:shift))))
    (benchmark-thunk :input-normalization (lambda () (normalize-key-event event))
                     :iterations iterations :warmup-iterations warmup-iterations)))

(defun %nonnegative-finite-real-p (value)
  (and (realp value)
       #+sbcl (or (rationalp value)
                  (not (or (sb-ext:float-nan-p value) (sb-ext:float-infinity-p value))))
       (<= 0 value)))

(defun compare-benchmark-results (baseline candidate &key (minimum-ratio 0.90d0))
  "Compare like-named, measurable throughput samples without imposing CI timing policy.
Missing/negative/nonfinite rates and mismatched names are errors. Unmeasurable
samples or differing recorded host/runtime context cannot pass. Old baselines
without context remain accepted; compare on the same host under similar load."
  (unless (equal (getf baseline :name) (getf candidate :name))
    (error "Cannot compare benchmarks with different names."))
  (let ((base (getf baseline :ops-per-second)) (current (getf candidate :ops-per-second)))
    (unless (every #'%nonnegative-finite-real-p (list base current minimum-ratio))
      (error "Benchmark rates and minimum ratio must be finite nonnegative reals."))
    (let* ((measurable (and (plusp base) (plusp current)
                            (getf baseline :measurement-valid-p t)
                            (getf candidate :measurement-valid-p t)))
           (same-context (every (lambda (key)
                                  (or (null (getf baseline key)) (null (getf candidate key))
                                      (equal (getf baseline key) (getf candidate key))))
                                '(:lisp-implementation :machine-type :software-type :software-version)))
           (ratio (and measurable (/ current base)))
           (status (cond ((not measurable) :insufficient-resolution)
                         ((not same-context) :context-mismatch)
                         (t :comparable))))
      (list :name (getf candidate :name) :baseline-ops-per-second base
            :candidate-ops-per-second current :ratio ratio :status status
            :minimum-ratio minimum-ratio
            :passes (and (eq status :comparable) (>= ratio minimum-ratio))))))

(defun stress-event-pipeline (&key (rounds 5) (iterations 50000))
  "Repeat the pure pipeline benchmark and report spread; no timing pass/fail gate.
The median averages the two central observations when ROUNDS is even."
  (check-type rounds (integer 1 *))
  (let* ((results (loop repeat rounds collect (benchmark-event-throughput :iterations iterations :warmup-iterations 1000)))
         (rates (sort (mapcar (lambda (result) (getf result :ops-per-second)) results) #'<))
         (middle (floor rounds 2))
         (median (if (oddp rounds) (nth middle rates)
                     (/ (+ (nth (1- middle) rates) (nth middle rates)) 2))))
    (list :rounds rounds :iterations-per-round iterations
          :measurement-valid-p (every (lambda (result) (getf result :measurement-valid-p)) results)
          :minimum-ops-per-second (first rates) :median-ops-per-second median
          :maximum-ops-per-second (car (last rates)) :results results)))

(defun write-benchmark-baseline (pathname results)
  "Write one readable Common Lisp value to PATHNAME, creating parent directories."
  (ensure-directories-exist pathname)
  (with-open-file (stream pathname :direction :output :if-exists :supersede :if-does-not-exist :create)
    (with-standard-io-syntax
      (let ((*print-pretty* t) (*print-readably* t))
        (write results :stream stream) (terpri stream))))
  pathname)

(defun read-benchmark-baseline (pathname)
  "Read exactly one data value with reader evaluation disabled; reject trailing forms."
  (with-open-file (stream pathname :direction :input)
    (with-standard-io-syntax
      (let* ((*read-eval* nil) (eof (gensym "EOF")) (value (read stream t)))
        (unless (eq eof (read stream nil eof))
          (error "Benchmark baseline contains more than one value."))
        value))))

(defun print-benchmark-result (result &optional (stream *standard-output*))
  "Print throughput or an insufficient-resolution notice, plus optional allocation."
  (let ((ops (getf result :ops-per-second 0.0d0)))
    (if (and (getf result :measurement-valid-p t) (plusp ops))
        (format stream "~A: ~,0F ops/s | ~,1F ns/op~@[ | ~,1F B/op~]~%"
                (getf result :name) ops (getf result :ns-per-op 0.0d0) (getf result :bytes-per-op))
        (format stream "~A: insufficient clock resolution; increase iterations~%" (getf result :name)))))

(defun run-benchmark-suite (&key (iterations 100000) (print-results t))
  "Run maintained pure microbenchmarks and return result plists, optionally printing."
  (let ((results (list (benchmark-event-throughput :iterations iterations)
                       (benchmark-input-normalization :iterations iterations))))
    (when print-results (dolist (result results) (print-benchmark-result result)))
    results))
