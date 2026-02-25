(uiop:define-package :elmtui.core.system-events
  (:use :cl)
  (:import-from :cl-events.system-events
                #:make-app-shutdown-event
                #:make-terminal-resized-event
                #:make-cursor-position-event)
  (:export #:SystemEvent
           #:make-appshutdown-systemevent
           #:make-terminalresized-systemevent
           #:make-cursorposition-systemevent))

(in-package :elmtui.core.system-events)

(deftype SystemEvent ()
  "Compatibility marker for system event payloads."
  'list)

(defun make-appshutdown-systemevent ()
  (make-app-shutdown-event))

(defun make-terminalresized-systemevent (&key width height)
  (make-terminal-resized-event :width width :height height))

(defun make-cursorposition-systemevent (&key col row)
  (make-cursor-position-event :col col :row row))
