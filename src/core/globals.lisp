;;;===============================================================
;;; File: src/core/globals.lisp
;;; Global Variables and Definitions needed early
;;;===============================================================
(uiop:define-package :elmtui.core.globals
  (:use :cl)
  (:export :*app-sender* :*app-state*
           :*event-loop* :*subscribers*
           ))
(in-package :elmtui.core.globals)

(defvar *app-sender* (lambda (msg) (format t "[WARN] *app-sender* not defined. Dropping msg: ~S~%" msg))
  "Dynamically bound function to send messages back to the application's update loop.")

(defvar *app-state* nil
  "The global application state instance.")

(defvar *event-loop* nil "The main event loop instance.")
(defvar *subscribers* (make-hash-table :test 'equal) "Registered event subscribers.")
