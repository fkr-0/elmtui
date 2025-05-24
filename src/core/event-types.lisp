
;;; File: src/core/event-types.lisp
;;; Standardized Event Type Definitions
;;;===============================================================
(uiop:define-package :elmtui.core.event-types
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn)
  (:import-from :elmtui.core.conditions
                #:event-validation-error)
  (:export
   ;; Event base struct
   #:ui-event
   #:make-ui-event
   #:ui-event-p
   #:ui-event-type
   #:ui-event-target
   #:ui-event-timestamp
   #:ui-event-consumed-p
   #:ui-event-original-event
   #:ui-event-stop-propagation

   ;; Key event
   #:key-event
   #:make-key-event
   #:key-event-p
   #:key-event-type
   #:key-event-key
   #:key-event-code
   #:key-event-modifiers
   #:key-event-consumed-p
   #:key-event-timestamp
   #:key-event-keycode
   #:key-event-modifier-state
   #:key-event-char


   ;; Mouse event
   #:mouse-event
   #:make-mouse-event
   #:mouse-event-p
   #:mouse-event-type
   #:mouse-event-x
   #:mouse-event-y
   #:mouse-event-modifiers
   #:mouse-event-timestamp
   #:mouse-event-button
   #:mouse-event-click-count
   #:mouse-event-delta-x
   #:mouse-event-delta-y
   #:mouse-event-consumed-p

   ;; Focus Event
   #:focus-event
   #:make-focus-event
   #:focus-event-p
   #:focus-event-type
   #:focus-event-target
   #:focus-event-source
   #:focus-event-timestamp
   #:focus-event-consumed-p
   ;; Window Event
   #:window-event
   #:make-window-event
   #:window-event-p
   #:window-event-type
   #:window-event-width
   #:window-event-height
   #:window-event-timestamp
   ;; System Event
   #:system-event
   #:make-system-event
   #:system-event-p
   #:system-event-type
   #:system-event-data
   #:system-event-timestamp
   ;; Timer Event
   #:timer-event
   #:make-timer-event
   #:timer-event-p
   #:timer-event-id
   #:timer-event-timestamp
   #:timer-event-user-data
   ;; Command Event
   #:command-event
   #:make-command-event
   #:command-event-p
   #:command-event-name
   #:command-event-args
   #:command-event-source
   #:command-event-timestamp
   ;; Event utility functions
   #:consume-event
   #:stop-propagation
   #:prevent-default
   ;; Event types

   ;; Resize Event
   #:paste-event
   #:make-paste-event
   #:paste-event-text    ; String containing the pasted text
   #:key-event-raw       ; Original raw byte sequence (for debugging)
   #:mouse-event-raw     ; Original raw byte sequence
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
   ;; Validation and normalization functions
   #:valid-key-event-p
   #:valid-mouse-event-p
   #:normalize-key-event
   #:normalize-mouse-event
   #:normalize-focus-event

   ;; Event control functions
   #:stop-propagation
   #:prevent-default))

(in-package :elmtui.core.event-types)

;; Base structure (optional, for potential type hierarchy)
(defstruct input-event
  (raw nil :type (or null vector))) ; Raw bytes received

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

;;;-----------------------------------------------------------------------------
;;; Base UI Event Type
;;;-----------------------------------------------------------------------------
(defstruct (ui-event (:constructor make-ui-event))
  "Base event structure for all UI events."
  (type (error "Type required") :type keyword)  ; :key-down, :mouse-up, etc.
  (target nil :type (or null symbol keyword))   ; ID of target element
  (timestamp (get-internal-real-time) :type integer)
  (consumed-p nil :type boolean)                ; Whether event has been consumed
  (original-event nil))                         ; Original platform event if applicable

(defun ui-event-stop-propagation (event)
  "Stops further propagation of the event."
  (setf (ui-event-consumed-p event) t)
  event)


;;===============================================================

;; Keyboard events
;;;-----------------------------------------------------------------------------
;;; Key Event Type
;;;-----------------------------------------------------------------------------

(defstruct (key-event (:constructor make-key-event )(:include input-event))
  "Represents a keyboard event."
  (type :key-down :type keyword) ; :key-down, :key-up
  (key nil :type (or null character keyword))  ; e.g., #\a, :enter, :f1
  (char nil :type (or null character))           ; Character representation
  (code nil :type (or null integer))           ; platform-specific keycode
  (modifiers nil :type list)                   ; e.g., (:control :shift)
  (timestamp (get-internal-real-time) :type integer)
  (consumed-p nil :type boolean))

;; (defmethod key-event-p ((event key-event))
;;   "Check if EVENT is a valid key-event structure."
;;   (and
;;    (member (key-event-type event) '(:key-down :key-up :key-press))
;;    (or (characterp (key-event-key event))
;;        (keywordp (key-event-key event))
;;        (null (key-event-key event)))))

(defun valid-key-event-p (event)
  "Returns true if EVENT is a valid key-event structure."
  (and (key-event-p event)
       (member (key-event-type event) '(:key-down :key-up :key-press))
       (or (characterp (key-event-key event))
           (keywordp (key-event-key event))
           (null (key-event-key event)))))

;; (defun key-event-char (event)
;;   "Returns the character representation of the key-event."
;;   (if (characterp (key-event-key event))
;;       (key-event-key event)
;;       (case (key-event-key event)
;;         (:enter #\Return)
;;         (:space #\Space)
;;         (:tab #\Tab)
;;         (:backspace #\Backspace)
;;         (:delete #\Delete)
;;         ;; Add more mappings as needed
;;         (t nil))))

(defun normalize-key-event (platform-event)
  "Converts platform-specific keyboard event to a standardized key-event.
   PLATFORM-EVENT: The raw event from the platform layer."
  ;; Implementation depends on platform-specific event structure.
  ;; This is a generic implementation that assumes a minimal interface.
  (let ((type (or (getf platform-event :type) :key-down))
        (key (or (getf platform-event :key)
                 (getf platform-event :character)))
        (code (getf platform-event :code))
        (mods (getf platform-event :modifiers)))

    ;; Normalize modifiers to keywords
    (let ((normalized-mods
            (loop for mod in (if (listp mods) mods (list mods))
                  when mod
                    collect (if (keywordp mod) mod (intern (string-upcase mod) :keyword)))))

      (make-key-event :type type
                      :key key
                      :code code
                      :modifiers normalized-mods))))

;;;-----------------------------------------------------------------------------
;;; Mouse Event Type
;;;-----------------------------------------------------------------------------

(defstruct (mouse-event (:constructor make-mouse-event )(:include input-event))
  "Represents a mouse input event."
  (type (error "Type required") :type keyword) ; :mouse-down, :mouse-up, :mouse-move, etc.
  (x 0 :type integer)                          ; X coordinate
  (y 0 :type integer)                          ; Y coordinate
  (button nil :type (or null keyword))         ; :left, :middle, :right
  (click-count 0 :type integer)                ; For detecting double/triple clicks
  (delta-x 0 :type integer)                    ; For scroll events
  (delta-y 0 :type integer)                    ; For scroll events
  (modifiers nil :type list)                   ; Keyboard modifiers during event
  (timestamp (get-internal-real-time) :type integer)
  (consumed-p nil :type boolean))

;; (defmethod mouse-event-p ((event mouse-event))
;;   "Check if EVENT is a valid mouse-event structure."
;;   (and
;;    (member (mouse-event-type event) '(:mouse-down :mouse-up :mouse-move))
;;    (integerp (mouse-event-x event))
;;    (integerp (mouse-event-y event))))

(defun valid-mouse-event-p (event)
  "Returns true if EVENT is a valid mouse-event structure."
  (and (mouse-event-p event)
       (member (mouse-event-type event)
               '(:mouse-down :mouse-up :mouse-move :mouse-wheel :mouse-enter :mouse-leave))))

(defun normalize-mouse-event (platform-event)
  "Converts platform-specific mouse event to a standardized mouse-event.
   PLATFORM-EVENT: The raw event from the platform layer."
  ;; Implementation depends on platform-specific event structure
  ;; This is a generic implementation that assumes a minimal interface
  (let ((type (or (getf platform-event :type) :mouse-move))
        (x (or (getf platform-event :x) 0))
        (y (or (getf platform-event :y) 0))
        (button (getf platform-event :button))
        (click-count (or (getf platform-event :click-count) 1))
        (delta-x (or (getf platform-event :delta-x) 0))
        (delta-y (or (getf platform-event :delta-y) 0))
        (mods (getf platform-event :modifiers)))

    ;; Normalize button to keyword
    (let ((normalized-button
            (cond
              ((null button) nil)
              ((keywordp button) button)
              ((numberp button) (case button
                                  (0 :left)
                                  (1 :middle)
                                  (2 :right)
                                  (otherwise button)))
              (t (intern (string-upcase button) :keyword))))

          ;; Normalize modifiers to keywords
          (normalized-mods
            (loop for mod in (if (listp mods) mods (list mods))
                  when mod
                    collect (if (keywordp mod) mod (intern (string-upcase mod) :keyword)))))

      (make-mouse-event :type type
                        :x x
                        :y y
                        :button normalized-button
                        :click-count click-count
                        :delta-x delta-x
                        :delta-y delta-y
                        :modifiers normalized-mods))))
;;===============================================================
;; Focus events
(defstruct (focus-event (:constructor make-focus-event)
                        (:include input-event))
  (type (error "Type required") :type keyword) ; :focus-in, :focus-out, :focus-request
  (target nil) ; The component receiving/losing focus
  (source nil) ; The previous/next component with focus
  (timestamp (get-internal-real-time) :type integer)
  (consumed-p nil :type boolean))

;; (defmethod focus-event-p ((event focus-event))
;;   "Check if EVENT is a valid focus-event structure."
;;   (and
;;    (member (focus-event-type event) '(:focus-in :focus-out :focus-request))
;;    (or (null (focus-event-target event))
;;        (typep (focus-event-target event) 'component))
;;    (or (null (focus-event-source event))
;;        (typep (focus-event-source event) 'component))))

;; Window events
(defstruct (window-event (:constructor make-window-event))
  (type (error "Type required") :type keyword) ; :resize, :minimize, :maximize
  (width 0 :type integer)
  (height 0 :type integer)
  (timestamp (get-internal-real-time) :type integer))

;; (defmethod window-event-p ((event window-event))
;;   "Check if EVENT is a valid window-event structure."
;;   (and
;;    (member (window-event-type event) '(:resize :minimize :maximize))
;;    (integerp (window-event-width event))
;;    (integerp (window-event-height event))))
;; System events
(defstruct (system-event (:constructor make-system-event))
  (type (error "Type required") :type keyword) ; :shutdown, :suspend, :resume
  (data nil)
  (timestamp (get-internal-real-time) :type integer))

;; (defmethod system-event-p ((event system-event))
;;   "Check if EVENT is a valid system-event structure."
;;   (and
;;    (member (system-event-type event) '(:shutdown :suspend :resume))
;;    (or (null (system-event-data event))
;;        (typep (system-event-data event) 'list))))
;; Timer events
(defstruct (timer-event (:constructor make-timer-event))
  (id (error "Timer ID required"))
  (timestamp (get-internal-real-time) :type integer)
  (user-data nil))

;; (defmethod timer-event-p ((event timer-event))
;;   "Check if EVENT is a valid timer-event structure."
;;   (and
;;    (integerp (timer-event-id event))
;;    (integerp (timer-event-timestamp event))
;;    (or (null (timer-event-user-data event))
;;        (typep (timer-event-user-data event) 'list))))

;; Command events
(defstruct (command-event (:constructor make-command-event))
  (name (error "Command name required") :type keyword)
  (args nil)
  (source nil)
  (timestamp (get-internal-real-time) :type integer))

;; (defmethod command-event-p ((event command-event))
;;   "Check if EVENT is a valid command-event structure."
;;   (and
;;    (keywordp (command-event-name event))
;;    (or (null (command-event-args event))
;;        (typep (command-event-args event) 'list))
;;    (or (null (command-event-source event))
;;        (typep (command-event-source event) 'component))))

;; Event utility functions
(defun consume-event (event)
  "Mark an event as consumed to prevent further processing"
  (etypecase event
    (key-event (setf (key-event-consumed-p event) t))
    (mouse-event (setf (mouse-event-consumed-p event) t))
    (focus-event (setf (focus-event-consumed-p event) t)))
  event)

(defun stop-propagation (event)
  "Generic function to stop event propagation."
  (typecase event
    (ui-event (ui-event-stop-propagation event))
    (key-event (setf (key-event-consumed-p event) t))
    (mouse-event (setf (mouse-event-consumed-p event) t))
    (t (log-warn "Unable to stop propagation of unknown event type: ~A" event)))
  event)

(defun prevent-default (event)
  "Marks event as having its default behavior prevented."
  ;; For now, we just use stop-propagation, but in a more complex system,
  ;; this would set a different flag to only prevent the default action
  ;; while still allowing propagation
  (stop-propagation event))

;; Helper function
(defun has-modifier-p (event modifier-keyword)
  "Checks if an event (like key-event or mouse-event) has a specific modifier."
  (let ((mods (cond ((key-event-p event) (key-event-modifiers event))
                    ((mouse-event-p event) (mouse-event-modifiers event))
                    (t nil))))
    (member modifier-keyword mods)))

(defun normalize-focus-event (platform-event)
  "Converts platform-specific focus event to a standardized focus-event.
   PLATFORM-EVENT: The raw event from the platform layer."
  ;; Implementation depends on platform-specific event structure
  ;; This is a generic implementation that assumes a minimal interface
  (let ((type (or (getf platform-event :type) :focus-in))
        (target (or (getf platform-event :target) nil))
        (source (getf platform-event :source)))

    (make-focus-event :type type
                      :target target
                      :source source)))

(defun convert-list-to-event (list-event)
  "Converts a list-format event to the appropriate struct format."
  (let ((event-type (first list-event)))
    (case event-type
      (:key-event
       (let* ((key (getf (rest list-event) :key))
              (modifiers (getf (rest list-event) :modifiers '())))
         (make-key-event
          :type :key-down ; Default for list format
          :key key
          :modifiers modifiers)))

      (:mouse-event
       (let* ((button (getf (rest list-event) :button))
              (x (getf (rest list-event) :x 0))
              (y (getf (rest list-event) :y 0))
              (modifiers (getf (rest list-event) :modifiers '())))
         (make-mouse-event
          :type :mouse-down ; Default for list format
          :x x
          :y y
          :button button
          :modifiers modifiers)))

      (:focus-event
       (let* ((focus-type (getf (rest list-event) :type :focus-in))
              (target (getf (rest list-event) :target)))
         (make-focus-event
          :type focus-type
          :target target)))

      ;; Add more cases for other event types as needed

      ;; Fallback case for unknown event types
      (otherwise
       (log-warn "Unknown list event type: ~S" event-type)
       nil))))
