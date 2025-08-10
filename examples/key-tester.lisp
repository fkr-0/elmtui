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
  (log-info "Key Tester App received message: ~S" message)
  (log-info "Key Tester App received state: ~S" app-state)
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
      ((or (typep message 'key-event)
           (eql (car message) :keyevent))

       (let ((new-comp (key-tester-on-key-event (copy-structure component) message)))
         (log-info "Key Tester App received key event: ~S" message)
         (make-update-result :patches `((:component ,new-comp)))))

      ;; --- Default Case ---
      (t
       (log-info "Key Tester App received unhandled message: ~S" message)
       (make-update-result)))))
;; (ELMTUI.VIEW.DSL:RENDER-DSL-TO-RESOLVED-TREE
;;  (:ROOT-VIEWPORT :ID :KEY-TESTER-ROOT :INITIAL-TERMINAL-DIMENSIONS #1=(1 1) :INITIAL-CURSOR-POS #1# :CHILDREN
;;                  (:CONTAINER :ID :KEY-TESTER-WIDGET :KEYMAP-ID :KEY-TESTER-EXAMPLE-CONTEXT :FOCUSABLE T :STYLE (:BORDER T :DIRECTION :COLUMN :WIDTH :AUTO :HEIGHT :AUTO :MIN-WIDTH 40 :MIN-HEIGHT 8 ...) :CHILDREN ((:TEXT :CONTENT "Elm TUI Key Tester") (:TEXT :CONTENT "Input: j") (:TEXT :CONTENT "Echo:  (:|j|)") (:TEXT :CONTENT "Press 'q' to quit. Try Backspace and Escape.")))
;;                  )
;;  #S(ELMTUI.CONTRACTS:APP-CONTEXT :VIEW-FN #<FUNCTION ELMTUI.EXAMPLES.KEY-TESTER::WRAPPED-VIEW-KEY-TESTER-APP>
;;                                  :STATE #<ELMTUI.TEA-STATE.API:APPLICATION-STATE data: 2, history: 2>
;;                                  :STYLESHEET NIL
;;                                  :VIEWPORT-RECT #<ELMTUI.VIEW.GEO:RECTANGLE Pos:#<POS X:0 Y:0> Size:#<SIZE W:95 H:41>> :DSL-TREE NIL :RAW-TREE NIL :STYLED-TREE NIL :ATOMIC-TREE NIL
;;                                  :LAID-OUT-TREE NIL :
;;                                  FRONT-BUFFER #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:VIRTUAL-TERMINAL-BUFFER :WIDTH 95 :HEIGHT 41 :CELLS #2A((#S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) ...) (#S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) ...) (#S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) ...) (#S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) ...) (#S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) ...) (#S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) ...) (#S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) ...) (#S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) ...) (#S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) ...) (#S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) ...) (#S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) ...) (#S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) #S(ELMTUI.PLATFORM.BACKEND.COMMON.VIRTUAL-BUFFER:BUFFER-CELL :CHAR #  :STYLE NIL) ...) ...) :DEFAULT-STYLE NIL :LOCK #<SB-THREAD:MUTEX "virtual-buffer-lock" free owner=0>) :BACK-BUFFER NIL :BACKEND #S(ELMTUI.PLATFORM.BACKEND.TERMINAL:TERMINAL-INSTANCE :FD 11 :STREAM #<SB-SYS:FD-STREAM for "file /dev/tty" {120697DBA3}> :ORIGINAL-TERMIOS #<SB-POSIX:TERMIOS {120705FB63}> :CURRENT-TERMIOS #<SB-POSIX:TERMIOS {120692EF93}> :WIDTH 95 :HEIGHT 41 :CURSOR-START-COL 1 :CURSOR-START-ROW 41 :CURSOR-VISIBLE-P T :CURSOR-ROW 41 :CURSOR-COL 1 :CURRENT-STYLE #S(ELMTUI.PLATFORM.BACKEND.COMMON.ANSI-STYLING:TERMINAL-STYLE :FG-COLOR NIL :BG-COLOR NIL :BOLD NIL :ITALIC NIL :UNDERLINE NIL :FAINT NIL :BLINK NIL :INVERSE NIL :STRIKE NIL :INVISIBLE NIL))
;;                                  ))
(defun key-tester-view (app-state &key root-id)
  "Renders the application's UI based on the current state."
  (log-info "Rendering Key Tester App with state: ~S ~A"
            app-state root-id)
  (let ((component
          (state-ref app-state :component)))
    `(:container
      :id :key-tester-widget
      :keymap-id :key-tester-example-context ; Link to our keymap context
      :focusable t
      :style (:border t :direction :column :width :auto :height :auto
              :min-width 40 :min-height 8 :display :block
              :margin 1
              :border-style :solid :border-width 1
              :fg-color (128 128 128)
              )
      :children ((:text
                  :content "Elm TUI Key Tester")
                 (:text :content
                        ,(format nil "Input: ~A" (key-tester-input component)))
                 (:text :content
                        ,(format nil "Echo:  ~A" (key-tester-echo component)))
                 (:text :content
                        "Press 'q' to quit. Try Backspace and Escape.")))))

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
;; (defun initialize-app-state-key-tester-app
;;         (
;;          &key (elmtui.app::initial-terminal-dimensions '(80 24))
;;          (elmtui.app::initial-cursor-position '(0 0)) &allow-other-keys)
;;    (declare
;;     (ignorable elmtui.app::initial-terminal-dimensions
;;      elmtui.app::initial-cursor-position))
;;    (let* ((elmtui.app::app-state
;;            (elmtui.tea-state.api:make-state
;;             (alexandria:plist-hash-table `(:component ,(make-key-tester))))))
;;      (multiple-value-bind (elmtui.app::patches elmtui.app::commands)
;;          (elmtui.ui.api:initialize-components-from-dsl
;;           '(:root-viewport :id :key-tester-root :initial-terminal-dimensions
;;             (1 1) :initial-cursor-pos (1 1) :children
;;             (:layout :id :key-tester-widget)))
;;        (elmtui.tea-state.transactions:apply-patches elmtui.app::app-state
;;                                                     elmtui.app::patches)
;;        (values elmtui.app::app-state elmtui.app::commands))))
;; (let ((tutu (elmtui.contracts:make-app-context
;;              :view-fn 'wrapped-view-key-tester-app
;;              :state (elmtui.tea-state.api:make-state
;;                      `(:component ,(make-key-tester)))
;;              :stylesheet nil
;;              :viewport-rect (elmtui.view.geo:make-rectangle
;;                              :pos (elmtui.view.geo:make-pos :x 0 :y 0)
;;                              :size (elmtui.view.geo:make-size :w 95 :h 41))
;;              :dsl-tree nil
;;              :raw-tree nil
;;              :styled-tree nil
;;              :atomic-tree nil
;;              :laid-out-tree nil
;;              :front-buffer (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer
;;                             95 41)
;;              :backend nil ;; (elmtui.platform.backend.terminal:make-terminal-instance)
;;              ))
;;       (t2 (elmtui.pipeline:full-view-pipeline tutu)))

;;   (log-info (elmtui.platform.backend.common.virtual-buffer:print-buffer-to-string
;;    (elmtui.contracts:ctx-back-buffer t2)))
;;   t2)


;;   (elmtui.view.tree-transforms:process-tree
;;    (elmtui.view.dsl:render-dsl-to-resolved-tree
;;     (key-tester-view (initialize-app-state-key-tester-app)
;;                      :root-id :key-tester-root)
;;     (initialize-app-state-key-tester-app))
;;    :ctx tutu :root-rect (elmtui.view.geo:make-rectangle
;;                          :pos (elmtui.view.geo:make-pos :x 0 :y 0)
;;                          :size (elmtui.view.geo:make-size :w 95 :h 41))))

;; (key-tester-view )
;; (elmtui.tea-state:make-application-state)
