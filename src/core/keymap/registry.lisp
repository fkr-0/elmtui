;;;===============================================================
;;; File: src/core/keymap/registry.lisp
;;; Keymap Registry - Centralized keymap management with context support
;;;===============================================================
(uiop:define-package :elmtui.core.keymap.registry
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.core.keymap
   :keymap :make-keymap
   :normalized-key :normalized-key=
   :lookup-keymap :create-keymap-from-definitions)
  (:export
   ;; Registry management
   #:find-context
   #:*keymap-registry*
   #:register-keymap
   #:collect-all-defined-sequences
   #:keymap-context-keymaps
   #:unregister-keymap
   #:find-keymap
   #:list-keymaps

   ;; Context management
   #:keymap-context
   #:make-keymap-context
   #:define-keymap-context
   #:add-keymap-to-context
   #:remove-keymap-from-context
   #:activate-context
   #:deactivate-context
   #:current-context

   ;; Lookup with context
   #:lookup-key-in-context
   #:lookup-key-binding

   ;; Keymap Introspection
   #:list-active-keybindings))

(in-package :elmtui.core.keymap.registry)

;;;-----------------------------------------------------------------------------
;;; Registry Structure
;;;-----------------------------------------------------------------------------

(defvar *keymap-registry* (make-hash-table :test 'eq)
  "Global registry of named keymaps.")

(defun register-keymap (name keymap)
  "Register a keymap with a given name."
  (log-debug "Registering keymap ~A" name)
  (setf (gethash name *keymap-registry*) keymap)
  keymap)

(defun unregister-keymap (name)
  "Remove a keymap from the registry."
  (log-debug "Unregistering keymap ~A" name)
  (remhash name *keymap-registry*))

(defun find-keymap (name)
  "Find a registered keymap by name."
  (gethash name *keymap-registry*))

(defun list-keymaps ()
  "List all registered keymaps."
  (let ((result '()))
    (maphash (lambda (name keymap)
               (push (cons name keymap) result))
             *keymap-registry*)
    result))

;;;-----------------------------------------------------------------------------
;;; Keymap Context - Groups of keymaps with activation state
;;;-----------------------------------------------------------------------------

(defstruct keymap-context
  "Represents a context of active keymaps with a specific order."
  (name nil :type (or symbol string) :read-only t)
  (keymaps '() :type list)        ; List of keymap names or direct keymaps, in order of priority
  (parent nil :type (or null keymap-context))  ; Parent context for inheritance
  (active nil :type boolean)      ; Whether this context is currently active
  (metadata nil))                 ; Additional metadata for the context

(defvar *keymap-context-registry* (make-hash-table :test 'eq)
  "Global registry of all defined keymap contexts, mapping context name to context object.")

(defvar *active-contexts* nil
  "Stack of currently active contexts, ordered by activation time (most recent first).")

(defmacro define-keymap-context (name (&key parent) &body keymap-names)
  "Define a named keymap context and register it."
  `(progn
     (defparameter ,name
       (make-keymap-context
        :name ',name
        :keymaps (list ,@keymap-names)
        :parent ,parent))
     (setf (gethash ',name *keymap-context-registry*) ,name)
     ,name))

(defun add-keymap-to-context (context keymap-name &optional (position :end))
  "Add a keymap to the context at the specified position (:start, :end, or numeric index)."
  (let ((new-list (copy-list (keymap-context-keymaps context))))
    (setf (keymap-context-keymaps context)
          (ecase position
            (:start (cons keymap-name new-list))
            (:end (append new-list (list keymap-name)))
            ((integer
              (let ((adjusted-pos (min position (length new-list))))
                (append (subseq new-list 0 adjusted-pos)
                        (list keymap-name)
                        (subseq new-list adjusted-pos)))))))))

(defun remove-keymap-from-context (context keymap-name)
  "Remove a keymap from the context."
  (setf (keymap-context-keymaps context)
        (remove keymap-name (keymap-context-keymaps context))))

;;;-----------------------------------------------------------------------------
;;; Context Activation
;;;-----------------------------------------------------------------------------

(defun activate-context (context)
  "Activate a keymap context, making it the current context."
  (log-debug "Activating keymap context ~A" (keymap-context-name context))

  ;; If the context is already active, move it to the front
  (setf *active-contexts* (remove context *active-contexts*))

  ;; Add to front of active contexts
  (push context *active-contexts*)
  (setf (keymap-context-active context) t))

(defun deactivate-context (context)
  "Deactivate a keymap context."
  (log-debug "Deactivating keymap context ~A" (keymap-context-name context))
  (setf *active-contexts* (remove context *active-contexts*))
  (setf (keymap-context-active context) nil))

(defun current-context ()
  "Get the currently active context, or NIL if none is active."
  (first *active-contexts*))

;;;-----------------------------------------------------------------------------
;;; Context-Aware Lookup
;;;-----------------------------------------------------------------------------

(defun resolve-keymap-reference (keymap-ref)
  "Resolve a keymap reference (name or direct keymap) to a keymap object."
  (cond
    ((typep keymap-ref 'keymap) keymap-ref)
    ((or (symbolp keymap-ref) (stringp keymap-ref))
     (find-keymap keymap-ref))
    (t nil)))

(defun collect-context-keymaps (context)
  "Collect all keymaps from a context, including parent contexts."
  (let ((result '()))
    ;; First, collect keymaps from parents recursively
    (when (keymap-context-parent context)
      (setf result (append result (collect-context-keymaps (keymap-context-parent context)))))

    ;; Then add this context's keymaps, resolving each reference
    (dolist (keymap-ref (keymap-context-keymaps context))
      (let ((keymap (resolve-keymap-reference keymap-ref)))
        (when keymap
          (push keymap result))))

    ;; Return in proper order (higher priority first)
    (nreverse result)))

(defun lookup-key-in-context (key &optional (context (current-context)))
  "Look up a key binding in the current context.
   Returns the binding if found, or NIL if not found."
  (when context
    (let ((keymaps (collect-context-keymaps context)))
      (loop for keymap in keymaps
            for binding = (lookup-keymap keymap key)
            when binding return binding))))

(defun lookup-key-binding (key)
  "Look up a key binding across all active contexts.
   Searches contexts in order of activation (most recent first)."
  (loop for context in *active-contexts*
        for binding = (lookup-key-in-context key context)
        when binding return binding))

;;;-----------------------------------------------------------------------------
;;; Sequence Collection for Partial Matching
;;;-----------------------------------------------------------------------------

(defun collect-all-defined-sequences (context)
  "Collect all key sequences defined in the context and its parent contexts.
   Returns a list of key-sequence objects that are defined in active keymaps."
  (let ((result '())
        (processed-contexts (make-hash-table :test 'eq)))

    (labels ((collect-from-context (ctx)
               (unless (gethash ctx processed-contexts)
                 ;; Mark as processed to avoid loops
                 (setf (gethash ctx processed-contexts) t)

                 ;; Process this context's keymaps
                 (dolist (km (keymap-context-keymaps ctx))
                   (let ((keymap (resolve-keymap-reference km)))
                     (when keymap
                       ;; Add sequences from this keymap
                       (setf result (append result
                                            (elmtui.core.keymap.sequence:collect-key-sequences-from-keymap
                                             keymap))))))

                 ;; Process parent context if it exists
                 (when (keymap-context-parent ctx)
                   (collect-from-context (keymap-context-parent ctx))))))

      ;; Start collection from the provided context
      (when context
        (collect-from-context context)))

    result))

;;; Keymap Introspection section removed as list-active-keybindings was the only function here.

;;;-----------------------------------------------------------------------------
;;; Initialize Default Registry
;;;-----------------------------------------------------------------------------
;;; Initialize Default Registry
;;;-----------------------------------------------------------------------------

;; Create a global context that's always active
(defparameter *global-keymap-context* (make-keymap-context :name :global :active t))
(activate-context *global-keymap-context*)

;; Register the global context in the registry
(register-keymap :global *global-keymap-context*) ; This registers the *object* under :global
;; Also register the global context in the context registry
(setf (gethash (keymap-context-name *global-keymap-context*) *keymap-context-registry*) *global-keymap-context*)

(defun find-context (context-id)
  "Find a registered keymap context by ID from the global context registry."
  (gethash context-id *keymap-context-registry*))

;; Register the global keymap context
;; (register-keymap :default-global-keymap
;;                  (create-keymap-from-definitions
;;                   :name :default-global-keymap
;;                   :keymap-definitions
;;                   '((:key :escape :action :quit)
;;                     (:key #\q :action :quit)
;;                     (:key #\r :action :refresh)
;;                     (:key #\s :action :save))))
