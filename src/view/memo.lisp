(defpackage :elmtui.view.memo
  (:use :cl)
  (:export :memo
    :defmemo
    :with-memoization
    :clear-memoization-cache
    :memoize
    :memoize-component
    :define-memoized-component
    :with-memo-stats))

(in-package :elmtui.view.memo)

;; Cache implementation
(defvar *memo-cache* (make-hash-table :test #'equal)
  "Cache for memoized function results")

(defvar *cache-stats* (make-hash-table :test #'eq)
  "Statistics for cache usage")

(defvar *memoization-enabled* t
  "Flag to enable/disable memoization")

;; Statistics tracking
;; Define a structure to hold cache statistics
;; Fields:
;; - hits :: integer: number of cache hits
;; - misses :: integer: number of cache misses
;; - function :: function: the memoized function
(defstruct cache-stats
  (hits 0 :type integer)
  (misses 0 :type integer)
  (function nil))

(defun memo (fn &key (key #'identity) (test #'equal))
  "Create a memoized version of a function, with customizable keying and cache behavior.

Arguments:
+ ~fn~ :: function
  The function to be memoized. Should accept any number of arguments.
+ ~:key~ :: function (default: ~identity~)
  Function applied to the argument list to produce a cache key. Should accept a list of arguments and return a hashable key.
+ ~:test~ :: function (default: ~equal~)
  Function used to compare cache keys in the hash table.

Return:
+ Returns a function that behaves like ~fn~, but caches results based on the computed key.

Side-effects:
+ Creates a hash table for caching results (local to the returned function).
+ Updates global ~*cache-stats*~ hash table with statistics for ~fn~.
+ Increments cache hit/miss counters in the stats object.
+ Reads global variable ~*memoization-enabled*~ to determine whether to use memoization.

Globals:
+ ~*cache-stats*~ :: hash table mapping functions to their statistics objects.
+ ~*memoization-enabled*~ :: boolean flag controlling whether memoization is enabled.

Behavior:
1. When called, the returned function checks ~*memoization-enabled*~.
2. If enabled, it computes a cache key using ~key~ and looks up the result in the cache.
3. If found, returns the cached value and increments the hit counter.
4. If not found, computes the result, stores it in the cache, increments the miss counter, and returns the result.
5. If memoization is disabled, simply calls ~fn~ with the arguments.

Examples:

;; Example: Memoizing a recursive Fibonacci function
(defun fib (n)
  (if (< n 2) n
      (+ (fib (- n 1)) (fib (- n 2)))))

(setq *memoization-enabled* t)
(setq *cache-stats* (make-hash-table))
(defun make-cache-stats (&key function)
  (list :function function :hits 0 :misses 0))
(defun cache-stats-hits (stats) (getf stats :hits))
(defun cache-stats-misses (stats) (getf stats :misses))

(let ((memo-fib (memo #'fib :key #'identity :test #'eql)))
  (funcall memo-fib 10)) ; => 55

;; Check statistics
(gethash #'fib *cache-stats*) ; => (:function #'fib :hits ... :misses ...)

;; Example: Custom key function for argument normalization
(defun slow-add (a b)
  (sleep 1)
  (+ a b))

(let ((memo-add (memo #'slow-add :key (lambda (args) (sort args #'<)))))
  (funcall memo-add 2 3) ; computes and caches
  (funcall memo-add 3 2)) ; returns cached result (same key)
"
  (let ((cache (make-hash-table :test test))
         (stats (make-cache-stats :function fn)))
    (setf (gethash fn *cache-stats*) stats)
    (lambda (&rest args)
      (if *memoization-enabled*
        (let ((k (funcall key args)))
          (multiple-value-bind (val found) (gethash k cache)
            (if found
              (progn
                (incf (cache-stats-hits stats))
                val)
              (progn
                (incf (cache-stats-misses stats))
                (let ((result (apply fn args)))
                  (setf (gethash k cache) result)
                  result)))))
        (apply fn args)))))

;; Helper macro for defining memoized functions
(defmacro defmemo (name args &body body)
  "Define a memoized function"
  `(progn
     (defun ,name ,args ,@body)
     (setf (fdefinition ',name)
       (memo (fdefinition ',name)))
     ',name))

;; Environment for memoization
(defmacro with-memoization (&body body)
  "Execute BODY with memoization enabled"
  `(let ((*memoization-enabled* t))
     ,@body))

(defmacro without-memoization (&body body)
  "Execute BODY with memoization disabled"
  `(let ((*memoization-enabled* nil))
     ,@body))

;; Cache management
(defun clear-memoization-cache (&optional function)
  "Clear the entire memoization cache or just for a specific function"
  (if function
    (remhash function *memo-cache*)
    (clrhash *memo-cache*)))

;; Component memoization
(defun memoize (component props &key (key #'identity) (test #'equal))
  "Memoize a component with given props"
  (declare (ignorable test))
  (when *memoization-enabled*
    (let ((cache-key (funcall key (cons component props))))
      (multiple-value-bind (cached-result found) (gethash cache-key *memo-cache*)
        (when found
          (return-from memoize cached-result))))

    ;; Not found, compute and cache
    (let ((result (funcall component props)))
      (setf (gethash (funcall key (cons component props)) *memo-cache*) result)
      result)))

;; Higher order component for memoization
(defun memoize-component (component &key (key #'identity) (test #'equal))
  "Create a memoized version of a component"
  (let ((memo-fn (memo component :key key :test test)))
    (lambda (props &rest args)
      (apply memo-fn props args))))

;; Define a memoized component
(defmacro define-memoized-component (name args &body body)
  "Define a memoized component"
  `(progn
     (defun ,name ,args ,@body)
     (setf (fdefinition ',name)
       (memoize-component (fdefinition ',name)))
     ',name))

;; Get memoization statistics
(defun get-memo-stats (&optional function)
  "Get memoization statistics for all functions or a specific one"
  (if function
    (gethash function *cache-stats*)
    (let ((all-stats nil))
      (maphash (lambda (fn stats)
                 (push (cons fn stats) all-stats))
        *cache-stats*)
      (sort all-stats #'> :key (lambda (entry)
                                 (+ (cache-stats-hits (cdr entry))
                                   (cache-stats-misses (cdr entry))))))))

;; Display memoization statistics
(defun print-memo-stats (&optional (stream *standard-output*))
  "Print memoization statistics"
  (format stream "~&Memoization Statistics:~%")
  (format stream "~&Function~30T Hits~40T Misses~50T Hit Rate~%")
  (format stream "~&-------------------------------------------------------------~%")
  (dolist (entry (get-memo-stats))
    (let* ((fn (car entry))
            (stats (cdr entry))
            (hits (cache-stats-hits stats))
            (misses (cache-stats-misses stats))
            (total (+ hits misses))
            (hit-rate (if (zerop total) 0 (* 100.0 (/ hits total)))))
      (format stream "~&~a~30T ~5d~40T ~5d~50T ~5,2f%~%"
        (typecase fn
          (symbol (symbol-name fn))
          (t "#<Function>"))
        hits misses hit-rate))))

;; Macro to collect and display memo stats
(defmacro with-memo-stats ((&key (report t)) &body body)
  "Execute BODY and optionally report memoization statistics"
  `(progn
     (clear-memoization-cache)
     (maphash (lambda (fn stats)
                (setf (cache-stats-hits stats) 0
                  (cache-stats-misses stats) 0))
       *cache-stats*)
     (let ((result (progn ,@body)))
       (when ,report
         (print-memo-stats))
       result)))

;; Example usage:
#|
(defmemo fibonacci (n)
(if (<= n 1)
n
(+ (fibonacci (- n 1))
(fibonacci (- n 2)))))

(with-memo-stats ()
(fibonacci 20))

(define-memoized-component expensive-component (data)
(sleep 0.1) ;; Simulate expensive rendering
(format nil "Processed ~a" data))
|#
