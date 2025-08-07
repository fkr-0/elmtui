;;; examples/key-tester.lisp
;;; A thorough example demonstrating how to integrate a legacy, functional
;;; component with the modern defapplication framework, including keymaps
;;; and focus management, following the recommended "Central Gateway" architecture.
(uiop:define-package :elmtui.examples.key-tester
  (:use :cl )

  (:import-from #:log4cl
                #:log-info)
  ;; Import the legacy widget and its keymap definitions
  (:import-from :example.key-tester
                #:make-key-tester
                #:key-tester-input
                #:key-tester-echo
                #:key-tester-on-key-event)
  (:import-from :example.key-tester.keymap
                #:kt-handle-delete-last
                #:kt-handle-clear-input)
  ;; Import from elmtui systems
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.tea-state
                #:make-update-result
                #:state-ref)


  (:import-from :elmtui.keymaps #:key-event-p
                #:define-keymap
                #:define-keymap-context
                #:register-keymap
                #:activate-context
                #:deactivate-context
                #:current-context

                #:key-event-key
                #:key-event-modifiers
                #:key-event->normalized-key
                #:normalized-key->string)

  (:import-from :elmtui.core.event-types #:key-event)
  (:import-from :elmtui.ui.widgets.layout #:layout) ; Import the layout component
  (:export
   #:run-key-tester-app
   #:%fake-key-event
   #:run))

(in-package :elmtui.examples.key-tester)

;;; ----------------------------------------------------------------------
;;; Keymap Integration Layer (Strategy A: Central Gateway)
;;; ----------------------------------------------------------------------

;; Actions dispatch high-level semantic messages.
(defun action-delete-char (app-state)
  (declare (ignore app-state))
  '(:delete-last-char))

(defun action-clear-buffer (app-state)
  (declare (ignore app-state))
  '(:clear-input))

;; The keymap binds keys to these message-dispatching actions.
(define-keymap *key-tester-example-keymap*
  ("backspace" :type :action :target 'action-delete-char
               :description "Delete last character")
  ("escape"    :type :action :target 'action-clear-buffer
               :description "Clear the input buffer"))

;; The context makes the keymap active when the component is focused.
(define-keymap-context :key-tester-example-context :parent nil
  :keymaps (list *key-tester-example-keymap*))


;;; ----------------------------------------------------------------------
;;; Application Definition
;;; ----------------------------------------------------------------------

(defun key-tester-update (message app-state)
  "Handles updates for the key tester application.
   This function reacts to high-level messages from the keymap,
   or raw key events for text input."
  (let ((component (state-ref app-state :component)))
    (cond
      ;; --- Global Quit Command ---
      ((and (typep message 'key-event) (eq (key-event-key message) #\q))
       (make-update-result :patches '((:should-quit t))))

      ;; --- Messages from our Keymap Actions ---
      ((equal message '(:delete-last-char))
       (let ((new-comp (kt-handle-delete-last (copy-structure component))))
         (make-update-result :patches `((:component ,new-comp)))))

      ((equal message '(:clear-input))
       (let ((new-comp (kt-handle-clear-input (copy-structure component))))
         (make-update-result :patches `((:component ,new-comp)))))

      ;; --- Raw Key Events for Echo and Input ---
      ;; This handles printable characters. The keymap above handles Backspace/Escape.
      ((typep message 'key-event)
       (let ((new-comp (key-tester-on-key-event (copy-structure component) message)))
         (make-update-result :patches `((:component ,new-comp)))))

      ;; --- Default Case ---
      (t
       (log-info "Key Tester App received unhandled message: ~S" message)
       (make-update-result)))))

(defun key-tester-view (app-state)
  "Renders the application's UI based on the current state."
  (let ((component (state-ref app-state :component)))
    `(:container
      :id :key-tester-widget
      :keymap-id :key-tester-example-context ; Link to our keymap context
      :focusable t
      :style (:border t :direction :column :width :auto :height :auto
              :min-width 40 :min-height 8 :display :block
              :margin 1
              :border-style :solid :border-width 1
                                        ;:fg-color (128 128 128)
              )
      :children ((:text
                  :content "Elm TUI Key Tester")
                 (:text :content ,(format nil "Input: ~A" (key-tester-input component)))
                 (:text :content ,(format nil "Echo:  ~A" (key-tester-echo component)))
                 (:text :content "Press 'q' to quit. Try Backspace and Escape.")))))

;; Define the application using the modern `defapplication` macro.
(defapplication key-tester-app
  :root-viewport-id :key-tester-root
  :initial-state-plist `(:component ,(make-key-tester))
  ;; The root component DSL must define the component that the view function renders.
  :root-component-dsl '(:layout :id :key-tester-widget)
  :update-fn 'key-tester-update
  :view-fn 'key-tester-view)

;; Export a runner function.
;; (defun run ()
;;   "Run the key tester example application."
;;   (run-key-tester-app))
