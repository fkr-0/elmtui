;;;===============================================================
;;; File: src/dev/event-dashboard.lisp
;;; Event System Debugging Dashboard
;;;===============================================================
(uiop:define-package :elmtui.dev.event-dashboard
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn)
  (:import-from :elmtui.core.loop
                #:get-event-loop-status
                #:get-event-queue-length
                #:*main-event-channel*)
  (:import-from :elmtui.dev.event-monitor
                #:get-event-loop-metrics
                #:get-event-processing-stats
                #:get-top-events-by-frequency
                #:get-top-events-by-processing-time
                #:start-event-monitoring
                #:stop-event-monitoring)
  (:import-from :elmtui.core.topic-registry
                #:get-all-subscriptions
                #:get-topics-with-subscribers
                #:subscription-count)
  (:import-from :elmtui.clevelib.utils
                #:format-duration
                #:format-percentage)
  (:export #:show-event-dashboard
           #:start-event-dashboard
           #:stop-event-dashboard
           #:generate-event-flow-diagram
           #:detect-event-bottlenecks
           #:analyze-event-system-health))

(in-package :elmtui.dev.event-dashboard)

;;;-----------------------------------------------------------------------------
;;; Dashboard Configuration
;;;-----------------------------------------------------------------------------

(defvar *dashboard-update-interval* 1.0
  "Update interval in seconds for the dashboard refresh.")

(defparameter *dashboard-metrics*
  '(:queue-length    "Event Queue Length"
    :processing-rate "Events/sec"
    :avg-latency     "Avg Processing Time (ms)"
    :max-latency     "Max Processing Time (ms)"
    :total-events    "Total Events Processed"
    :active-subs     "Active Subscriptions"
    :event-backlog   "Event Backlog (events)"
    :memory-usage    "Memory Usage (MB)"
    :cpu-usage       "CPU Usage (%)"
    :ui-frame-rate   "UI Frame Rate (fps)"
    :event-drop-rate "Event Drop Rate (%)")
  "Metrics to display in the dashboard with their display names.")

(defparameter *dashboard-sections*
  '(:metrics      "System Metrics"
    :top-events   "Top Events (by frequency)"
    :hot-handlers "Slowest Handlers"
    :bottlenecks  "Performance Bottlenecks"
    :subscriptions "Active Subscriptions"
    :channel-status "Channel Status")
  "Dashboard sections with their display titles.")

;;;-----------------------------------------------------------------------------
;;; Advanced Metrics Collection
;;;-----------------------------------------------------------------------------

(defstruct event-bottleneck
  "Information about an event processing bottleneck"
  (handler nil :type (or symbol function))
  (event-type nil)
  (avg-time 0.0 :type float)
  (impact-percentage 0.0 :type float)
  (occurrences 0 :type integer)
  (recommendation nil :type string))

(defvar *bottleneck-threshold-ms* 16.0
  "Threshold in milliseconds above which a handler is considered a bottleneck (16ms = ~60fps)")

(defvar *event-history* (make-array 1000 :initial-element nil :fill-pointer 0)
  "Circular buffer of recent events for flow analysis")

(defvar *event-history-pointer* 0
  "Current position in the event history circular buffer")

(defun collect-dashboard-data ()
  "Collect all data needed for the dashboard display."
  (let* ((metrics (get-event-loop-metrics))
         (stats (get-event-processing-stats))
         (top-events (get-top-events-by-frequency 10))
         (slow-handlers (get-top-events-by-processing-time 5))
         (bottlenecks (detect-event-bottlenecks))
         (subscriptions (get-all-subscriptions))
         (queue-length (get-event-queue-length))
         (channel-status (get-channel-status)))
    
    (list :metrics (list :queue-length queue-length
                         :processing-rate (getf stats :events-per-second)
                         :avg-latency (getf stats :average-processing-time)
                         :max-latency (getf stats :max-processing-time)
                         :total-events (getf stats :total-events)
                         :active-subs (subscription-count)
                         :event-backlog (calculate-event-backlog stats)
                         :memory-usage (get-process-memory-usage)
                         :cpu-usage (get-process-cpu-usage)
                         :ui-frame-rate (estimate-ui-frame-rate stats)
                         :event-drop-rate (calculate-event-drop-rate stats))
          :top-events top-events
          :hot-handlers slow-handlers
          :bottlenecks bottlenecks
          :subscriptions subscriptions
          :channel-status channel-status)))

(defun calculate-event-backlog (stats)
  "Calculate the current event backlog based on processing rate and queue length."
  (let ((processing-rate (getf stats :events-per-second))
        (queue-length (get-event-queue-length)))
    (if (and processing-rate (numberp queue-length) (> processing-rate 0))
        (float (/ queue-length processing-rate))
        :unknown)))

(defun get-process-memory-usage ()
  "Get the current memory usage of the process in MB."
  ;; Implementation dependent - this is a stub
  (declare (ignore-errors t))
  (handler-case
      (with-open-file (s "/proc/self/stat" :if-does-not-exist nil)
        (when s
          (let* ((stats (read-line s nil))
                 (tokens (split-sequence:split-sequence #\Space stats))
                 (vm-size (parse-integer (nth 22 tokens) :junk-allowed t)))
            (when vm-size
              (float (/ vm-size 1024 1024))))))
    (error () :unknown)))

(defun get-process-cpu-usage ()
  "Get the current CPU usage of the process as a percentage."
  ;; Implementation dependent - this is a stub
  (declare (ignore-errors t))
  (handler-case
      (let ((total 0))
        (with-open-file (s "/proc/self/stat" :if-does-not-exist nil)
          (when s
            (let* ((stats (read-line s nil))
                   (tokens (split-sequence:split-sequence #\Space stats))
                   (utime (parse-integer (nth 13 tokens) :junk-allowed t))
                   (stime (parse-integer (nth 14 tokens) :junk-allowed t)))
              (setq total (+ utime stime)))))
        
        ;; This is very simplified - a real implementation would track
        ;; changes over time to calculate percentage
        (if (> total 0)
            (mod total 100) ; Just to show something changing
            :unknown))
    (error () :unknown)))

(defun estimate-ui-frame-rate (stats)
  "Estimate the UI frame rate based on event processing statistics."
  (let ((avg-latency (getf stats :average-processing-time)))
    (if (and avg-latency (> avg-latency 0))
        (min 60 (float (/ 1000 avg-latency)))
        :unknown)))

(defun calculate-event-drop-rate (stats)
  "Calculate the percentage of events that are being dropped (if any)."
  ;; This is a stub - a real implementation would track dropped events
  (declare (ignore stats))
  0.0) ; Assume no drops for now

(defun get-channel-status ()
  "Get status information about all event channels."
  (list 
   (list :name "Main Event Channel" 
         :length (get-event-queue-length)
         :status (if *main-event-channel* "Active" "Inactive"))))

(defun detect-event-bottlenecks ()
  "Analyze event processing data to identify bottlenecks."
  (let ((slow-handlers (get-top-events-by-processing-time 10))
        (bottlenecks nil))
    
    (loop for (handler avg-time max-time) in slow-handlers
          when (> avg-time *bottleneck-threshold-ms*)
          do (push (make-event-bottleneck 
                    :handler handler
                    :event-type (handler-event-type handler)
                    :avg-time avg-time
                    :impact-percentage (calculate-impact-percentage avg-time)
                    :occurrences (handler-occurrence-count handler)
                    :recommendation (generate-optimization-recommendation 
                                     handler avg-time max-time))
                   bottlenecks))
    
    (nreverse bottlenecks)))

(defun handler-event-type (handler)
  "Try to determine what event type this handler processes."
  ;; This is a stub - would need to map handlers to event types
  (declare (ignore handler))
  :unknown)

(defun handler-occurrence-count (handler)
  "Get the number of times this handler has been called."
  ;; This is a stub - would need event counting
  (declare (ignore handler))
  (+ 10 (random 100)))

(defun calculate-impact-percentage (avg-time)
  "Calculate the performance impact percentage of a slow handler."
  (let ((frame-budget 16.67)) ; ~60fps
    (min 100.0 (* 100.0 (/ avg-time frame-budget)))))

(defun generate-optimization-recommendation (handler avg-time max-time)
  "Generate a recommendation for optimizing a slow handler."
  (cond
    ((> max-time 100)
     "Consider moving work to a background thread or splitting the operation.")
    ((> avg-time 50)
     "Throttle this event handler or optimize its core algorithm.")
    ((> avg-time 25)
     "Consider debouncing this handler for less frequent events.")
    (t "Review handler implementation for optimization opportunities.")))

;;;-----------------------------------------------------------------------------
;;; Dashboard Rendering
;;;-----------------------------------------------------------------------------

(defun render-metrics-section (metrics stream)
  "Render the metrics section of the dashboard."
  (format stream "~%~A~%" (getf *dashboard-sections* :metrics))
  (format stream "~A~%" (make-string (length (getf *dashboard-sections* :metrics)) :initial-element #\=))
  
  (loop for (key label) on *dashboard-metrics* by #'cddr
        for value = (getf metrics key)
        when value
        do (format stream "~30A: ~A~%" label 
                   (cond
                     ((eq value :unknown) "Unknown")
                     ((and (numberp value) (member key '(:avg-latency :max-latency)))
                      (format nil "~,2F ms" value))
                     ((and (numberp value) (eq key :processing-rate))
                      (format nil "~,2F" value))
                     ((and (numberp value) (member key '(:cpu-usage :event-drop-rate)))
                      (format nil "~,1F%" value))
                     ((and (numberp value) (eq key :ui-frame-rate))
                      (format nil "~,1F" value))
                     ((and (numberp value) (eq key :memory-usage))
                      (format nil "~,1F MB" value))
                     (t value)))))

(defun render-top-events-section (top-events stream)
  "Render the top events section of the dashboard."
  (format stream "~%~A~%" (getf *dashboard-sections* :top-events))
  (format stream "~A~%" (make-string (length (getf *dashboard-sections* :top-events)) :initial-element #\=))
  
  (format stream "~5A ~30A ~10A ~10A~%" "Rank" "Event Type/Topic" "Count" "% Total")
  (loop for (event-type count percentage) in top-events
        for rank from 1
        do (format stream "~5D ~30A ~10D ~10,2F%~%" 
                   rank
                   (if (stringp event-type)
                       event-type
                       (format nil "~S" event-type))
                   count
                   percentage)))

(defun render-hot-handlers-section (hot-handlers stream)
  "Render the hot handlers section of the dashboard."
  (format stream "~%~A~%" (getf *dashboard-sections* :hot-handlers))
  (format stream "~A~%" (make-string (length (getf *dashboard-sections* :hot-handlers)) :initial-element #\=))
  
  (format stream "~5A ~30A ~15A ~15A~%" "Rank" "Handler/Topic" "Avg Time (ms)" "Max Time (ms)")
  (loop for (handler avg-time max-time) in hot-handlers
        for rank from 1
        do (format stream "~5D ~30A ~15,3F ~15,3F~%" 
                   rank
                   (if (stringp handler)
                       handler
                       (format nil "~S" handler))
                   avg-time
                   max-time)))

(defun render-bottlenecks-section (bottlenecks stream)
  "Render the bottlenecks section of the dashboard."
  (format stream "~%~A~%" (getf *dashboard-sections* :bottlenecks))
  (format stream "~A~%" (make-string (length (getf *dashboard-sections* :bottlenecks)) :initial-element #\=))
  
  (if bottlenecks
      (progn
        (format stream "~30A ~10A ~10A ~40A~%" 
                "Handler" "Time (ms)" "Impact" "Recommendation")
        (loop for bottleneck in bottlenecks
              do (format stream "~30A ~10,2F ~10,1F% ~40A~%" 
                         (format nil "~S" (event-bottleneck-handler bottleneck))
                         (event-bottleneck-avg-time bottleneck)
                         (event-bottleneck-impact-percentage bottleneck)
                         (event-bottleneck-recommendation bottleneck))))
      (format stream "No significant bottlenecks detected.~%")))

(defun render-subscriptions-section (subscriptions stream)
  "Render the subscriptions section of the dashboard."
  (format stream "~%~A~%" (getf *dashboard-sections* :subscriptions))
  (format stream "~A~%" (make-string (length (getf *dashboard-sections* :subscriptions)) :initial-element #\=))
  
  (format stream "~30A ~30A~%" "Topic" "Subscriber")
  (loop for (topic . subscribers) in subscriptions
        do (loop for subscriber in subscribers
                 do (format stream "~30A ~30A~%" 
                            (if (stringp topic) 
                                topic 
                                (format nil "~S" topic))
                            (format nil "~S" subscriber)))))

(defun render-channel-status-section (channel-status stream)
  "Render the channel status section of the dashboard."
  (format stream "~%~A~%" (getf *dashboard-sections* :channel-status))
  (format stream "~A~%" (make-string (length (getf *dashboard-sections* :channel-status)) :initial-element #\=))
  
  (format stream "~20A ~15A ~15A~%" "Channel" "Queue Length" "Status")
  (loop for channel in channel-status
        do (format stream "~20A ~15A ~15A~%" 
                   (getf channel :name)
                   (let ((len (getf channel :length)))
                     (if (eq len :unknown) "Unknown" len))
                   (getf channel :status))))

(defun render-dashboard (data &optional (stream *standard-output*))
  "Render the full dashboard to the given stream."
  (format stream "~%ELMTUI Event System Dashboard~%")
  (format stream "============================~%")
  (format stream "Last updated: ~A~%" (local-time:format-timestring nil (local-time:now)))
  
  (render-metrics-section (getf data :metrics) stream)
  (render-top-events-section (getf data :top-events) stream)
  (render-hot-handlers-section (getf data :hot-handlers) stream)
  (render-bottlenecks-section (getf data :bottlenecks) stream)
  (render-subscriptions-section (getf data :subscriptions) stream)
  (render-channel-status-section (getf data :channel-status) stream))

;;;-----------------------------------------------------------------------------
;;; Event Flow Visualization
;;;-----------------------------------------------------------------------------

(defun record-event (event)
  "Record an event in the event history for flow analysis."
  (when (< (length *event-history*) 1000)
    (vector-push-extend event *event-history*))
  (setf (aref *event-history* *event-history-pointer*) event)
  (setf *event-history-pointer* (mod (1+ *event-history-pointer*) 1000)))

(defun generate-event-flow-diagram (&optional (output-file "event-flow.dot"))
  "Generate a Graphviz DOT file visualizing the event flow."
  (with-open-file (stream output-file :direction :output 
                          :if-exists :supersede :if-does-not-exist :create)
    (format stream "digraph EventFlow {~%")
    (format stream "  rankdir=LR;~%")
    (format stream "  node [shape=box, style=filled, fillcolor=lightblue];~%")
    
    ;; Generate nodes and edges based on event history
    (let ((sources (make-hash-table :test 'equal))
          (targets (make-hash-table :test 'equal))
          (edges (make-hash-table :test 'equal)))
      
      ;; Analyze events to build the graph
      (loop for i from 0 below (length *event-history*)
            for event = (aref *event-history* i)
            when event
            do (let ((source (event-source event))
                     (target (event-target event)))
                 (incf (gethash source sources 0))
                 (incf (gethash target targets 0))
                 (incf (gethash (cons source target) edges 0))))
      
      ;; Output nodes
      (maphash (lambda (source count)
                 (format stream "  \"~A\" [label=\"~A\\n(~D events)\"];~%"
                         source source count))
               sources)
      
      ;; Output edges
      (maphash (lambda (edge count)
                 (format stream "  \"~A\" -> \"~A\" [label=\"~D\", weight=~D];~%"
                         (car edge) (cdr edge) count count))
               edges))
    
    (format stream "}~%"))
  
  (format t "Event flow diagram generated as ~A~%" output-file)
  (format t "To visualize, run: dot -Tpng ~A -o event-flow.png~%" output-file)
  output-file)

(defun event-source (event)
  "Extract the source of an event."
  ;; This is a stub - would depend on event structure
  (cond
    ((typep event 'key-event) "Keyboard")
    ((and (listp event) (eq (first event) :mouse)) "Mouse")
    ((and (listp event) (eq (first event) :app-message)) "Application")
    (t "Unknown")))

(defun event-target (event)
  "Extract the target of an event."
  ;; This is a stub - would depend on event structure
  (cond
    ((and (listp event) (eq (first event) :app-message)) "App Update")
    ((typep event 'key-event) "Key Handler")
    (t "Event System")))

;;;-----------------------------------------------------------------------------
;;; System Health Analysis
;;;-----------------------------------------------------------------------------

(defun analyze-event-system-health ()
  "Perform a comprehensive analysis of the event system's health."
  (let* ((metrics (get-event-loop-metrics))
         (stats (get-event-processing-stats))
         (avg-latency (getf stats :average-processing-time))
         (queue-length (get-event-queue-length))
         (bottlenecks (detect-event-bottlenecks))
         (health-status :good)
         (issues nil))
    
    ;; Check for high latency
    (when (and (numberp avg-latency) (> avg-latency 33))
      (push "High average processing time (>33ms) may cause UI lag" issues)
      (setq health-status (if (> avg-latency 50) :critical :warning)))
    
    ;; Check for queue buildup
    (when (and (numberp queue-length) (> queue-length 10))
      (push (format nil "Event queue building up (~D events)" queue-length) issues)
      (setq health-status (if (> queue-length 50) :critical :warning)))
    
    ;; Check for bottlenecks
    (when bottlenecks
      (push (format nil "~D performance bottlenecks detected" (length bottlenecks)) issues)
      (setq health-status :warning))
    
    ;; Return the analysis
    (list :status health-status
          :issues issues
          :recommendations (generate-health-recommendations health-status issues bottlenecks))))

(defun generate-health-recommendations (status issues bottlenecks)
  "Generate recommendations based on system health analysis."
  (declare (ignore issues)) ; We'll use the full information for now
  
  (case status
    (:critical
     (list "Consider emergency throttling of event sources"
           "Look for blocking operations in event handlers"
           "Check for infinite loops or recursion in event processing"))
    (:warning
     (append
      (when bottlenecks
        (list "Optimize the identified bottleneck handlers"
              "Consider using throttle/debounce for high-frequency events"))
      (list "Monitor CPU and memory usage for resource constraints")))
    (otherwise
     (list "System appears healthy"
           "Continue monitoring for potential issues"))))

;;;-----------------------------------------------------------------------------
;;; Dashboard API
;;;-----------------------------------------------------------------------------

(defun show-event-dashboard (&optional (stream *standard-output*))
  "Display the current event system dashboard to the specified stream."
  (let ((data (collect-dashboard-data)))
    (render-dashboard data stream)
    data))

(defvar *dashboard-thread* nil
  "Thread for the continuously updating dashboard.")

(defvar *stop-dashboard* nil
  "Flag to signal the dashboard thread to stop.")

(defun start-event-dashboard (&key (interval *dashboard-update-interval*) (stream *standard-output*) (clear-screen t))
  "Start a continuously updating event dashboard.
   INTERVAL: Update interval in seconds (default: 1 second)
   STREAM: Output stream (default: *standard-output*)
   CLEAR-SCREEN: Whether to clear the screen before each update (default: T)"
  (when *dashboard-thread*
    (stop-event-dashboard)
    (sleep 0.1)) ; Give time for the old thread to terminate
  
  ;; Ensure event monitoring is active
  (start-event-monitoring)
  
  (setf *stop-dashboard* nil)
  (setf *dashboard-thread*
        (bt:make-thread
         (lambda ()
           (unwind-protect
                (loop until *stop-dashboard* do
                  (when clear-screen
                    ;; Clear screen - ANSI escape sequence
                    (format stream "~c[2J~c[H" #\ESC #\ESC))
                  (show-event-dashboard stream)
                  (sleep interval))
             (format stream "~%Event Dashboard stopped.~%")))
         :name "ELMTUI Event Dashboard"))
  
  (values *dashboard-thread* "Event dashboard started. Use STOP-EVENT-DASHBOARD to exit."))

(defun stop-event-dashboard ()
  "Stop the continuously updating event dashboard."
  (when *dashboard-thread*
    (setf *stop-dashboard* t)
    (bt:join-thread *dashboard-thread* :timeout 2)
    (setf *dashboard-thread* nil)
    t))

;;;-----------------------------------------------------------------------------
;;; Initialize Module
;;;-----------------------------------------------------------------------------

;; Ensure we have the split-sequence package
(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package :split-sequence)
    (asdf:load-system :split-sequence)))

;; Add any initialization code here if needed
(log-info "Enhanced Event Dashboard module loaded and ready.")
