(defpackage :elmtui.platform.profiler
  (:use :cl)
  (:export :profile-components
           :suggest-memoization-candidates
           :find-expensive-components
           :with-component-profiling
           :show-render-stats
           :enable-profiling
           :disable-profiling))

(in-package :elmtui.platform.profiler)

;; Profiling data structures
(defvar *render-times* (make-hash-table :test #'eq)
  "Hash table mapping components to rendering times")

(defvar *render-counts* (make-hash-table :test #'eq)
  "Hash table mapping components to render counts")

(defvar *call-tree* nil
  "Current component call tree during profiling")

(defvar *profiling-enabled* nil
  "Flag to enable/disable profiling")

;; Enable/disable profiling
(defun enable-profiling ()
  "Enable component profiling"
  (setf *profiling-enabled* t))

(defun disable-profiling ()
  "Disable component profiling"
  (setf *profiling-enabled* nil))

;; Clear profiling data
(defun clear-profiling-data ()
  "Reset all profiling counters and timing data"
  (clrhash *render-times*)
  (clrhash *render-counts*))

;; Profile a component render
(defun profile-render (component args thunk)
  "Profile the rendering of a component"
  (if *profiling-enabled*
      (let ((start-time (get-internal-real-time))
            (parent *call-tree*)
            (current-node (list component)))
        
        ;; Update call tree
        (setf *call-tree* current-node)
        (when parent
          (push current-node (cdr parent)))
        
        ;; Execute the render function
        (multiple-value-prog1
            (funcall thunk)
          
          ;; Record timing data
          (let ((elapsed (- (get-internal-real-time) start-time)))
            (incf (gethash component *render-counts* 0))
            (push elapsed (gethash component *render-times* nil)))
          
          ;; Restore call tree context
          (setf *call-tree* parent)))
      
      ;; Profiling disabled, just call the function
      (funcall thunk)))

;; Wrap component rendering with profiling
(defmacro with-component-profiling ((component &rest args) &body body)
  "Execute body with component profiling"
  `(profile-render ,component (list ,@args)
                   (lambda () ,@body)))

;; Calculate statistics
(defun component-stats (component)
  "Get rendering statistics for a component"
  (let ((times (gethash component *render-times* nil))
        (count (gethash component *render-counts* 0)))
    (when times
      (let* ((total (reduce #'+ times))
             (average (if (> count 0) (/ total count) 0))
             (sorted (sort (copy-list times) #'<))
             (median (if (> count 0)
                         (nth (floor count 2) sorted)
                         0)))
        (list :component component
              :count count
              :total total
              :average average
              :median median
              :min (if times (apply #'min times) 0)
              :max (if times (apply #'max times) 0))))))

;; Show rendering statistics
(defun show-render-stats (&key (min-count 1) (sort-by :total) (limit nil))
  "Display component rendering statistics"
  (let* ((components nil)
         (all-stats nil))
    
    ;; Collect components
    (maphash (lambda (component count)
               (declare (ignore count))
               (push component components))
             *render-counts*)
    
    ;; Get stats for each component
    (setf all-stats
          (loop for component in components
                for stats = (component-stats component)
                when (and stats (>= (getf stats :count) min-count))
                collect stats))
    
    ;; Sort by the specified criteria
    (setf all-stats
          (sort all-stats #'> :key (lambda (stats) (getf stats sort-by))))
    
    ;; Apply limit if specified
    (when limit
      (setf all-stats (subseq all-stats 0 (min limit (length all-stats)))))
    
    ;; Print table header
    (format t "~&~%Component Rendering Statistics:~%")
    (format t "~&Component~40T Count~50T Total(ms)~60T Avg(ms)~70T Med(ms)~80T Max(ms)~%")
    (format t "~&-----------------------------------------------------------------------~%")
    
    ;; Print each row
    (dolist (stats all-stats)
      (let ((component (getf stats :component))
            (count (getf stats :count))
            (total (/ (getf stats :total) internal-time-units-per-second 1/1000))
            (avg (/ (getf stats :average) internal-time-units-per-second 1/1000))
            (median (/ (getf stats :median) internal-time-units-per-second 1/1000))
            (max (/ (getf stats :max) internal-time-units-per-second 1/1000)))
        (format t "~&~a~40T ~5d~50T ~8,2f~60T ~7,2f~70T ~7,2f~80T ~7,2f~%"
                component count total avg median max)))
    
    all-stats))

;; Find memoization candidates
(defun suggest-memoization-candidates (&key (min-count 5) (min-time 10))
  "Suggest components that would benefit from memoization"
  (let* ((components nil)
         (candidates nil)
         (min-time-units (* min-time internal-time-units-per-second 1/1000)))
    
    ;; Collect components
    (maphash (lambda (component count)
               (declare (ignore count))
               (push component components))
             *render-counts*)
    
    ;; Find candidates
    (dolist (component components)
      (let* ((stats (component-stats component))
             (count (getf stats :count))
             (avg (getf stats :average)))
        (when (and (>= count min-count)
                   (>= avg min-time-units))
          (push stats candidates))))
    
    ;; Sort by total render time
    (setf candidates
          (sort candidates #'> :key (lambda (stats) 
                                      (* (getf stats :count)
                                         (getf stats :average)))))
    
    ;; Print recommendations
    (format t "~&~%Memoization Candidates:~%")
    (format t "~&Component~40T Count~50T Total(ms)~60T Avg(ms)~70T Potential Savings(ms)~%")
    (format t "~&-------------------------------------------------------------------------------~%")
    
    (dolist (stats candidates)
      (let ((component (getf stats :component))
            (count (getf stats :count))
            (total (/ (getf stats :total) internal-time-units-per-second 1/1000))
            (avg (/ (getf stats :average) internal-time-units-per-second 1/1000))
            (potential (* (getf stats :average) (max 0 (1- (getf stats :count))))))
        (format t "~&~a~40T ~5d~50T ~8,2f~60T ~7,2f~70T ~10,2f~%"
                component count total avg 
                (/ potential internal-time-units-per-second 1/1000))))
    
    candidates))

;; Find expensive components
(defun find-expensive-components (&key (threshold 10) (limit 10))
  "Find components with render times exceeding threshold (in ms)"
  (let* ((components nil)
         (expensive nil)
         (threshold-units (* threshold internal-time-units-per-second 1/1000)))
    
    ;; Collect components
    (maphash (lambda (component count)
               (declare (ignore count))
               (push component components))
             *render-counts*)
    
    ;; Find expensive components
    (dolist (component components)
      (let* ((stats (component-stats component))
             (avg (getf stats :average)))
        (when (>= avg threshold-units)
          (push stats expensive))))
    
    ;; Sort by average render time
    (setf expensive
          (sort expensive #'> :key (lambda (stats) (getf stats :average))))
    
    ;; Apply limit
    (when limit
      (setf expensive (subseq expensive 0 (min limit (length expensive)))))
    
    ;; Print results
    (format t "~&~%Expensive Components (threshold: ~ams):~%" threshold)
    (format t "~&Component~40T Count~50T Avg(ms)~60T Max(ms)~%")
    (format t "~&-----------------------------------------------------~%")
    
    (dolist (stats expensive)
      (let ((component (getf stats :component))
            (count (getf stats :count))
            (avg (/ (getf stats :average) internal-time-units-per-second 1/1000))
            (max (/ (getf stats :max) internal-time-units-per-second 1/1000)))
        (format t "~&~a~40T ~5d~50T ~7,2f~60T ~7,2f~%"
                component count avg max)))
    
    expensive))

;; Main entry point for profiling components
(defmacro profile-components ((&key (clear t) (report t)) &body body)
  "Execute body with component profiling"
  `(progn
     (when ,clear
       (clear-profiling-data))
     (let ((*profiling-enabled* t)
           (*call-tree* nil))
       (unwind-protect
           (progn ,@body)
         (when ,report
           (show-render-stats))))))

;; Example usage:
#|
(profile-components ()
  (render-component :root {} 
    (render-component :header {}
      (render-component :title {} "Hello World"))
    (render-component :list {} 
      (loop for i from 1 to 100 do 
        (render-component :list-item {} (format nil "Item ~a" i))))))

(suggest-memoization-candidates)
(find-expensive-components :threshold 5)
|#
