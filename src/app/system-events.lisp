(uiop:define-package :elmtui.app.system-events
  (:use :cl :elmtui.tea-state.msg)
  (:export #:SystemEvent
           #:make-appshutdown-systemevent
           #:make-terminalresized-systemevent
           #:make-cursorpositionchanged-systemevent))

(in-package :elmtui.app.system-events)
(defmsg SystemEvent (:docstring "Core system-level events.")
        AppShutdown
        (TerminalResized :width integer :height integer)
        (CursorPositionChanged :col integer :row integer))
