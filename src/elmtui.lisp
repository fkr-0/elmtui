;;;; elmtui.lisp: the root ELMTUI package, a curated facade of the
;;;; application API.
;;;;
;;;; Every name exported here is the framework's own symbol (imported, not
;;;; re-interned), so ELMTUI:DEFAPPLICATION is ELMTUI.APP:DEFAPPLICATION.
;;;; Until 0.4.0 this package used UIOP :REEXPORT over eight packages, which
;;;; only exports by name: it exported 127 fresh, unbound symbols. Extension
;;;; and backend APIs live in their own packages (ELMTUI.UI.*, ELMTUI.PLATFORM.*,
;;;; ELMTUI.STATE.API, ...); see docs/architecture/api-support-levels.md.

(uiop:define-package :elmtui
  (:use :cl)
  (:documentation "The ElmTUI application API.

Define an application with DEFAPPLICATION (patch-based updates) or DEFTEA-APP
(direct model replacement). Update functions read state with STATE-REF,
return MAKE-UPDATE-RESULT, and recognise input with KEY-PRESSED-P and
QUIT-REQUESTED-P or the KEY-EVENT accessors.")
  (:import-from :elmtui.app
                #:defapplication #:key-pressed-p #:quit-requested-p)
  (:import-from :elmtui.app.tea-core #:deftea-app)
  (:import-from :elmtui.state.api #:make-update-result #:state-ref
                #:patch #:patch* #:quit-result)
  (:import-from :elmtui.core.event-types
                #:key-event #:key-event-p #:key-event-key #:key-event-char
                #:key-event-modifiers #:key-event-parts)
  (:import-from :elmtui.core.async #:cmd-async)
  (:import-from :elmtui.style.presets #:dark-theme #:light-theme)
  (:export
   ;; Defining applications
   #:defapplication #:deftea-app
   ;; Update functions
   #:make-update-result #:state-ref
   #:patch #:patch* #:quit-result
   #:key-pressed-p #:quit-requested-p
   #:key-event #:key-event-p #:key-event-key #:key-event-char
   #:key-event-modifiers #:key-event-parts
   ;; Async commands
   #:cmd-async
   ;; Style presets
   #:dark-theme #:light-theme))
