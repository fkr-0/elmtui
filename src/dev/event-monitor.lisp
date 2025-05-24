;;;===============================================================
;;; File: src/dev/event-monitor.lisp
;;; Event Flow Visualization and Monitoring Tool
;;;===============================================================
(uiop:define-package :elmtui.dev.event-monitor
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn)
  (:import-from :elmtui.core.events
                #:message-type
                #:message-data)
  (:import-from :elmtui.core.event-types
                #:ui-event
                #:ui-event-type
                #:ui-event-target
                #:ui-event-timestamp
                #:key-event
                #:key-event-type
                #:key-event-key
                #:key-event-modifiers
                #:mouse-event
                #:mouse-event-type
                #:mouse-event-x
                #:mouse-event-y
                #:mouse-event-button)
  (:import-from :elmtui.core.event-propagation
                #:capture-phase
                #:target-phase
                #:bubble-phase)
  (:import-from :elmtui.core.topics
                #:topic
                #:topic-name
                #:find-topic)
  (:import-from :elmtui.core.topic-registry
                #:subscribe)
  (:export 
   #:start-event-monitoring
   #:stop-event-monitoring
   #:show-event-history
   #:clear-event-history
   #:save-event-history
   #:filter-event-history
   #:visualize-event-flow))

(in-package :elmtui.dev.event-monitor)

;;;-----------------------------------------------------------------------------
;;; Event History Storage
;;;-----------------------------------------------------------------------------

(defvar *event-history* nil
  "List of recorded events for analysis.")

(defvar *event-monitoring-active* nil
  "Flag indicating if event monitoring is active.")

(defvar *max-event-history* 1000
  "Maximum number of events to keep in history.")

(defvar *monitoring-subscription-tokens* nil
  "List of subscription tokens for monitoring.")

(defvar *event-filter-predicate* nil
  "Optional predicate function to filter which events are recorded.")

;;;-----------------------------------------------------------------------------
;;; Event Recording
;;;-----------------------------------------------------------------------------

(defun record-event (event &optional context)
  "Record an event with optional context information."
  (when (and *event-monitoring-active*
             (or (null *event-filter-predicate*)
                 (funcall *event-filter-predicate* event)))
    
    ;; Add to history with timestamp
    (push (list :timestamp (get-internal-real-time)
                :event event
                :context context)
          *event-history*)
    
    ;; Trim history if needed
    (when (> (length *event-history*) *max-event-history*)
      (setf *event-history* (subseq *event-history* 0 *max-event-history*))))
  
  ;; Always return the event unchanged
  event)

(defun event-handler (topic message)
  "Generic event handler for all monitored topics."
  (record-event message (list :topic topic))
  message)

(defun phase-handler (event phase node-id)
  "Record propagation phase information."
  (record-event event (list :phase phase :node node-id))
  event)

;;;-----------------------------------------------------------------------------
;;; Monitoring Control
;;;-----------------------------------------------------------------------------

(defun start-event-monitoring (&key filter-fn max-history)
  "Start monitoring events flowing through the system.
   FILTER-FN: Optional predicate function to filter events.
   MAX-HISTORY: Maximum number of events to store (default 1000)."
  (when *event-monitoring-active*
    (stop-event-monitoring))
  
  (when max-history
    (setf *max-event-history* max-history))
  
  (setf *event-filter-predicate* filter-fn)
  (setf *event-history* nil)
  (setf *event-monitoring-active* t)
  
  ;; Subscribe to relevant topics
  (setf *monitoring-subscription-tokens*
        (list
         ;; UI events
         (subscribe "ui/#" #'event-handler :priority :low)
         ;; Input events
         (subscribe "input/#" #'event-handler :priority :low)
         ;; System events
         (subscribe "system/#" #'event-handler :priority :low)))
  
  ;; Install phase monitoring
  (elmtui.core.event-propagation:add-phase-hook :capture 
                                               (lambda (event node)
                                                 (phase-handler event :capture (getf (elmtui.view.core:ui-node-props node) :id))))
  
  (elmtui.core.event-propagation:add-phase-hook :target 
                                               (lambda (event node)
                                                 (phase-handler event :target (getf (elmtui.view.core:ui-node-props node) :id))))
  
  (elmtui.core.event-propagation:add-phase-hook :bubble 
                                               (lambda (event node)
                                                 (phase-handler event :bubble (getf (elmtui.view.core:ui-node-props node) :id))))
  
  (log-info "Event monitoring started"))

(defun stop-event-monitoring ()
  "Stop monitoring events."
  (unless *event-monitoring-active*
    (return-from stop-event-monitoring nil))
  
  ;; Unsubscribe from all topics
  (dolist (token *monitoring-subscription-tokens*)
    (elmtui.core.topic-registry:unsubscribe token))
  
  ;; Remove phase hooks
  (elmtui.core.event-propagation:remove-phase-hook :capture)
  (elmtui.core.event-propagation:remove-phase-hook :target)
  (elmtui.core.event-propagation:remove-phase-hook :bubble)
  
  (setf *event-monitoring-active* nil)
  (setf *monitoring-subscription-tokens* nil)
  
  (log-info "Event monitoring stopped with ~D events recorded" 
            (length *event-history*))
  
  (length *event-history*))

;;;-----------------------------------------------------------------------------
;;; Event History Analysis
;;;-----------------------------------------------------------------------------

(defun clear-event-history ()
  "Clear the recorded event history."
  (setf *event-history* nil)
  t)

(defun save-event-history (filename)
  "Save the event history to a file."
  (with-open-file (stream filename :direction :output :if-exists :supersede)
    (format stream "# ELMTUI Event History - ~A~%" (local-time:now))
    (format stream "# ~D events recorded~%~%" (length *event-history*))
    
    ;; Write each event in readable format
    (dolist (entry (reverse *event-history*))
      (let ((timestamp (getf entry :timestamp))
            (event (getf entry :event))
            (context (getf entry :context)))
        
        (format stream "[~A] " (format-time timestamp))
        (format-event stream event)
        (when context
          (format stream " Context: ~S" context))
        (format stream "~%"))))
  
  (log-info "Event history saved to ~A" filename)
  filename)

(defun format-time (timestamp)
  "Format a timestamp in a readable way."
  (multiple-value-bind (seconds minutes hours day month year)
      (decode-universal-time (/ timestamp internal-time-units-per-second))
    (format nil "~D-~2,'0D-~2,'0D ~2,'0D:~2,'0D:~2,'0D"
            year month day hours minutes seconds)))

(defun format-event (stream event)
  "Format an event in a readable way."
  (typecase event
    (ui-event
     (format stream "UI-EVENT type=~S target=~S" 
             (ui-event-type event) (ui-event-target event)))
    
    (key-event
     (format stream "KEY-EVENT type=~S key=~S mods=~S" 
             (key-event-type event) (key-event-key event) (key-event-modifiers event)))
    
    (mouse-event
     (format stream "MOUSE-EVENT type=~S pos=(~D,~D) button=~S" 
             (mouse-event-type event) (mouse-event-x event) (mouse-event-y event) 
             (mouse-event-button event)))
    
    (t
     (if (and (listp event) (keywordp (first event)))
         (format stream "LIST-EVENT ~S" event)
         (format stream "~S" event)))))

(defun show-event-history (&key max-events filter-fn)
  "Display the event history in a readable format.
   MAX-EVENTS: Maximum number of events to show.
   FILTER-FN: Optional predicate function to filter events."
  (let ((filtered-history 
          (if filter-fn
              (remove-if-not (lambda (entry) 
                               (funcall filter-fn (getf entry :event)))
                             *event-history*)
              *event-history*))
        (count 0))
    
    (format t "~&Event History (~D events):~%" (length filtered-history))
    (format t "~&Time                   Event~%")
    (format t "~&-----------------------------------------------------------------~%")
    
    (dolist (entry (reverse filtered-history))
      (when (and max-events (>= count max-events))
        (return))
      
      (let ((timestamp (getf entry :timestamp))
            (event (getf entry :event))
            (context (getf entry :context)))
        
        (format t "[~A] " (format-time timestamp))
        (format-event t event)
        (when context
          (format t " Context: ~S" context))
        (format t "~%"))
      
      (incf count))
    
    (when (and max-events (> (length filtered-history) max-events))
      (format t "~&... and ~D more events (use MAX-EVENTS to see more)~%" 
              (- (length filtered-history) max-events))))
  
  (values))

(defun filter-event-history (predicate)
  "Filter the event history using a predicate function.
   PREDICATE: Function taking an event and returning true to include it."
  (remove-if-not (lambda (entry) 
                   (funcall predicate (getf entry :event)))
                 *event-history*))

;;;-----------------------------------------------------------------------------
;;; Event Flow Visualization
;;;-----------------------------------------------------------------------------

(defun visualize-event-flow (output-file &key max-events filter-fn)
  "Generate a visualization of event flow using Graphviz.
   OUTPUT-FILE: Path to save the visualization (should end with .dot or .png).
   MAX-EVENTS: Maximum number of events to include.
   FILTER-FN: Optional predicate function to filter events."
  (let ((filtered-history 
          (if filter-fn
              (remove-if-not (lambda (entry) 
                               (funcall filter-fn (getf entry :event)))
                             *event-history*)
              *event-history*))
        (dot-file (if (string-equal (pathname-type output-file) "dot")
                      output-file
                      (concatenate 'string output-file ".dot"))))
    
    ;; Limit the number of events if needed
    (when (and max-events (> (length filtered-history) max-events))
      (setf filtered-history (subseq filtered-history 0 max-events)))
    
    ;; Generate DOT file
    (with-open-file (stream dot-file :direction :output :if-exists :supersede)
      (format stream "digraph event_flow {~%")
      (format stream "  rankdir=LR;~%")
      (format stream "  node [shape=box, style=filled, fillcolor=lightblue];~%")
      (format stream "  edge [color=gray50];~%")
      
      ;; Track unique nodes and edges
      (let ((nodes (make-hash-table :test 'equal))
            (edges (make-hash-table :test 'equal))
            (event-id 0)
            (last-node nil))
        
        ;; Process events in chronological order
        (dolist (entry (reverse filtered-history))
          (let* ((event (getf entry :event))
                 (context (getf entry :context))
                 (context-type (and context (first context)))
                 (node-label (format nil "event_~D" (incf event-id)))
                 (node-name (format nil "~A" (if (typep event 'ui-event)
                                               (ui-event-type event)
                                               (typecase event
                                                 (key-event (key-event-type event))
                                                 (mouse-event (mouse-event-type event))
                                                 (t (format nil "~A" event)))))))
            
            ;; Add this event as a node
            (setf (gethash node-label nodes)
                  (format nil "~A [label=\"~A\"]" 
                          node-label
                          (cl-ppcre:regex-replace-all "\"" 
                                                      (with-output-to-string (s) 
                                                        (format-event s event))
                                                      "\\\"")))
            
            ;; Add edge from previous event if any
            (when last-node
              (let ((edge-key (format nil "~A -> ~A" last-node node-label)))
                (setf (gethash edge-key edges) edge-key)))
            
            ;; Add edges for phase relationships
            (when (and context (eq context-type :phase))
              (let* ((phase (second context))
                     (node-id (third context))
                     (phase-node (format nil "phase_~A_~A" 
                                        (string-downcase (symbol-name phase))
                                        node-id))
                     (phase-color (case phase
                                    (:capture "blue")
                                    (:target "green")
                                    (:bubble "red")
                                    (t "black"))))
                
                ;; Add phase node
                (setf (gethash phase-node nodes)
                      (format nil "~A [label=\"~A\\n~A\", fillcolor=~A]" 
                              phase-node
                              (string-capitalize (symbol-name phase))
                              node-id
                              phase-color))
                
                ;; Add edge to phase node
                (let ((edge-key (format nil "~A -> ~A" node-label phase-node)))
                  (setf (gethash edge-key edges) edge-key))))
            
            ;; Remember this node for the next iteration
            (setf last-node node-label)))
        
        ;; Write all nodes
        (maphash (lambda (k v) (declare (ignore k)) (format stream "  ~A;~%" v)) nodes)
        
        ;; Write all edges
        (maphash (lambda (k v) (declare (ignore k)) (format stream "  ~A;~%" v)) edges))
      
      (format stream "}~%"))
    
    ;; Convert to PNG if requested
    (when (not (string-equal (pathname-type output-file) "dot"))
      (let ((result 
              (uiop:run-program (format nil "dot -Tpng -o \"~A\" \"~A\"" 
                                        output-file dot-file)
                                :error-output *error-output*
                                :ignore-error-status t)))
        (declare (ignore result))
        (delete-file dot-file)))
    
    (log-info "Event flow visualization saved to ~A" output-file)
    output-file))

;;;-----------------------------------------------------------------------------
;;; Module Initialization
;;;-----------------------------------------------------------------------------

;; Add phase hooks to event propagation system if they don't exist
(unless (fboundp 'elmtui.core.event-propagation:add-phase-hook)
  (defun elmtui.core.event-propagation:add-phase-hook (phase hook-fn)
    (log-warn "Phase hooks not supported in this version of elmtui"))
  
  (defun elmtui.core.event-propagation:remove-phase-hook (phase)
    (log-warn "Phase hooks not supported in this version of elmtui")))
