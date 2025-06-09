
(uiop:define-package :elmtui.state.api
  (:use :cl)
  (:documentation "Public API for the ElmTUI state management system.
This package exports the core functionalities for managing application state,
defining models and messages, and creating update functions, following Elm Architecture principles.")

  ;; Import symbols from their respective packages to be re-exported.

  ;; From elmtui.core.globals
  (:import-from :elmtui.core.globals
   :*app-state*)

  ;; From elmtui.state (which wraps/uses elmtui.statelib)
                                        ; (:import-from :elmtui.state
  ;;  ;; Core state object
  ;;  :application-state :make-application-state
  ;;  ;; Transactional wrapper
  ;;  :with-transaction
  ;;  ;; Update result structure (returned by update functions)
  ;;               :update-result :make-update-result :ur-patches :ur-commands
  ;;               ;; Path-based state manipulation (for patches)
  ;;               :merge-patch :merge-patches
  ;;               :get-path :set-path :remove-path
  ;;               ;; Component instance state management
  ;;  :get-component-by-path :store-component-at-path :remove-component-at-path
  ;;  ;; General state access (use with caution, prefer model/component accessors)
  ;;               :get-state)

  ;; From elmtui.state.model (Elm-style model definition)
  ;; (:import-from :elmtui.state.model
  ;;  :defmodel
  ;;               :initialize-model-state ; For setting up models in the app state
  ;;  :get-slot             ; Accessor for model slots
  ;;               :with-model-access)
                                        ; Utility for safer model access

  ;; From elmtui.state.msg (Elm-style message definition)
  ;; (:import-from :elmtui.state.msg
  ;;  :defmsg
  ;;               :message-variant-p
  ;;               ;; Constructors for pre-defined AppMsg variants
  ;;               ;; These are examples; users defining new messages via defmsg
  ;;               ;; will have their constructors exported from elmtui.state.msg.
  ;;               ;; For a fully self-contained API, these would ideally be discoverable
  ;;               ;; or this API package would need to be updated with all new messages.
  ;;  :make-increment-counter-appmsg
  ;;               :make-decrement-counter-appmsg
  ;;  :make-set-counter-label-appmsg
  ;;               :make-activate-user-appmsg
  ;;  :make-deactivate-user-appmsg
  ;;               :make-request-focus-appmsg
  ;;  :make-focus-next-appmsg
  ;;               :make-focus-previous-appmsg
  ;;  :make-set-theme-appmsg
  ;;               :make-state-changed-appmsg
  ;;  :make-async-progress-update-appmsg
  ;;               :make-key-event-appmsg
  ;;  :make-mouse-event-appmsg
  ;;               :make-window-resize-appmsg
  ;;  :make-update-focusable-ids-appmsg)

  ;; From elmtui.state.update (Elm-style update function definition)
  ;; (:import-from :elmtui.state.update
  ;;  :defupdate
  ;;               :publish-to-topic       ; For command handling
  ;;  :dispatch-to-topic      ; For command handling
  ;;               :handle-async-command   ; For async command processing
  ;;  :malformed-update-result-error)
                                        ; Condition for update errors

  ;; Define the public interface by exporting the imported symbols.
  (:export
   ;; Global application state instance
   :*app-state*

   ;; Core State & Transactions
   :application-state :make-application-state
   :get-state ; General state accessor
   #:update-result
   #:ur-patches
   #:ur-commands
   #:ur-add-command
   #:ur-has-command-p
   #:make-update-result
   :start-transaction
   :with-transaction
   :state-ref
   :set-state
   :get-state

   ;; Path & Component State Management (primarily for use within update logic/patches)
   :merge-patch :merge-patches
   :get-path :set-path :remove-path
   :get-component-by-path :store-component-at-path :remove-component-at-path
   :handle-async-command
   ;; Elm-style Abstractions
   :undo-last-transaction
   ;; Models
   :application-state-transaction-history
   :defmodel
   :initialize-model-state
   :get-slot
   :with-model-access
   ;; Messages
   :defmsg
   :message-variant-p
   ;; Update Logic
   :defupdate
   :update-result :make-update-result :ur-patches :ur-commands

   ;; Predefined AppMsg Message Constructors (exported from elmtui.state.msg)
   :make-increment-counter-appmsg
   :make-decrement-counter-appmsg
   :make-set-counter-label-appmsg
   :make-activate-user-appmsg
   :make-deactivate-user-appmsg
   :make-request-focus-appmsg
   :make-focus-next-appmsg
   :make-focus-previous-appmsg
   :make-set-theme-appmsg
   :make-state-changed-appmsg
   :make-async-progress-update-appmsg
   :make-key-event-appmsg
   :make-mouse-event-appmsg
   :make-window-resize-appmsg
   :make-update-focusable-ids-appmsg
   :state-data
   :application-state
   #:application-state-data
   #:state-data-data
   #:application-state #:state-data
   :application-state-undone-history
   :application-state-transaction-log
   :application-state-observers
   :application-state-lock
   ;; Application Loop and Command Handling
   ;; Advanced Update/Command Handling
   :publish-to-topic
   :dispatch-to-topic
   :handle-async-command
   :malformed-update-result-error))

(in-package :elmtui.state.api)
;; NOTE: The `defupdate` macro from `elmtui.state.update` currently uses
;; `ut.state.state:merge-state` which might need alignment with `elmtui.state:merge-patches`
;; if the `state-patch-plist` returned by the update body is a list of patch-forms
;; `((path value) ...)` rather than a direct plist to merge.
;; The current `elmtui.state:update-result` structure implies patches are `((path value) ...)` lists.
;; If `defupdate`'s first argument (`state-var`) is the `application-state` struct,
;; then `(setf (state-data-data state-var) (merge-patches (state-data-data state-var) patches))`
;; would be the way to apply these patches.

(defstruct (update-result (:conc-name ur-))
  "Represents the result of an update operation, containing patches to apply to the state
and commands to be executed."
  (patches nil :type list)
  (commands nil :type list))

(defmethod ur-has-command-p ((result update-result) command)
  "Checks if the update result contains a specific command."
  (member command (ur-commands result)))

(defmethod ur-add-command ((result update-result) command)
  "Adds a command to the update result."
  (setf (ur-commands result) (cons command (ur-commands result)))
  result)

;;;--------------------------------------------------------------
(defstruct state-data
  "A struct to hold the application state data.
  The data is stored in a hash-table."
  (data (make-hash-table :test 'equal) :type hash-table))

(defstruct application-state
  "A struct to hold the application state.
  The application state holds the state data, observers, a lock, a transaction log,
  a transaction history (for undo), and an undone history (for redo)."
  (data (make-state-data) :type state-data)
  (observers (list) :type list)
  (lock (sb-thread:make-mutex) :type sb-thread:mutex)
  (transaction-log (list) :type list) ; Temporary log for current transaction
  (transaction-history (list) :type list) ; Stack of committed transactions (undo stack)
  (undone-history (list) :type list)) ; Stack of undone transactions (redo stack)
(defgeneric handle-async-command (command app-state)
  (:documentation
   "Handle an asynchronous command `COMMAND` in the context of `APP-STATE`.
    This method is intended to process commands that may involve side effects or
    external interactions, such as network requests or UI updates."))
(defgeneric state-ref (app-state key &optional comp-id)
  (:documentation "Get the value of `KEY' from application state `APP-STATE'.
  Optionally provide COMP-ID to scope the key.

  Args:
    app-state: The application state to get the value from.
    key: The key to get the value for.
    comp-id: Optional component identifier to scope the key.

  Returns:
    The value of `KEY' in `APP-STATE', or nil if not found.")
  )

(defgeneric (setf state-ref) (value app-state key &optional comp-id)
  (:documentation
   "Set the value of `KEY' in application state `APP-STATE' to `VALUE'.
    Optionally provide COMP-ID to scope the key.

    NOTE: This method bypasses transaction logging and locking. It is generally
    unsafe for direct use. Use the `set-state!` macro provided within `defupdate`
    for safe, transactional updates. This method exists primarily for internal
    use or specific scenarios where transactionality is handled externally.

  Args:
    value: The value to set.
    app-state: The application state to set the value on.
    key: The key to set.
    comp-id: Optional component identifier to scope the key.

  Returns:
    The set value."))

(defgeneric set-state (app-state key value)
  (:documentation "Set the value of `KEY' in application state `APP-STATE' to `VALUE'.
  NOTE: This method bypasses transaction logging. Use within transaction logic
  (like apply/revert-transaction) or use the `set-state!` macro inside `defupdate`.

  Args:
    app-state: The application state to set the value on.
    key: The key to set.
    value: The value to set.

  Returns:
    nil")
  )
(defgeneric get-state (app-state key)
  (:documentation "Get the value of `KEY' from application state `APP-STATE'.

  Args:
    app-state: The application state to get the value from.
    key: The key to get the value for.

  Returns:
    The value of `KEY' in `APP-STATE', or nil if not found."
                  ))

(defgeneric undo-last-transaction (app-state))
