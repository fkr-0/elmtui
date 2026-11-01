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
  "Cache for the legacy MEMOIZE component+props helper.")

(defvar *memo-function-caches*
  #+sbcl (make-hash-table :test #'eq :weakness :key)
  #-sbcl (make-hash-table :test #'eq)
  "Weak wrapper -> (original function . cache). Originals never own cache lists.
Both the original function and its memoizing wrapper may invalidate them.
Discarding the last wrapper releases its cached arguments and results on SBCL.")

(defvar *cache-stats* #+sbcl (make-hash-table :test #'eq :weakness :key)
                     #-sbcl (make-hash-table :test #'eq)
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
  "Return a memoizing wrapper around FN, caching its primary return value.

:KEY receives a list of FN's arguments and defaults to IDENTITY; :TEST is
the hash-table equality predicate and defaults to EQUAL. Each wrapper has its
own cache. Repeated argument keys return the cached primary value, including
NIL; multiple return values are not preserved. With memoization disabled,
FN executes normally and no entry is cached.

CLEAR-MEMOIZATION-CACHE accepts either FN or the returned wrapper, or no
argument to invalidate every live wrapper. Hit/miss statistics for FN remain
available separately."
  (let* ((cache (make-hash-table :test test))
         (stats (make-cache-stats :function fn))
         (wrapper
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
    (setf (gethash wrapper *memo-function-caches*) (cons fn cache))
    (setf (gethash fn *cache-stats*) stats)
    wrapper))

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
  "Invalidate memoized results. With FUNCTION, clear that original function's
or wrapper's MEMO caches; without FUNCTION, clear all MEMO and MEMOIZE caches.
Existing wrappers stay callable and their hit/miss statistics are retained."
  (if function
      (progn
        (maphash (lambda (wrapper entry)
                   (when (or (eq function wrapper) (eq function (car entry)))
                     (clrhash (cdr entry))))
                 *memo-function-caches*)
        ;; Default MEMOIZE keys are (FUNCTION . PROPS). A custom :KEY may
        ;; deliberately erase that identity, so only recognizable entries
        ;; can be invalidated selectively.
        (maphash (lambda (key value)
                   (declare (ignore value))
                   (when (and (consp key) (eq (car key) function))
                     (remhash key *memo-cache*)))
                 *memo-cache*))
      (progn
        (clrhash *memo-cache*)
        (maphash (lambda (wrapper entry)
                   (declare (ignore wrapper))
                   (clrhash (cdr entry)))
                 *memo-function-caches*)))
  t)

;; Component memoization
(defun memoize (component props &key (key #'identity) (test #'equal))
  "Memoize a one-argument component with PROPS in the legacy shared cache.
When memoization is disabled, invoke COMPONENT without storing the result.
The legacy :TEST keyword is accepted but the shared cache uses EQUAL."
  (declare (ignorable test))
  (if (not *memoization-enabled*)
      (funcall component props)
      (let ((cache-key (funcall key (cons component props))))
        (multiple-value-bind (cached-result found)
            (gethash cache-key *memo-cache*)
          (when found
            (return-from memoize cached-result)))
        (let ((result (funcall component props)))
          (setf (gethash cache-key *memo-cache*) result)
          result))))

;; Higher order component for memoization
(defun memoize-component (component &key (key #'identity) (test #'equal))
  "Wrap COMPONENT while retaining its first PROPS argument as one argument.
Additional arguments are forwarded unchanged. Cache invalidation accepts
the original function or the returned wrapper."
  (let* ((memo-fn (memo component :key key :test test))
         (adapter (lambda (props &rest args)
                    (apply memo-fn (cons props args)))))
    (setf (gethash adapter *memo-function-caches*)
          (gethash memo-fn *memo-function-caches*))
    adapter))

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
