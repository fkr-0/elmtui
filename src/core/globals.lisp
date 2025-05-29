;;;===============================================================
;;; File: src/core/globals.lisp
;;; Global Variables and Definitions needed early
;;;===============================================================
(uiop:define-package :elmtui.core.globals
  (:use :cl)
  (:export :*app-sender* :*app-state*
           :*event-loop* :*subscribers*
           :*debug-layout-outlines* ; Export the new debug flag
           :*main-event-channel*    ; Export the main event channel
           ))
(in-package :elmtui.core.globals)

(defvar *app-sender* (lambda (msg) (format t "[WARN] *app-sender* not defined. Dropping msg: ~S~%" msg))
  "Dynamically bound function to send messages back to the application's update loop.")

(defvar *app-state* nil
  "The global application state instance.")

(defvar *event-loop* nil "The main event loop instance.")
(defvar *subscribers* (make-hash-table :test 'equal) "Registered event subscribers.")

(defvar *debug-layout-outlines* nil
  "When T, enables rendering of layout box outlines (margin, border, padding, content) for debugging.")

(defvar *main-event-channel* nil
  "Central event channel for all TEA-cycle-triggering events and messages.
   This is an lparallel:channel that serves as a single, serialized entry point
   for all events that should trigger the update function of the application.
   All events must be submitted to this channel to ensure proper TEA compliance
   with sequential updates to application state.")
