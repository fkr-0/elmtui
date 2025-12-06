;;;===============================================================
;;; File: src/core/keymap/defaults.lisp
;;; Default Keymaps - Standard keymap definitions for navigation and interaction
;;;===============================================================
(uiop:define-package :elmtui.core.keymap.defaults
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.core.keymap
   :define-keymap
                :keymap
   :normalized-key=
                :make-keymap)
  (:import-from :elmtui.core.keymap.registry
   :register-keymap
                :normalized-key=
   :*global-keymap-context*
                :add-keymap-to-context)
  (:export
   ;; Standard keymaps
   #:*global-navigation-keymap*
   #:*dialog-keymap*
   #:*form-keymap*
   #:*editor-keymap*
   #:*list-navigation-keymap*

   ;; Keymap registration
   #:register-standard-keymaps

   ;; Common actions
   #:action-cancel
   #:action-confirm
   #:action-help
   #:action-menu))

(in-package :elmtui.core.keymap.defaults)

;;;-----------------------------------------------------------------------------
;;; Common Actions
;;;-----------------------------------------------------------------------------

;; These would typically be implemented elsewhere and imported here
;; For now, they're defined as stubs

(defun action-cancel (app-state)
  "Cancel current operation or close dialog."
  (declare (ignore app-state))
  (log-debug "Cancel action triggered"))

(defun action-confirm (app-state)
  "Confirm current operation or dialog."
  (declare (ignore app-state))
  (log-debug "Confirm action triggered"))

(defun action-help (app-state)
  "Show help screen."
  (declare (ignore app-state))
  (log-debug "Help action triggered"))

(defun action-menu (app-state)
  "Show application menu."
  (declare (ignore app-state))
  (log-debug "Menu action triggered"))

;;;-----------------------------------------------------------------------------
;;; Standard Keymaps
;;;-----------------------------------------------------------------------------

;; Global navigation keymap for application-wide navigation
(define-keymap *global-navigation-keymap*
  ("F1" :type :action :target 'action-help :description "Show Help")
  ("F10" :type :action :target 'action-menu :description "Show Menu")
  ("Escape" :type :action :target 'action-cancel :description "Cancel/Back")
  ("C-q" :type :message :target '(:quit) :description "Quit Application"))

;; Dialog keymap for modal dialogs
(define-keymap *dialog-keymap*
  ("Enter" :type :action :target 'action-confirm :description "Confirm")
  ("Escape" :type :action :target 'action-cancel :description "Cancel")
  ("Tab" :type :message :target '(:focus-next) :description "Next Field")
  ("S-Tab" :type :message :target '(:focus-previous) :description "Previous Field"))

;; Form keymap for form interaction
(define-keymap *form-keymap*
  ("Enter" :type :message :target '(:form-submit) :description "Submit Form")
  ("Tab" :type :message :target '(:focus-next) :description "Next Field")
  ("S-Tab" :type :message :target '(:focus-previous) :description "Previous Field")
  ("Escape" :type :message :target '(:form-cancel) :description "Cancel"))

;; Text editor keymap
(define-keymap *editor-keymap*
  ("C-a" :type :message :target '(:select-all) :description "Select All")
  ("C-c" :type :message :target '(:copy) :description "Copy")
  ("C-v" :type :message :target '(:paste) :description "Paste")
  ("C-x" :type :message :target '(:cut) :description "Cut")
  ("C-z" :type :message :target '(:undo) :description "Undo")
  ("C-y" :type :message :target '(:redo) :description "Redo"))

;; List navigation keymap
(define-keymap *list-navigation-keymap*
  ("Up" :type :message :target '(:select-previous) :description "Previous Item")
  ("Down" :type :message :target '(:select-next) :description "Next Item")
  ("Home" :type :message :target '(:select-first) :description "First Item")
  ("End" :type :message :target '(:select-last) :description "Last Item")
  ("PageUp" :type :message :target '(:page-up) :description "Page Up")
  ("PageDown" :type :message :target '(:page-down) :description "Page Down")
  ("Enter" :type :message :target '(:activate-selection) :description "Activate Selection"))

;;;-----------------------------------------------------------------------------
;;; Standard Keymap Registration
;;;-----------------------------------------------------------------------------

(defun register-standard-keymaps ()
  "Register all standard keymaps and add global ones to the global context."
  (log-info "Registering standard keymaps")

  ;; Register all keymaps
  (register-keymap :global-navigation *global-navigation-keymap*)
  (register-keymap :dialog *dialog-keymap*)
  (register-keymap :form *form-keymap*)
  (register-keymap :editor *editor-keymap*)
  (register-keymap :list-navigation *list-navigation-keymap*)

  ;; Add global navigation to global context
  (add-keymap-to-context *global-keymap-context* :global-navigation)

  t)
