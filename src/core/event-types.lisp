
;;; File: src/core/event-types.lisp
;;; Standardized Event Type Definitions
;;;===============================================================
(uiop:define-package :elmtui.core.event-types
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn)
  (:import-from :elmtui.core.conditions
                #:event-validation-error)
  (:import-from :cl-events.types
   ;; Re-export all UI/input event types from cl-events
   #:ui-event #:make-ui-event #:ui-event-p
   #:ui-event-type #:ui-event-target #:ui-event-timestamp
   #:ui-event-consumed-p #:ui-event-original-event

   #:key-event #:make-key-event #:key-event-p
   #:key-event-type #:key-event-key #:key-event-code
   #:key-event-char #:key-event-modifiers
   #:key-event-timestamp #:key-event-consumed-p

   #:mouse-event #:make-mouse-event #:mouse-event-p
   #:mouse-event-type #:mouse-event-x #:mouse-event-y
   #:mouse-event-button #:mouse-event-click-count
   #:mouse-event-delta-x #:mouse-event-delta-y
   #:mouse-event-modifiers #:mouse-event-timestamp
   #:mouse-event-consumed-p

   #:focus-event #:make-focus-event #:focus-event-p
   #:focus-event-type #:focus-event-target #:focus-event-source
   #:focus-event-timestamp #:focus-event-consumed-p

   #:consume-event #:prevent-default #:has-modifier-p)
  (:import-from :cl-events.protocols #:stop-propagation)
  (:export
   ;; Re-exported from cl-events.types
   #:ui-event #:make-ui-event #:ui-event-p
   #:ui-event-type #:ui-event-target #:ui-event-timestamp
   #:ui-event-consumed-p #:ui-event-original-event

   #:key-event #:make-key-event #:key-event-p
   #:key-event-type #:key-event-key #:key-event-code
   #:key-event-char #:key-event-modifiers
   #:key-event-timestamp #:key-event-consumed-p

   #:mouse-event #:make-mouse-event #:mouse-event-p
   #:mouse-event-type #:mouse-event-x #:mouse-event-y
   #:mouse-event-button #:mouse-event-click-count
   #:mouse-event-delta-x #:mouse-event-delta-y
   #:mouse-event-modifiers #:mouse-event-timestamp
   #:mouse-event-consumed-p

   #:focus-event #:make-focus-event #:focus-event-p
   #:focus-event-type #:focus-event-target #:focus-event-source
   #:focus-event-timestamp #:focus-event-consumed-p

   #:consume-event #:stop-propagation #:prevent-default #:has-modifier-p

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
   ;; Validation and normalization functions
   #:valid-key-event-p
   #:valid-mouse-event-p
   #:normalize-key-event
   #:normalize-mouse-event
   #:normalize-focus-event
   #:convert-list-to-event
   ;; Key constants
   #:key-left #:key-right #:key-up #:key-down
   #:key-home #:key-end #:key-page-up #:key-page-down
   #:key-backspace #:key-delete #:key-insert #:key-enter
   #:key-escape #:key-tab #:key-space
   #:key-f1 #:key-f2 #:key-f3 #:key-f4
   #:key-f5 #:key-f6 #:key-f7 #:key-f8
   #:key-f9 #:key-f10 #:key-f11 #:key-f12
   #:key-0 #:key-1 #:key-2 #:key-3 #:key-4
   #:key-5 #:key-6 #:key-7 #:key-8 #:key-9
   #:key-a #:key-b #:key-c #:key-d #:key-e #:key-f
   #:key-g #:key-h #:key-i #:key-j #:key-k #:key-l
   #:key-m #:key-n #:key-o #:key-p #:key-q #:key-r
   #:key-s #:key-t #:key-u #:key-v #:key-w #:key-x
   #:key-y #:key-z
   #:key-minus #:key-equals
   #:key-left-bracket #:key-right-bracket
   #:key-semicolon #:key-quote
   #:key-comma #:key-period #:key-slash))

(in-package :elmtui.core.event-types)

;;;-----------------------------------------------------------------------------
;;; elmtui-specific Event Types (not in cl-events.types)
;;;-----------------------------------------------------------------------------

;; Window events
(defstruct (window-event (:constructor make-window-event))
  (type (error "Type required") :type keyword) ; :resize, :minimize, :maximize
  (width 0 :type integer)
  (height 0 :type integer)
  (timestamp (get-internal-real-time) :type integer))

;; System events
(defstruct (system-event (:constructor make-system-event))
  (type (error "Type required") :type keyword) ; :shutdown, :suspend, :resume
  (data nil)
  (timestamp (get-internal-real-time) :type integer))

;; Timer events
(defstruct (timer-event (:constructor make-timer-event))
  (id (error "Timer ID required"))
  (timestamp (get-internal-real-time) :type integer)
  (user-data nil))

;; Command events
(defstruct (command-event (:constructor make-command-event))
  (name (error "Command name required") :type keyword)
  (args nil)
  (source nil)
  (timestamp (get-internal-real-time) :type integer))

;;;-----------------------------------------------------------------------------
;;; Validation and normalization functions
;;;-----------------------------------------------------------------------------

(defun valid-key-event-p (event)
  "Returns true if EVENT is a valid key-event structure."
  (and (key-event-p event)
       (member (key-event-type event) '(:key-down :key-up :key-press))
       (or (characterp (key-event-key event))
           (keywordp (key-event-key event))
           (null (key-event-key event)))))

(defun valid-mouse-event-p (event)
  "Returns true if EVENT is a valid mouse-event structure."
  (and (mouse-event-p event)
       (member (mouse-event-type event)
               '(:mouse-down :mouse-up :mouse-move :mouse-wheel :mouse-enter :mouse-leave))))

(defun normalize-key-event (platform-event)
  "Converts platform-specific keyboard event to a standardized key-event.
   PLATFORM-EVENT: The raw event from the platform layer."
  (let ((type (or (getf platform-event :type) :key-down))
        (key (or (getf platform-event :key)
                 (getf platform-event :character)))
        (code (getf platform-event :code))
        (mods (getf platform-event :modifiers)))
    (let ((normalized-mods
            (loop for mod in (if (listp mods) mods (list mods))
                  when mod
                    collect (if (keywordp mod) mod (intern (string-upcase mod) :keyword)))))
      (make-key-event :type type
                      :key key
                      :code code
                      :modifiers normalized-mods))))

(defun normalize-mouse-event (platform-event)
  "Converts platform-specific mouse event to a standardized mouse-event.
   PLATFORM-EVENT: The raw event from the platform layer."
  (let ((type (or (getf platform-event :type) :mouse-move))
        (x (or (getf platform-event :x) 0))
        (y (or (getf platform-event :y) 0))
        (button (getf platform-event :button))
        (click-count (or (getf platform-event :click-count) 1))
        (delta-x (or (getf platform-event :delta-x) 0))
        (delta-y (or (getf platform-event :delta-y) 0))
        (mods (getf platform-event :modifiers)))
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

(defun normalize-focus-event (platform-event)
  "Converts platform-specific focus event to a standardized focus-event.
   PLATFORM-EVENT: The raw event from the platform layer."
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
          :type :key-down
          :key key
          :modifiers modifiers)))

      (:mouse-event
       (let* ((button (getf (rest list-event) :button))
              (x (getf (rest list-event) :x 0))
              (y (getf (rest list-event) :y 0))
              (modifiers (getf (rest list-event) :modifiers '())))
         (make-mouse-event
          :type :mouse-down
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

      (otherwise
       (log-warn "Unknown list event type: ~S" event-type)
       nil))))

;;; ---------------------------------------------------------------------------
;;; Key-constant DSL
;;; ---------------------------------------------------------------------------

(defmacro define-key-constants (&body specs)
  "Define KEY-EVENT constants in bulk.
   Each SPEC is (symbol keyword) – e.g.  (key-left :arrow-left).
   Constants are created at read-time so they're available for #. forms."
  `(eval-when (:compile-toplevel :load-toplevel :execute)
     ,@(loop for (sym kw) in specs
             collect `(defconstant ,sym ,kw
                        ,(format nil "Key constant generated by DEFINE-KEY-CONSTANTS: ~A" kw)))))

;;; ---------------------------------------------------------------------------
;;; 72 most important keys (one call, readable table layout)
;;; ---------------------------------------------------------------------------

(define-key-constants
    ;; ── Cursor & navigation ──────────────────────────────────────────────
    (key-left          :arrow-left)     (key-right        :arrow-right)
  (key-up            :arrow-up)       (key-down         :arrow-down)
  (key-home          :home)           (key-end          :end)
  (key-page-up       :page-up)        (key-page-down    :page-down)

  ;; ── Editing / control ───────────────────────────────────────────────
  (key-backspace     :backspace)      (key-delete       :delete)
  (key-insert        :insert)         (key-enter        :enter)
  (key-escape        :escape)         (key-tab          :tab)
  (key-space         :space)

  ;; ── Function keys ───────────────────────────────────────────────────
  (key-f1  :f1)  (key-f2  :f2)  (key-f3  :f3)  (key-f4  :f4)
  (key-f5  :f5)  (key-f6  :f6)  (key-f7  :f7)  (key-f8  :f8)
  (key-f9  :f9)  (key-f10 :f10) (key-f11 :f11) (key-f12 :f12)

  ;; ── Digits ──────────────────────────────────────────────────────────
  (key-0 :0) (key-1 :1) (key-2 :2) (key-3 :3) (key-4 :4)
  (key-5 :5) (key-6 :6) (key-7 :7) (key-8 :8) (key-9 :9)

  ;; ── Letters (A-Z) ───────────────────────────────────────────────────
  (key-a :a)  (key-b :b)  (key-c :c)  (key-d :d)  (key-e :e)  (key-f :f)
  (key-g :g)  (key-h :h)  (key-i :i)  (key-j :j)  (key-k :k)  (key-l :l)
  (key-m :m)  (key-n :n)  (key-o :o)  (key-p :p)  (key-q :q)  (key-r :r)
  (key-s :s)  (key-t :t)  (key-u :u)  (key-v :v)  (key-w :w)  (key-x :x)
  (key-y :y)  (key-z :z)

  ;; ── Core punctuation ────────────────────────────────────────────────
  (key-minus          :minus)         (key-equals      :equals)
  (key-left-bracket   :left-bracket)  (key-right-bracket :right-bracket)
  (key-semicolon      :semicolon)     (key-quote       :quote)
  (key-comma          :comma)         (key-period      :period)
  (key-slash          :slash))
