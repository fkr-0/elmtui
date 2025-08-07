;;; == exampleproject/src/components/key-tester-keymap.lisp ==
(uiop:define-package :example.key-tester.keymap
  (:use :cl #:log4cl)
  (:import-from :elmtui.keymaps
                #:define-keymap
                #:register-keymap             ;; internal in unified file; if not exported, strip & just keep the var
                #:define-keymap-context
                #:activate-context
                #:deactivate-context
                #:current-context
                )
  (:import-from :example.key-tester
                #:key-tester
                )
  (:export
   #:*key-tester-keymap*
   #:*key-tester-context*
   #:kt-handle-delete-last
   #:kt-handle-clear-input
   #:kt-focus-gained
   #:kt-focus-lost))

(in-package :example.key-tester.keymap)

;;; --------------------------------------------------------------------------
;;; Actions (operate directly on component instance).
;;; In your app, you might wrap these into messages (TEA) instead.
;;; --------------------------------------------------------------------------

(defun kt-handle-delete-last (component)
  "Backspace: delete last character in INPUT (if any)."
  ;; (when (> (length (key-tester-input component)) 0)
  ;;   (setf (key-tester-input component)
  ;;         (subseq (key-tester-input component) 0 (1- (length (key-tester-input component))))))
  component)

(defun kt-handle-clear-input (state)
  "Escape: clear INPUT entirely."

  (log-info "ok")
  state)

;;; --------------------------------------------------------------------------
;;; Component keymap
;;; --------------------------------------------------------------------------

(define-keymap *key-tester-keymap*
  ;; Backspace deletes last char
  ("Backspace" :type :action :target 'kt-handle-delete-last :description "Delete last character")
  ;; Escape clears input
  ("Escape"    :type :action :target 'kt-handle-clear-input :description "Clear input"))

;;; If you want to use contexts to enable/disable the component map with focus:
(defparameter *key-tester-context*
  (define-keymap-context :key-tester :parent nil :keymaps (list *key-tester-keymap*)))

(defun kt-focus-gained ()
  "Activate component context on focus."
  (activate-context *key-tester-context*))

(defun kt-focus-lost ()
  "Deactivate component context when focus leaves."
  (deactivate-context *key-tester-context*))
;;; == end/components/key-tester-keymap.lisp ==
