;;;===============================================================
;;; File: src/core/keymap-system.lisp
;;; Keymap System - Main entry point for the enhanced keymap and focus integration
;;;===============================================================
(uiop:define-package :elmtui.core.keymap-system
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.core.keymap
   :keymap
                :normalized-key)
  (:import-from :elmtui.core.keymap.registry
   :register-keymap
                :*global-keymap-context*
   :activate-context)
  (:import-from :elmtui.core.keymap.defaults
   :register-standard-keymaps
   ;; Import default keymap variables to re-export them
   #:*global-navigation-keymap*
   #:*dialog-keymap*
   #:*form-keymap*
   #:*editor-keymap*
   #:*list-navigation-keymap*)
  ;; (:import-from :elmtui.core.keymap.focus-integration :handle-key-event) ; handle-key-event is now from elmtui.core.focus
  (:import-from :elmtui.core.keymap.event-integration
                #:setup-keyboard-event-handler)
  (:import-from :elmtui.core.focus ; Consolidated focus imports
                #:focus-manager          ; Struct name for type hints if needed
                #:make-focus-manager
                #:request-focus          ; For focus-element
                #:tab-navigate           ; For focus-next/previous
                #:component-gained-focus
                #:component-lost-focus
                #:navigate-direction
                #:register-focus-context
                #:switch-focus-context
                #:handle-key-event       ; From elmtui.core.focus
                #:list-active-keybindings) ; From elmtui.core.focus (for introspection)
  ;; Import symbols to re-export
  (:import-from :elmtui.core.keymap
                #:define-keymap
                #:parse-key-string
                #:normalized-key->string)
  (:import-from :elmtui.core.keymap.registry
                #:define-keymap-context
                #:activate-context        ; Already imported from registry for internal use
                #:deactivate-context
                #:current-context
                #:register-keymap         ; Already imported from registry for internal use
                #:find-keymap
                #:find-context)
  (:export
   ;; System setup and initialization
   #:initialize-keymap-system
   #:create-focus-manager
   #:setup-key-event-handling

   ;; Focus management
   #:focus-element
   #:focus-next
   #:focus-previous
   #:navigate-focus

   ;; Keymap management (defined in this package)
   #:add-keybinding
   #:remove-keybinding
   #:register-component-keymap

   ;; Re-exported from elmtui.core.keymap
   #:define-keymap
   #:parse-key-string
   #:normalized-key->string

   ;; Re-exported from elmtui.core.keymap.registry
   #:define-keymap-context
   #:activate-context    ; This is fine, it's used internally and also good for export
   #:deactivate-context
   #:current-context
   #:register-keymap     ; This is fine, it's used internally and also good for export
   #:find-keymap
   #:find-context

   ;; Re-exported from elmtui.core.keymap.defaults
   #:*global-navigation-keymap*
   #:*dialog-keymap*
   #:*form-keymap*
   #:*editor-keymap*
   #:*list-navigation-keymap*

   ;; Re-exported from elmtui.core.focus (for introspection)
   #:list-active-keybindings
   ))

(in-package :elmtui.core.keymap-system)

;;;-----------------------------------------------------------------------------
;;; System Initialization
;;;-----------------------------------------------------------------------------

(defun initialize-keymap-system ()
  "Initialize the keymap system with standard keymaps and focus handlers."
  (log-info "Initializing keymap system")

  ;; Initialize event channels
  (when (find-package :elmtui.core.event-async)
    (funcall (intern "INITIALIZE-EVENT-CHANNELS" :elmtui.core.event-async)))

  ;; Register standard keymaps
  (register-standard-keymaps)

  ;; Ensure global context is active
  (activate-context *global-keymap-context*)

  ;; Return success
  t)

(defun create-focus-manager ()
  "Create and initialize a focus manager."
  (make-focus-manager)) ; Uses elmtui.core.focus:make-focus-manager

(defun setup-key-event-handling (focus-manager app-state)
  "Set up keyboard event handling for the application."
  (elmtui.core.keymap.event-integration:setup-keyboard-event-handler focus-manager app-state)

  ;; The call to elmtui.core.keymap.focus-integration:register-focus-keymaps was here.
  ;; It's considered redundant as component keymap contexts are handled dynamically
  ;; by component-gained-focus / component-lost-focus in elmtui.core.focus.
  t)

;;;-----------------------------------------------------------------------------
;;; Focus Management API
;;;-----------------------------------------------------------------------------

(defun focus-element (focus-manager element-id)
  "Focus a specific element."
  (request-focus focus-manager element-id)) ; Uses elmtui.core.focus:request-focus

(defun focus-next (focus-manager)
  "Focus the next element in tab order."
  (tab-navigate focus-manager :forward)) ; Uses elmtui.core.focus:tab-navigate

(defun focus-previous (focus-manager)
  "Focus the previous element in tab order."
  (tab-navigate focus-manager :backward)) ; Uses elmtui.core.focus:tab-navigate

(defun navigate-direction (focus-manager direction)
  "Navigate focus in a specified direction.
   DIRECTION can be one of :up, :down, :left, :right."
  (case direction
    (:up (tab-navigate focus-manager :forward))
    (:down (tab-navigate focus-manager :backward))
    (:left (tab-navigate focus-manager :backward))
    (:right (tab-navigate focus-manager :forward))
    (otherwise (error "Invalid navigation direction: ~A" direction))))

(defun navigate-focus (focus-manager direction)
  "Navigate focus in a direction (one of :up, :down, :left, :right)."
  (navigate-direction focus-manager direction))

;;;-----------------------------------------------------------------------------
;;; Keymap Management API
;;;-----------------------------------------------------------------------------

(defun add-keybinding (keymap key-string action-type action-target &key description)
  "Add a keybinding to a keymap.
   KEYMAP: The keymap to modify.
   KEY-STRING: String representation of the key (e.g., 'C-x').
   ACTION-TYPE: Either :action (function) or :message.
   ACTION-TARGET: Function symbol or message data.
   DESCRIPTION: Optional description of the binding."
  (let ((key (elmtui.core.keymap:parse-key-string key-string))
        (binding (list :type action-type :target action-target :description description)))
    (setf (gethash key (elmtui.core.keymap:keymap-bindings keymap)) binding)
    binding))

(defun remove-keybinding (keymap key-string)
  "Remove a keybinding from a keymap."
  (let ((key (elmtui.core.keymap:parse-key-string key-string)))
    (remhash key (elmtui.core.keymap:keymap-bindings keymap))
    t))

(defun register-component-keymap (focus-manager component-id keymap)
  "Register a keymap for a specific component.
   Automatically creates a context for the component."
  (let ((keymap-id (gensym (format nil "KEYMAP-~A-" component-id))))
    ;; Register the keymap
    (register-keymap keymap-id keymap)

    ;; Create a focus context for the component if it doesn't exist
    (register-focus-context focus-manager component-id)

    keymap-id))

;;;-----------------------------------------------------------------------------
;;; Focus Change Notifications
;;;-----------------------------------------------------------------------------

(defun notify-focus-change (old-focus new-focus app-state)
  "Handle focus changes between components with keymap integration."
  ;; Deactivate old component's keymap context
  (when old-focus
    (component-lost-focus old-focus app-state)) ; Uses elmtui.core.focus:component-lost-focus

  ;; Activate new component's keymap context
  (when new-focus
    (component-gained-focus new-focus app-state)) ; Uses elmtui.core.focus:component-gained-focus

  ;; Return the new focus
  new-focus)
