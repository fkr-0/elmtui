;;; src/events/packages.lisp
(uiop:define-package :cl-events.protocols
  (:use :cl :alexandria)
  (:export
   ;; Object→topic/key extraction
   #:event-topic #:event-payload #:event-timestamp
   ;; Event→Message translation
   #:translate-event->messages
   ;; Optional message semantics
   #:message-state #:message-priority
   #:broadcast-p #:capture-p #:bubble-p #:stop-propagation
   ;; Update + View contracts (app supplies these)
   #:app-update #:app-view
   ;; Render side-effect hook
   #:perform-render
   ;; Command execution (effects)
   #:perform-command))

(uiop:define-package :cl-events.types
  (:use :cl :alexandria)
  (:import-from :cl-events.protocols #:stop-propagation)
  (:export
   ;; Event
   #:event #:make-event #:event-type #:event-data #:event-when
   ;; Message (pure signal consumed by app update)
   #:message #:make-message #:message-type #:message-data
   ;; Command (effectful instruction emitted by update)
   #:command #:make-command #:command-type #:command-args
   ;; UI/Input Events for TUI integration
   #:ui-event #:make-ui-event #:ui-event-p
   #:ui-event-type #:ui-event-target #:ui-event-consumed-p
   #:ui-event-timestamp #:ui-event-original-event
   #:stop-propagation
   #:key-event #:make-key-event #:key-event-p
   #:key-event-type #:key-event-key #:key-event-code
   #:key-event-char #:key-event-modifiers
   #:key-event-timestamp #:key-event-consumed-p
   #:mouse-event #:make-mouse-event #:mouse-event-p
   #:mouse-event-type #:mouse-event-x #:mouse-event-y
   #:mouse-event-button #:mouse-event-modifiers
   #:mouse-event-click-count #:mouse-event-delta-x
   #:mouse-event-delta-y #:mouse-event-timestamp
   #:mouse-event-consumed-p
   #:focus-event #:make-focus-event #:focus-event-p
   #:focus-event-type #:focus-event-target
   #:focus-event-source #:focus-event-timestamp
   #:focus-event-consumed-p
   ;; Utility functions
   #:consume-event #:stop-propagation* #:prevent-default #:has-modifier-p))

(uiop:define-package :cl-events.system-events
  (:use :cl)
  (:export
   #:make-app-shutdown-event
   #:make-terminal-resized-event
   #:make-cursor-position-event))

(uiop:define-package :cl-events.channel
  (:use :cl :alexandria :bordeaux-threads)
  (:export
   #:channel #:make-channel #:chan-put #:chan-take #:chan-close #:channel-length
   #:try-put
   #:select #:no-wait #:channel-put! #:channel-take! #:-> #:<-
   #:filtered-channel #:make-filtered-channel
   #:channel-add-filter #:channel-remove-filter
   #:mailbox #:make-mailbox #:mb-put #:mb-take #:mb-empty-p))

(uiop:define-package :cl-events.bus
  (:use :cl :alexandria :cl-events.channel :cl-events.protocols :cl-events.types)
  (:export
   #:event-bus #:make-event-bus #:publish-event #:subscribe #:unsubscribe
   #:with-subscription))

(uiop:define-package :cl-events.dispatcher
  (:use :cl :alexandria :cl-events.protocols :cl-events.types :cl-events.bus)
  (:export
   #:dispatch-event #:dispatch-message-batch #:execute-commands))

(uiop:define-package :cl-events.async
  (:use :cl :alexandria :bordeaux-threads :cl-events.types :cl-events.bus)
  (:export
   #:spawn-task #:future #:await #:cancel
   #:promise #:make-promise #:resolve-promise #:reject-promise
   #:promise-value #:promise-error #:promise-resolved #:promise-cancelled
   #:promise-cancel #:promise-cancelled-p
   #:async-task #:new-task #:async-exec #:async-run
   #:async-task-finished-p #:async-task-result #:async-task-error
   #:async-task-status #:async-task-promise
   #:chain #:all #:race
   #:schedule-after #:schedule-every))

(uiop:define-package :cl-events.messaging
  (:use :cl :alexandria :cl-events.protocols :cl-events.types)
  (:export
   #:message-envelope #:make-message-envelope
   #:message-envelope-message #:message-envelope-phase
   #:message-envelope-stop-p #:message-envelope-broadcast-p
   #:message-envelope-capture-p #:message-envelope-bubble-p
   #:message-phases #:message->envelope
   #:expand-message #:envelope->messages))

(uiop:define-package :cl-events.loop
  (:use :cl :alexandria :cl-events.bus :cl-events.dispatcher :cl-events.protocols
        :cl-events.types :cl-events.channel :cl-events.async)
  (:export
   #:+default-poll-timeout-seconds+
   #:poll-runtime-event
   #:runtime-consume-once
   #:run-consumer-loop-shell
   #:select-primary-channel
   #:resolve-runtime-error-action
   #:default-runtime-error-policy
   #:make-join-deadline
   #:deadline-expired-p
   #:run-app-loop #:stop-app-loop
   #:app-context #:make-app-context))

(uiop:define-package :cl-events.api
  (:use :cl
        :cl-events.protocols :cl-events.types :cl-events.channel
        :cl-events.bus :cl-events.dispatcher :cl-events.async
        :cl-events.system-events
        :cl-events.messaging :cl-events.loop)
  (:reexport :cl-events.protocols :cl-events.types :cl-events.channel
             :cl-events.bus :cl-events.dispatcher :cl-events.async
             :cl-events.system-events
             :cl-events.messaging :cl-events.loop))
