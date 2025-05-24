;;;===============================================================
;;; File: src/core/keymap/event-integration.lisp
;;; Keymap-Event Integration - Connect keymap system with event processing
;;;===============================================================
(uiop:define-package :elmtui.core.keymap.event-integration
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.core.keymap
   :key-event->normalized-key)
  (:import-from :elmtui.core.keymap.registry
   :lookup-key-binding
                :current-context
   :collect-all-defined-sequences)

  (:import-from :elmtui.core.keymap.sequence
   :make-sequence-state
                :update-sequence-state
   :reset-sequence-state
                :key-sequence-complete-p
   :key-sequence-partial-p
                :sequence->string)
  (:import-from :elmtui.core.event-async
   :*key-event-channel*
                :dispatch-event-async)
  (:import-from :elmtui.core.topic-registry #:subscribe) ; Added for setup-keyboard-event-handler
  ;; :normalize-event was removed as it's no longer used here.
  ;; Canonical event structs are expected.
  ;; (:import-from :elmtui.core.events :make-key-event) ; This import seems unused or incorrect, make-key-event-from-normalized uses elmtui.core.event-types
  (:export
   ;; Event processing
   #:process-keyboard-event
   #:setup-keyboard-event-handler
   
   ;; Key sequence tracking
   #:handle-key-event
   #:handle-key-binding
   #:*key-sequence-state*
   #:handle-key-sequence))

(in-package :elmtui.core.keymap.event-integration)
(defgeneric handle-key-binding (binding &key app-state)
  (:documentation "Execute the action associated with a key binding."))

(defgeneric handle-key-event (focus-manager key-event &key app-state ui-tree)
  (:documentation "Handle a key event with focus awareness."))
;;;-----------------------------------------------------------------------------
;;; Key Sequence State
;;;-----------------------------------------------------------------------------

(defvar *key-sequence-state* (make-sequence-state)
  "Global state for tracking partial key sequences.")

;;;-----------------------------------------------------------------------------
;;; Event Handlers
;;;-----------------------------------------------------------------------------

(defun process-keyboard-event (key-event focus-manager &key app-state handle-sequence)
  "Process a keyboard event through the keymap system.
   KEY-EVENT: The keyboard event to process.
   FOCUS-MANAGER: The current focus manager instance.
   APP-STATE: The current application state.
   HANDLE-SEQUENCE: Whether to handle key sequences (default: T).
   Returns T if the event was handled, NIL otherwise."
  (log-debug "Processing keyboard event: ~A" key-event)
  
  ;; Assuming key-event is already a canonical event struct from elmtui.core.event-types
  (let* ((normalized-key (key-event->normalized-key key-event)))
    (when normalized-key
      (if (and handle-sequence (not (null handle-sequence)))
          ;; Try to handle as part of a key sequence
          (handle-key-sequence normalized-key focus-manager :app-state app-state)
          
          ;; Handle as a single key
          ;; handle-key-event (from focus/manager) expects a canonical key-event struct
          (handle-key-event key-event focus-manager :app-state app-state)))))

(defun handle-key-sequence (normalized-key focus-manager &key app-state)
  "Handle a key as part of a potential key sequence.
   Returns T if handled, NIL otherwise."
  ;; Update the sequence state with the new key
  (let* ((new-sequence (update-sequence-state 
                        *key-sequence-state* 
                        normalized-key
                        :timeout-fn (lambda (seq)
                                      (log-debug "Key sequence timeout: ~A" 
                                                 (sequence->string seq))
                                      (reset-sequence-state *key-sequence-state*))))
         ;; Get all available sequences from all active keymaps
         (available-sequences (collect-all-defined-sequences (current-context))))
    
    ;; Check if it's a complete sequence in any active keymap
    (let ((binding (lookup-key-binding new-sequence)))
      (cond
        ;; Complete sequence found, execute it
        (binding
         (log-debug "Complete key sequence detected: ~A" (sequence->string new-sequence))
         (handle-key-binding binding :app-state app-state)
         (reset-sequence-state *key-sequence-state*)
         t)
        
        ;; Not a complete sequence, check if it might be partial
        ((key-sequence-partial-p new-sequence available-sequences)
         ;; Partial sequence, wait for more keys
         (log-debug "Partial key sequence detected: ~A" (sequence->string new-sequence))
         ;; We're handling this as part of a sequence
         t)
        
        ;; Not a valid sequence, reset and try handling as a single key
        (t
         (reset-sequence-state *key-sequence-state*)
         (handle-key-event 
          ;; Convert back to event structure for handle-key-event
          (make-key-event-from-normalized normalized-key)
          focus-manager
          :app-state app-state))))))

;;;-----------------------------------------------------------------------------
;;; Key Sequence Utilities
;;;-----------------------------------------------------------------------------

(defun make-key-event-from-normalized (normalized-key)
  "Create a canonical key-event from a normalized-key."
  ;; Creates a proper elmtui.core.events:key-event struct
  (elmtui.core.event-types:make-key-event
   :type :key-down
   :key (elmtui.core.keymap::normalized-key-key normalized-key)
   :modifiers (elmtui.core.keymap::normalized-key-modifiers normalized-key)
   :timestamp (get-internal-real-time)))

;;;-----------------------------------------------------------------------------
;;; Event Handler Setup
;;;-----------------------------------------------------------------------------

(defun setup-keyboard-event-handler (focus-manager app-state)
  "Set up a handler for keyboard events by subscribing to :key-event
   from elmtui.core.loop. The handler will call process-keyboard-event."
  (log-info "Setting up keyboard event handler for focus-manager: ~A and app-state: ~A" focus-manager app-state)
  
  (let ((handler-token
          (subscribe :key-event
                     (lambda (event)
                       (log-debug "Keymap event integration received event: ~S" event)
                       ;; Ensure it's a key-event struct before processing
                       (if (typep event 'elmtui.core.event-types:key-event)
                           (process-keyboard-event event focus-manager 
                                                   :app-state app-state 
                                                   :handle-sequence t) ; Default to handling sequences
                           (log-warn "Keymap event integration received non-key-event: ~S" event))))))
    (log-info "Keyboard event handler subscribed with token: ~A" handler-token)
    handler-token)) ; Return the subscription token so it can be unsubscribed if needed
