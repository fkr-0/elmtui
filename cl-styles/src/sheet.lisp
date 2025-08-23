(in-package :cl-styles.sheet)

(defstruct stylesheet rules variables namespace compiled-index)

(defmacro defstylesheet (&body body)
  `(make-stylesheet :rules (list ,@body) :variables nil :namespace nil))

(defun compile-stylesheet (sheet)
  (setf (stylesheet-compiled-index sheet) nil)
  sheet)

(defun merge-stylesheets (&rest sheets)
  (make-stylesheet :rules (apply #'append (mapcar #'stylesheet-rules sheets))
                   :variables (apply #'append (mapcar #'stylesheet-variables sheets))
                   :namespace nil))

(defun with-variables (sheet vars)
  (make-stylesheet :rules (stylesheet-rules sheet)
                   :variables (append vars (stylesheet-variables sheet))
                   :namespace (stylesheet-namespace sheet)))

