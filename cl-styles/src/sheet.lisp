(in-package :cl-styles.sheet)

(defclass stylesheet ()
  ((rules :initarg :rules :accessor stylesheet-rules)
   (variables :initarg :variables :accessor stylesheet-variables)
   (namespace :initarg :namespace :accessor stylesheet-namespace)))

(defstruct compiled-stylesheet
  (ruleset nil :type list)
  (variables nil :type list))

(defclass style-engine ()
  ((stylesheet :initarg :stylesheet :accessor stylesheet)
   (patches :initform nil :accessor patches)
   (dirty :initform t :accessor dirty)))

(defun make-stylesheet (&key rules variables namespace)
  (make-instance 'stylesheet :rules rules :variables variables :namespace namespace))

(defmacro defstylesheet (&body body)
  `(make-stylesheet :rules (list ,@body)))

