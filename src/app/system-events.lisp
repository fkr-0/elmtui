(uiop:define-package :elmtui.app.system-events
  (:use :cl :elmtui.state.msg)
  (:export #:SystemEvent
           #:make-appshutdown-systemevent
           #:make-terminalresized-systemevent
           #:make-cursorposition-systemevent))

(in-package :elmtui.app.system-events)
(defmsg SystemEvent (:docstring "Core system-level events.")
        AppShutdown
        (TerminalResized :width integer :height integer)
        (CursorPosition :col integer :row integer))
