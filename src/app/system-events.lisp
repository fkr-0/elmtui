(uiop:define-package :elmtui.app.system-events
  (:use :cl :elmtui.state.msg)
  (:export #:SystemEvent
           #:make-appshutdown-system-event
           #:make-terminalresized-system-event))

(in-package :elmtui.app.system-events)

(defmsg SystemEvent (:docstring "Core system-level events.")
        AppShutdown
        (TerminalResized :width integer :height integer))
