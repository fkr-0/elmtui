;;;===============================================================
;;; File: src/core/input_events.lisp
;;; Standardized Input Event Structures
;;;
;;; Defines the canonical structures for representing various input
;;; events received from platform backends, ensuring consistency
;;; regardless of the underlying terminal or input mechanism.
;;;===============================================================

(uiop:define-package :elmtui.core.input-events
  (:use :cl)
  (:export #:input-event ; Base type (optional)
           ;; Keyboard Events
           #:key-event
           #:make-key-event
           #:key-event-key       ; Symbol representing the key (e.g., :enter, :f1, :a, :A)
           #:key-event-char      ; The actual character if printable, otherwise nil
           #:key-event-modifiers ; List of keywords (:shift, :control, :alt, :meta)
           #:key-event-raw       ; Original raw byte sequence (for debugging)
           #:key-event-type      ; :key-down, :key-up (optional, most terminals only send down)

           ;; Mouse Events
           #:mouse-event
           #:make-mouse-event
           #:mouse-event-type    ; :mouse-down, :mouse-up, :mouse-move, :scroll-up, :scroll-down
           #:mouse-event-button  ; Integer (1=left, 2=middle, 3=right, 4=scroll-up, 5=scroll-down, etc.)
           #:mouse-event-row     ; Integer row coordinate (0-based)
           #:mouse-event-col     ; Integer column coordinate (0-based)
           #:mouse-event-modifiers ; List of keywords (:shift, :control, :alt, :meta)
           #:mouse-event-raw     ; Original raw byte sequence

           ;; Focus Events
           #:focus-event
           #:make-focus-event
           #:focus-event-type    ; :focus-in, :focus-out

           ;; Paste Event
           #:paste-event
           #:make-paste-event
           #:paste-event-text    ; String containing the pasted text

           ;; Resize Event
           #:resize-event
           #:make-resize-event
           #:resize-event-width
           #:resize-event-height

           ;; Unknown/Raw Event
           #:raw-input-event
           #:make-raw-input-event
           #:raw-input-event-bytes ; Vector of bytes

           ;; Modifiers Check
           #:has-modifier-p
           ))

(in-package :elmtui.core.input-events)

;; Base structure (optional, for potential type hierarchy)
(defstruct input-event
  (raw nil :type (or null vector))) ; Raw bytes received

;; Keyboard Event
(defstruct (key-event (:include input-event))
  (key nil :type symbol)              ; Standardized key symbol (e.g., :enter, :f1, :a, :A)
  (char nil :type (or null character)) ; Character if printable
  (modifiers nil :type list)          ; List like (:control :shift)
  (type :key-down :type keyword))     ; Typically :key-down

;; Mouse Event
(defstruct (mouse-event (:include input-event))
  (type :mouse-down :type keyword) ; :mouse-down, :mouse-up, :mouse-move, :scroll-up, :scroll-down
  (button 0 :type integer)         ; 1=left, 2=middle, 3=right, 4/5=scroll, etc.
  (row 0 :type integer)            ; 0-based row
  (col 0 :type integer)            ; 0-based column
  (modifiers nil :type list))      ; List like (:control :shift)

;; Focus Event
(defstruct (focus-event (:include input-event))
  (type :focus-in :type keyword)) ; :focus-in or :focus-out

;; Paste Event (often bracketed paste mode)
(defstruct (paste-event (:include input-event))
  (text "" :type string))

;; Resize Event (often signaled via SIGWINCH, not direct input read)
(defstruct (resize-event (:include input-event))
  (width 0 :type integer)
  (height 0 :type integer))

;; Fallback for unparsed sequences
(defstruct (raw-input-event (:include input-event))
  (bytes nil :type (vector (unsigned-byte 8))))

;; Helper function
(defun has-modifier-p (event modifier-keyword)
  "Checks if an event (like key-event or mouse-event) has a specific modifier."
  (let ((mods (cond ((key-event-p event) (key-event-modifiers event))
                    ((mouse-event-p event) (mouse-event-modifiers event))
                    (t nil))))
    (member modifier-keyword mods)))
