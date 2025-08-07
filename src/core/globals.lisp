(uiop:define-package :elmtui.core.globals
  (:use :cl)
  (:nicknames :et.glob)
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
           #:*applications*
           #:*stylesheets*
           #:*dsl-type-to-component-class*
           #:*message-schemas*
           #:*widget-registry*))
(in-package :elmtui.core.globals)
(eval-when (:compile-toplevel :load-toplevel :execute)

  (defvar *message-schemas* (make-hash-table :test 'eq)
    "Global registry for message types and their variants defined by defmsg.")

  (defvar *debug-mode* nil "Enable extensive debugging output if T.")
  (declaim (type boolean *debug-mode*))

  (defvar *config* (make-hash-table :test 'equal) "Global configuration settings.")
  (declaim (type hash-table *config*))

  (defvar *event-loop* nil "The main event loop instance (legacy).")
  ;; Add specific type for *event-loop* if known, e.g., (type (or null some-event-loop-class) *event-loop*)

  (defvar *main-event-channel* nil "The main channel for TEA-style event/message processing.")
  ;; Add specific type for *main-event-channel* if known, e.g., (type (or null some-channel-class) *main-event-channel*)

  (defvar *app-sender* nil "Holds the function (e.g., #'elmtui.core.loop:publish) to send messages into the TEA loop.")
  (declaim (type (or null function) *app-sender*))

  (defvar *app-message-processor* nil "Holds the function (message app-state) to process application messages.")
  (declaim (type (or null function) *app-message-processor*))

  (defvar *app-state* nil "The current application state (ut.state:application-state instance).")
  ;; Add specific type for *app-state* if known, e.g., (type (or null ut.state:application-state) *app-state*)

  (defvar *subscribers* (make-hash-table :test 'equal) "Hash table for legacy event subscribers.")
  (declaim (type hash-table *subscribers*))

  (defvar *current-backend* nil "The active platform backend instance.")
  ;; Add specific type for *current-backend* if known, e.g., (type (or null some-backend-class) *current-backend*)

  (defvar *current-program* nil "The top-level program or application object.")
  ;; Add specific type for *current-program* if known, e.g., (type (or null some-program-class) *current-program*)

  (defvar *focus-manager* nil "The active focus manager instance.")
  ;; Add specific type for *focus-manager* if known, e.g., (type (or null focus:manager) *focus-manager*)

  (defvar *keymap-registry* nil "The global keymap registry.")
  ;; Add specific type for *keymap-registry* if known, e.g., (type (or null keymap:registry) *keymap-registry*)

  (defvar *theme* (make-hash-table :test 'equal) "Global theme settings.")


  (declaim (type hash-table *theme*))

  (defvar *applications* (make-hash-table :test 'equal)
    "Hash table of registered applications, keyed by their names.")
  (declaim (type hash-table *applications*))

  (defvar *stylesheets* (make-hash-table :test 'equal))
  (declaim (type hash-table *stylesheets*))

  (defvar *widget-registry* (make-hash-table :test 'equal)
    "Registry of all widget classes, keyed by their DSL type keywords.
   This is used to map DSL types to their corresponding component classes.")
  (declaim (type hash-table *widget-registry*))

  (defvar *dsl-type-to-component-class*
    (make-hash-table :test 'equal)
    "Maps DSL type keywords to their corresponding component class symbols.
     This is used to resolve DSL types to actual component classes when rendering views.")
  (declaim (type hash-table *dsl-type-to-component-class*))

  (defvar *debug-layout-outlines* nil
    "If T, enables layout outlines for debugging purposes.
   This is typically used to visualize widget boundaries and layout structures.")
  (declaim (type boolean *debug-layout-outlines*))

  )
