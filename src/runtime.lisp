;;;===============================================================
;;; File: src/runtime.lisp
;;; Runtime Assembly & Entrypoint
(uiop:define-package :elmtui.runtime
  (:use :cl
        :elmtui.state.model
        :elmtui.state.msg
        :elmtui.state.update
        :elmtui.view.core
        :elmtui.core.events
        :elmtui.core.loop
        :elmtui.core.async
        :elmtui.platform.driver)
  (:export :def-elm-app
           :run-app))
(in-package :elmtui.runtime)

(defmacro def-elm-app (name &key model msg update view)
  "Generate entry-point: defines *model*, wires Msg channel, loop, and run-platform.
   Contract: generates
     1. *model* var initialized via defmodel defaults
     2. (start-reader) & (start-loop) & subscription to render on every Msg
     3. (run-platform) entrypoint"
  `(progn
     ;; stub: define *model* var, initialize *msg-chan*
     ;; stub: call run-platform
     ))

(defun run-app ()
  "Start the Elm TUI application.
   Contract: blocks until (quit) Msg received."
  ;; stub: invoke run-platform and block until quit
  )
