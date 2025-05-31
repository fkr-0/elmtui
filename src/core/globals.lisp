(uiop:define-package :elmtui.core.globals
  (:use :cl)
  (:export #:*debug-mode*
           #:*config*
           #:*event-loop*
           #:*main-event-channel* ; Central channel for TEA messages
           #:*app-sender*          ; Function to send messages into the TEA loop (e.g., elmtui.core.loop:publish)
           #:*app-message-processor* ; Function to process a decoded app message (e.g., by platform/driver)
           #:*app-state*           ; The global application state object
           #:*subscribers*         ; For legacy/direct event subscriptions
           #:*current-backend*
           #:*current-program*
           #:*debug-layout-outlines*
           #:*focus-manager*
           #:*keymap-registry*
           #:*theme*
           #:*stylesheets*
           #:*widget-registry*))
(in-package :elmtui.core.globals)

(defvar *debug-mode* nil "Enable extensive debugging output if T.")
(defvar *config* (make-hash-table :test 'equal) "Global configuration settings.")

(defvar *event-loop* nil "The main event loop instance (legacy).")
(defvar *main-event-channel* nil "The main channel for TEA-style event/message processing.")
(defvar *app-sender* nil "Holds the function (e.g., #'elmtui.core.loop:publish) to send messages into the TEA loop.")
(defvar *app-message-processor* nil "Holds the function (message app-state) to process application messages.")
(defvar *app-state* nil "The current application state (ut.state:application-state instance).")
(defvar *subscribers* (make-hash-table :test 'equal) "Hash table for legacy event subscribers.")
(defvar *current-backend* nil "The active platform backend instance.")
(defvar *current-program* nil "The top-level program or application object.")
(defvar *focus-manager* nil "The active focus manager instance.")
(defvar *keymap-registry* nil "The global keymap registry.")
(defvar *theme* (make-hash-table :test 'equal) "Global theme settings.")

(defvar *debug-layout-outlines* nil
  "If T, enables layout outlines for debugging purposes.
   This is typically used to visualize widget boundaries and layout structures.")
