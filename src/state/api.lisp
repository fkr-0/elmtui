(uiop:define-package :elmtui.state.api
  (:use :cl)
  (:documentation "Public API for the ElmTUI state management system.
This package exports the core functionalities for managing application state,
defining models and messages, and creating update functions, following Elm Architecture principles.")

  ;; Import symbols from their respective packages to be re-exported.

  ;; From elmtui.core.globals
  (:import-from :elmtui.core.globals
   :*app-state*)

  ;; From elmtui.statelib.state (struct definitions)
  (:import-from :elmtui.statelib.state
   :state-data :make-state-data :state-data-data
                :application-state :make-application-state :application-state-data
   :application-state-observers :application-state-lock
   :application-state-transaction-log :application-state-transaction-history
   :application-state-undone-history
                :get-state :set-state :state-ref)

  ;; From elmtui.state (which wraps/uses elmtui.statelib)
  ;; (:import-from :elmtui.state
  ;;  ;; Transactional wrapper
  ;;  ;; Update result structure (returned by update functions)
  ;;               :update-result :make-update-result :ur-patches :ur-commands
  ;;               ;; Path-based state manipulation (for patches)
  ;;               :merge-patch :merge-patches
  ;;               :get-path :set-path :remove-path
  ;;               ;; Component instance state management
  ;;  :get-component-by-path :store-component-at-path :remove-component-at-path)

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
   #:with-transaction
   #:update-result
   #:ur-patches
   #:ur-commands
   #:ur-add-command
   #:ur-has-command-p
   #:make-update-result
   #:start-transaction
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
;;; ===================================================================
;;; INTERFACE SECTION - Public API declarations
;;; ===================================================================
;; NOTE: The `defupdate` macro from `elmtui.state.update` currently uses
;; `ut.state.state:merge-state` which might need alignment with `elmtui.state:merge-patches`
;; if the `state-patch-plist` returned by the update body is a list of patch-forms
;; `((path value) ...)` rather than a direct plist to merge.
;; The current `elmtui.state:update-result` structure implies patches are `((path value) ...)` lists.
;; If `defupdate`'s first argument (`state-var`) is the `application-state` struct,
;; then `(setf (state-data-data state-var) (merge-patches (state-data-data state-var) patches))`
;; would be the way to apply these patches.
;; (defgeneric make-application-state ()
;;   (:documentation "Create a new application state instance."))
(defmacro with-transaction (&body body)
  (declare (ignore body))
  (error "with-transaction macro not yet implemented."))
(defstruct (update-result (:conc-name ur-))
  "Represents the result of an update operation, containing patches to apply to the state
and commands to be executed."
  (patches nil :type list)
  (commands nil :type list))

;; Define a generic function with proper FTYPE
(defgeneric ur-has-command-p (result command)
  (:documentation "Checks if the update result contains a specific command."))

;;; ===================================================================
;;; IMPLEMENTATION SECTION
;;; ===================================================================
(defmethod ur-has-command-p ((result update-result) command)
  "Checks if the update result contains a specific command."
  (declare (type update-result result)
           (type t command))
  (check-type result update-result)
  (member command (ur-commands result) :test #'equal)) ; Added :test for robustness

;; Define a generic function with proper FTYPE
;; (declaim (ftype (function (update-result t) (values update-result &rest t)) ur-add-command))
(defgeneric ur-add-command (result command)
  (:documentation "Adds a command to the update result."))
(defmethod ur-add-command ((result update-result) command)
  "Adds a command to the update result."
  (declare (type update-result result)
           (type t command))
  (check-type result update-result)
  (setf (ur-commands result) (cons command (ur-commands result)))
  result)

;; Note: The state-data and application-state structs are now defined in
;; elmtui.statelib.state and imported from there.
;; (declaim (ftype (function (application-state) state-data) application-state-data))
;; (declaim (ftype (function (state-data application-state) state-data) (setf application-state-data)))
;; (declaim (ftype (function (application-state) list) application-state-observers))
;; (declaim (ftype (function (list application-state) list) (setf application-state-observers)))
;; (declaim (ftype (function (application-state) sb-thread:mutex) application-state-lock))
;; (declaim (ftype (function (sb-thread:mutex application-state) sb-thread:mutex) (setf application-state-lock)))
;; (declaim (ftype (function (application-state) list) application-state-transaction-log))
;; (declaim (ftype (function (list application-state) list) (setf application-state-transaction-log)))
;; (declaim (ftype (function (application-state) list) application-state-transaction-history))
;; (declaim (ftype (function (list application-state) list) (setf application-state-transaction-history)))
;; (declaim (ftype (function (application-state) list) application-state-undone-history))
;; (declaim (ftype (function (list application-state) list) (setf application-state-undone-history)))

;; ;; Ensure defgeneric before FTYPE to prevent clobber for handle-async-command
;; (declaim (ftype (function (t application-state) *) handle-async-command))
(defgeneric handle-async-command (command app-state)
  (:method ((command t) (app-state application-state))
    (declare (ignore command app-state))
    (error "No method defined for handling async command"))
  (:documentation
   "Handle an asynchronous command `COMMAND` in the context of `APP-STATE`.
    This method is intended to process commands that may involve side effects or
    external interactions, such as network requests or UI updates."))

;; Ensure FTYPE and defgeneric match exactly
;; (declaim (ftype (function (application-state t &optional t) *) state-ref))
(defgeneric state-ref (app-state key &optional comp-id)
  (:method ((app-state application-state) key &optional comp-id)
    (declare (ignore key comp-id))
    (error "No implementation for state-ref"))
  (:documentation "Get the value of `KEY' from application state `APP-STATE'.
  Optionally provide COMP-ID to scope the key.

  Args:
    app-state: The application state to get the value from.
    key: The key to get the value for.
    comp-id: Optional component identifier to scope the key.

  Returns:
    The value of `KEY' in `APP-STATE', or nil if not found.")
  )

;; Ensure FTYPE and defgeneric match exactly
;; (declaim (ftype (function (t application-state t &optional t) *) (setf state-ref)))
(defgeneric (setf state-ref) (value app-state key &optional comp-id)
  (:method (value (app-state application-state) key &optional comp-id)
    (declare (ignore value key comp-id))
    (error "No implementation for (setf state-ref)"))
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

;; Ensure FTYPE and defgeneric match exactly
;; (declaim (ftype (function (application-state t t) *) set-state))
(defgeneric set-state (app-state key value)
  (:method ((app-state application-state) key value)
    (declare (ignore key value))
    (error "No implementation for set-state"))
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
;; Ensure FTYPE and defgeneric match exactly
;; (declaim (ftype (function (application-state t) *) get-state))
(defgeneric get-state (app-state key)
  (:method ((app-state application-state) key)
    (declare (ignore key))
    (error "No implementation for get-state"))
  (:documentation "Get the value of `KEY' from application state `APP-STATE'.

  Args:
    app-state: The application state to get the value from.
    key: The key to get the value for.

  Returns:
    The value of `KEY' in `APP-STATE', or nil if not found."))

;; Ensure FTYPE and defgeneric match exactly
;; Removed FTYPE declaration to avoid clobbering warning
(defgeneric undo-last-transaction (app-state)
  (:method ((app-state application-state))
    (error "No implementation for undo-last-transaction")))
