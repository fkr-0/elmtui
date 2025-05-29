;;;===============================================================
;;; File: src/dev/event-benchmark.lisp
;;; Event Performance Benchmarking Utilities
;;;===============================================================
(uiop:define-package :elmtui.dev.event-benchmark
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn)
  (:import-from :elmtui.core.event-types
                #:ui-event
                #:ui-event-type
                #:ui-event-timestamp
                #:make-ui-event
                #:key-event
                #:make-key-event)
  (:import-from :elmtui.dev.event-monitor
                #:start-event-monitoring
                #:stop-event-monitoring
                #:clear-event-history
                #:filter-event-history)
  (:export 
   #:benchmark-event-throughput
   #:benchmark-event-propagation
   #:benchmark-event-handlers
   #:generate-event-benchmark-report))

(in-package :elmtui.dev.event-benchmark)

;;;-----------------------------------------------------------------------------
;;; Benchmarking State Variables
;;;-----------------------------------------------------------------------------

(defvar *benchmark-results* nil
  "Collection of benchmark results for analysis.")

(defun clear-benchmark-results ()
  "Clear stored benchmark results."
  (setf *benchmark-results* nil))

(defun add-benchmark-result (name result)
  "Add a benchmark result to the collection."
  (push (cons name result) *benchmark-results*))

;;;-----------------------------------------------------------------------------
;;; Event Generation Functions
;;;-----------------------------------------------------------------------------

(defun generate-test-events (count &key (event-type :keydown) (key-range 26))
  "Generate a vector of test events.

   Args:
     COUNT: Number of events to generate.
     EVENT-TYPE: Type of events to generate (:keydown, :keyup, etc.)
     KEY-RANGE: Range of key codes to use (integer).

   Returns:
     Vector of test events."
  (let ((events (make-array count)))
    (dotimes (i count)
      (setf (aref events i)
            (make-key-event :type event-type
                           :key (code-char (+ 97 (mod i key-range)))
                           :timestamp (+ (get-internal-real-time) i))))
    events))

;;;-----------------------------------------------------------------------------
;;; Benchmark Functions
;;;-----------------------------------------------------------------------------

(defun benchmark-event-throughput (&key (event-count 10000) (iterations 5))
  "Benchmark raw event throughput.

   Args:
     EVENT-COUNT: Number of events to process in each iteration.
     ITERATIONS: Number of benchmark iterations to run.

   Returns:
     Plist with benchmark results."
  (format t "~&Benchmarking event throughput with ~D events × ~D iterations...~%"
          event-count iterations)
  
  (let ((results nil)
        (total-time 0)
        (events (generate-test-events event-count)))
    
    ;; Run multiple iterations
    (dotimes (i iterations)
      (let ((start-time (get-internal-real-time))
            (processed 0))
        
        ;; Process all events as quickly as possible
        (dotimes (j event-count)
          (let ((event (aref events j)))
            ;; Simulate minimal processing
            (when (typep event 'key-event)
              (incf processed))))
        
        (let ((elapsed (- (get-internal-real-time) start-time))
              (elapsed-seconds (/ (- (get-internal-real-time) start-time)
                                internal-time-units-per-second)))
          (push elapsed results)
          (incf total-time elapsed)
          
          (format t "  Iteration ~D: ~,2F ms (~,2F events/sec)~%"
                  (1+ i)
                  (* 1000 elapsed-seconds)
                  (/ processed elapsed-seconds)))))
    
    ;; Calculate statistics
    (let* ((average (/ total-time iterations))
           (average-seconds (/ average internal-time-units-per-second))
           (events-per-second (/ event-count average-seconds))
           (result (list :event-count event-count
                        :iterations iterations
                        :total-time-units total-time
                        :average-time-units average
                        :events-per-second events-per-second)))
      
      (format t "~&Results: ~,2F events/second average~%" events-per-second)
      
      ;; Store result
      (add-benchmark-result :throughput result)
      
      result)))

(defun benchmark-event-propagation (&key (event-count 1000) (tree-depth 5))
  "Benchmark event propagation through a UI tree.

   Args:
     EVENT-COUNT: Number of events to process.
     TREE-DEPTH: Depth of the UI tree to create.

   Returns:
     Plist with benchmark results."
  (format t "~&Benchmarking event propagation with ~D events through tree depth ~D...~%"
          event-count tree-depth)
  
  ;; Create a test UI tree
  (let* ((events (generate-test-events event-count))
         (ui-tree (create-test-ui-tree tree-depth))
         (start-time (get-internal-real-time))
         (processed 0))
    
    ;; Process events through the tree
    (dotimes (i event-count)
      (let ((event (aref events i)))
        ;; Simulate event propagation (capture, target, bubble phases)
        (simulate-event-propagation event ui-tree)
        (incf processed)))
    
    ;; Calculate results
    (let* ((elapsed (- (get-internal-real-time) start-time))
           (elapsed-seconds (/ elapsed internal-time-units-per-second))
           (events-per-second (/ processed elapsed-seconds))
           (result (list :event-count processed
                        :tree-depth tree-depth
                        :total-time-units elapsed
                        :events-per-second events-per-second)))
      
      (format t "~&Results: ~,2F events/second with tree depth ~D~%" 
              events-per-second tree-depth)
      
      ;; Store result
      (add-benchmark-result :propagation result)
      
      result)))

(defun benchmark-event-handlers (&key (handler-count 10) (event-count 1000))
  "Benchmark event handler invocation performance.

   Args:
     HANDLER-COUNT: Number of handlers to attach.
     EVENT-COUNT: Number of events to process.

   Returns:
     Plist with benchmark results."
  (format t "~&Benchmarking event handlers with ~D handlers × ~D events...~%"
          handler-count event-count)
  
  (let* ((events (generate-test-events event-count))
         (handlers (make-array handler-count))
         (handler-calls (make-array handler-count :initial-element 0))
         (start-time 0)
         (total-time 0))
    
    ;; Create test handlers
    (dotimes (i handler-count)
      (let ((index i))
        (setf (aref handlers i)
              (lambda (event)
                (declare (ignore event))
                (incf (aref handler-calls index))))))
    
    ;; Start timing
    (setf start-time (get-internal-real-time))
    
    ;; Process events through all handlers
    (dotimes (i event-count)
      (let ((event (aref events i)))
        (dotimes (j handler-count)
          (funcall (aref handlers j) event))))
    
    ;; Calculate results
    (setf total-time (- (get-internal-real-time) start-time))
    (let* ((elapsed-seconds (/ total-time internal-time-units-per-second))
           (total-handler-calls (apply #'+ (coerce handler-calls 'list)))
           (handlers-per-second (/ total-handler-calls elapsed-seconds))
           (result (list :handler-count handler-count
                        :event-count event-count
                        :total-time-units total-time
                        :total-handler-calls total-handler-calls
                        :handlers-per-second handlers-per-second)))
      
      (format t "~&Results: ~,2F handler calls/second with ~D handlers~%" 
              handlers-per-second handler-count)
      
      ;; Store result
      (add-benchmark-result :handlers result)
      
      result)))

;;;-----------------------------------------------------------------------------
;;; Helper Functions
;;;-----------------------------------------------------------------------------

(defun create-test-ui-tree (depth)
  "Create a test UI tree with the specified depth.

   Args:
     DEPTH: Desired tree depth.

   Returns:
     A nested list representing a UI tree."
  (labels ((build-tree (current-depth id)
             (if (= current-depth 0)
                 (list :type :leaf :id id)
                 (list :type :node
                       :id id
                       :children (list (build-tree (1- current-depth) 
                                                  (format nil "~A-1" id))
                                       (build-tree (1- current-depth)
                                                  (format nil "~A-2" id)))))))
    (build-tree depth "root")))

(defun simulate-event-propagation (event tree)
  "Simulate propagating an event through a UI tree.

   Args:
     EVENT: The event to propagate.
     TREE: The UI tree to propagate through.

   Returns:
     T if event was handled, NIL otherwise."
  (labels ((propagate-down (node phase)
             (when node
               ;; Process this node
               (when (getf node :handler)
                 (funcall (getf node :handler) event phase))
               
               ;; Process children for capture phase
               (when (eq phase :capture)
                 (dolist (child (getf node :children))
                   (propagate-down child phase)))))
           
           (propagate-up (node phase)
             (when node
               ;; Process this node
               (when (getf node :handler)
                 (funcall (getf node :handler) event phase))
               
               ;; Process parent for bubble phase
               (when (eq phase :bubble)
                 (when-let ((parent (getf node :parent)))
                   (propagate-up parent phase))))))
    
    ;; Capture phase (root to target)
    (propagate-down tree :capture)
    
    ;; Target phase
    (let ((target (getf tree :id)))
      (when target
        (propagate-up target :target)))
    
    ;; Bubble phase (target to root)
    (let ((target (getf tree :id)))
      (when target
        (propagate-up target :bubble)))))

;;;-----------------------------------------------------------------------------
;;; Reporting Functions
;;;-----------------------------------------------------------------------------

(defun generate-event-benchmark-report (&optional filename)
  "Generate a report of all benchmark results.

   Args:
     FILENAME: Optional filename to save the report to.

   Returns:
     Report string."
  (with-output-to-string (report)
    (format report "~&========================================~%")
    (format report "ELMTUI Event System Benchmark Report~%")
    (format report "========================================~%")
    (format report "Generated: ~A~%~%" (local-time:now))
    
    ;; Report throughput results
    (format report "~&Event Throughput Results:~%")
    (format report "------------------------~%")
    (let ((results (cdr (assoc :throughput *benchmark-results*))))
      (when results
        (format report "Events processed: ~D~%" (getf results :event-count))
        (format report "Iterations: ~D~%" (getf results :iterations))
        (format report "Average events per second: ~,2F~%~%" 
                (getf results :events-per-second))))
    
    ;; Report propagation results
    (format report "~&Event Propagation Results:~%")
    (format report "-------------------------~%")
    (let ((results (cdr (assoc :propagation *benchmark-results*))))
      (when results
        (format report "Events processed: ~D~%" (getf results :event-count))
        (format report "Tree depth: ~D~%" (getf results :tree-depth))
        (format report "Events per second: ~,2F~%~%" 
                (getf results :events-per-second))))
    
    ;; Report handler results
    (format report "~&Event Handler Results:~%")
    (format report "--------------------~%")
    (let ((results (cdr (assoc :handlers *benchmark-results*))))
      (when results
        (format report "Handlers: ~D~%" (getf results :handler-count))
        (format report "Events: ~D~%" (getf results :event-count))
        (format report "Total handler calls: ~D~%" (getf results :total-handler-calls))
        (format report "Handler calls per second: ~,2F~%~%" 
                (getf results :handlers-per-second))))
    
    ;; Save to file if requested
    (when filename
      (with-open-file (file filename :direction :output :if-exists :supersede)
        (write-string (get-output-stream-string report) file)))))

;;;-----------------------------------------------------------------------------
;;; Main Benchmark Functions
;;;-----------------------------------------------------------------------------

(defun run-all-benchmarks ()
  "Run all event benchmarks and generate a report.

   Returns:
     Report string."
  (clear-benchmark-results)
  
  ;; Run all benchmarks
  (benchmark-event-throughput)
  (benchmark-event-propagation)
  (benchmark-event-handlers)
  
  ;; Generate and return report
  (generate-event-benchmark-report))
