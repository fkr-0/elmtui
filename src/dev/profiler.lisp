;;; -*- mode: lisp; indent-tabs-mode: nil -*-
;;;
;;; Profiling and Timing Utilities for Startup Performance Analysis
;;;
;;; This module provides lightweight profiling tools to measure elapsed time
;;; between checkpoints during ElmTUI application startup to identify
;;; performance bottlenecks.

(defpackage :elmtui.dev.profiler
  (:use :common-lisp)
  (:import-from :log4cl
                #:log-info
                #:log-warn
                #:log-error)
  (:export #:start-profiling-session
           #:end-profiling-session
           #:profile-checkpoint
           #:with-profiling
           #:get-timing-report
           #:clear-timing-data
           #:*profiling-enabled*))

(in-package :elmtui.dev.profiler)

;;; ---------------------------------------------------------------------------
;;; == Global State ==
;;; ---------------------------------------------------------------------------

(defvar *profiling-enabled* nil
  "When T, profiling measurements are collected. When NIL, profiling calls are no-ops.")

(defvar *profiling-session-start* nil
  "Internal real time when profiling session started.")

(defvar *timing-checkpoints* nil
  "List of timing checkpoints: (name timestamp-ms description)")

(defvar *timing-data* nil
  "Accumulated timing data across sessions.")

;;; ---------------------------------------------------------------------------
;;; == Core Profiling Functions ==
;;; ---------------------------------------------------------------------------

(defun start-profiling-session (&optional (description "Startup profiling"))
  "Start a new profiling session, resetting checkpoint data.
   Arguments:
     DESCRIPTION (string): Optional description for this profiling session.
   Returns:
     The starting timestamp (internal-real-time)
   Side-effects: Clears previous timing checkpoints and starts new session."
  (declare (type string description))
  (when *profiling-enabled*
    (setf *profiling-session-start* (get-internal-real-time))
    (setf *timing-checkpoints* nil)
    (log-info "PROFILER: Started profiling session: ~A at time ~A" 
              description *profiling-session-start*)
    *profiling-session-start*))

(defun end-profiling-session (&optional (description "Session complete"))
  "End the current profiling session and log summary.
   Arguments:
     DESCRIPTION (string): Optional description for session end.
   Returns:
     Total session duration in seconds (float)
   Side-effects: Logs session summary and preserves timing data."
  (declare (type string description))
  (when (and *profiling-enabled* *profiling-session-start*)
    (let* ((end-time (get-internal-real-time))
           (total-ms (/ (- end-time *profiling-session-start*) 
                       (/ internal-time-units-per-second 1000.0)))
           (total-seconds (/ total-ms 1000.0)))
      (log-info "PROFILER: ~A - Total session time: ~,3F seconds (~,1F ms)"
                description total-seconds total-ms)
      (push (list :session-end end-time total-ms description) *timing-checkpoints*)
      ;; Preserve data for reporting
      (push (list :session *timing-checkpoints*) *timing-data*)
      total-seconds)))

(defun profile-checkpoint (name &optional (description ""))
  "Record a timing checkpoint with the given name and optional description.
   Arguments:
     NAME (keyword or string): Identifier for this checkpoint.
     DESCRIPTION (string): Optional detailed description.
   Returns:
     Elapsed milliseconds since session start, or NIL if not profiling.
   Side-effects: Records checkpoint in timing data."
  (when (and *profiling-enabled* *profiling-session-start*)
    (let* ((current-time (get-internal-real-time))
           (elapsed-ms (/ (- current-time *profiling-session-start*)
                         (/ internal-time-units-per-second 1000.0))))
      (push (list name elapsed-ms description current-time) *timing-checkpoints*)
      (log-info "PROFILER: [~,1F ms] ~A~@[ - ~A~]" elapsed-ms name 
                (when (and description (not (string= description ""))) description))
      elapsed-ms)))

(defmacro with-profiling ((checkpoint-name &optional description) &body body)
  "Execute BODY with automatic profiling checkpoints before and after.
   Arguments:
     CHECKPOINT-NAME (keyword or string): Base name for checkpoints.
     DESCRIPTION (string): Optional description.
   Returns:
     Values returned by BODY.
   Side-effects: Records 'start' and 'end' checkpoints around BODY execution."
  (let ((start-name (if (keywordp checkpoint-name)
                        (intern (format nil "~A-START" (symbol-name checkpoint-name)) :keyword)
                        (format nil "~A-start" checkpoint-name)))
        (end-name (if (keywordp checkpoint-name)
                      (intern (format nil "~A-END" (symbol-name checkpoint-name)) :keyword)
                      (format nil "~A-end" checkpoint-name))))
    `(progn
       (profile-checkpoint ,start-name ,(format nil "Starting ~A~@[ - ~A~]" checkpoint-name description))
       (multiple-value-prog1
           (progn ,@body)
         (profile-checkpoint ,end-name ,(format nil "Completed ~A~@[ - ~A~]" checkpoint-name description))))))

;;; ---------------------------------------------------------------------------
;;; == Reporting and Analysis ==
;;; ---------------------------------------------------------------------------

(defun get-timing-report (&optional (detailed-p t))
  "Generate a timing report from collected profiling data.
   Arguments:
     DETAILED-P (boolean): If T, include detailed checkpoint info.
   Returns:
     String containing formatted timing report.
   Side-effects: None."
  (declare (type boolean detailed-p))
  (if (null *timing-data*)
      "No profiling data available."
      (with-output-to-string (s)
        (format s "~%=== ELMTUI STARTUP PROFILING REPORT ===~%")
        (dolist (session-data (reverse *timing-data*))
          (let ((checkpoints (second session-data)))
            (when checkpoints
              (format s "~%Session Checkpoints (~A total):~%" (length checkpoints))
              (dolist (checkpoint (reverse checkpoints))
                (destructuring-bind (name elapsed-ms description &optional timestamp) checkpoint
                  (declare (ignore timestamp))
                  (if detailed-p
                      (format s "  [~6,1F ms] ~A~@[ - ~A~]~%" elapsed-ms name 
                              (when (and description (not (string= description ""))) description))
                      (format s "  [~6,1F ms] ~A~%" elapsed-ms name))))
              ;; Calculate intervals between checkpoints
              (when (and detailed-p (> (length checkpoints) 1))
                (format s "~%Intervals:~%")
                (let ((sorted-checkpoints (sort (copy-list checkpoints) #'< :key #'second)))
                  (loop for i from 1 below (length sorted-checkpoints)
                        for prev = (nth (1- i) sorted-checkpoints)
                        for curr = (nth i sorted-checkpoints)
                        for interval = (- (second curr) (second prev))
                        do (format s "  ~A -> ~A: ~6,1F ms~%" 
                                  (first prev) (first curr) interval))))))))
      ))

(defun clear-timing-data ()
  "Clear all accumulated timing data and reset profiling state.
   Returns: NIL
   Side-effects: Clears all profiling state variables."
  (setf *timing-data* nil
        *timing-checkpoints* nil
        *profiling-session-start* nil)
  (log-info "PROFILER: All timing data cleared."))

;;; ---------------------------------------------------------------------------
;;; == Convenience Functions for Common Patterns ==
;;; ---------------------------------------------------------------------------

(defun profile-function-call (function-name function &rest args)
  "Profile a function call, recording start/end checkpoints.
   Arguments:
     FUNCTION-NAME (string or keyword): Name for profiling checkpoint.
     FUNCTION (function): Function to call.
     ARGS: Arguments to pass to FUNCTION.
   Returns:
     Values returned by FUNCTION.
   Side-effects: Records profiling checkpoints."
  (with-profiling (function-name)
    (apply function args)))

(defmacro profile-form ((name &optional description) &body body)
  "Alias for WITH-PROFILING for convenience."
  `(with-profiling (,name ,description) ,@body))