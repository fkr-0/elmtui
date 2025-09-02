;;; == elmtui/core/keymaps.lisp ==============================================
;;;  Title:  ELMTUI Keymap System – All-in-one implementation
;;;  Author:  flo (Germany’s Next Topcoder) & ChatGPT
;;;  Purpose: Provide keyboard-handling infrastructure (key objects,
;;;           keymaps, sequences, registry, default maps, event integration)
;;;           for any TUI/GUI built on ELMTUI.
;;;
;;;  Public API  (quick reference)
;;;  ------------------------------------------------------------------------
;;;   • (keymaps:initialise)                       ; bootstraps everything
;;;   • (keymaps:parse-key-string "C-x")           ; → NORMALIZED-KEY
;;;   • (keymaps:add-keybinding <keymap> ...)
;;;   • (keymaps:list-active-keybindings)          ; introspection
;;;   • (keymaps:process-key-event evt focus app)  ; main dispatcher
;;;   • *global-navigation-keymap* etc.            ; ready-made maps
;;;
;;;  File Outline  (ASCII sitemap)
;;;  ------------------------------------------------------------------------
;;;   0.  Package & utilities
;;;   1.  Normalised keys        – structs, parsing, helpers
;;;   2.  Keymaps                – struct, lookup, DSL (`DEFINE-KEYMAP`)
;;;   3.  Sequences              – multi-key support
;;;   4.  Registry & Contexts    – stacks, activation, lookup
;;;   5.  Defaults               – standard maps & actions
;;;   6.  Event Integration      – translate raw events to actions
;;;   7.  System Bootstrap       – single call to wire everything
;;;   8.  Introspection helpers  – list bindings for UI/help overlays
;;;
;;;  NOTE:  External subsystems (focus manager, async event loop, etc.)
;;;         are referenced but not re-implemented here – they must exist
;;;         in the encompassing ELMTUI project.
;;;
;;;  Keymap Dispatch Integration Guide
;;;  ------------------------------------------------------------------------
;;;  This section outlines how to integrate the keymap system with an
;;;  application's `update` function. The core idea is to translate raw
;;;  key events into application-specific messages or actions.
;;;
;;;  1. The `process-key-event` Function
;;;     - This is the main entry point. It takes a raw `key-event`, a
;;;       `focus-manager`, the application `state`, and a `dispatch-fn`.
;;;     - It normalizes the key event and looks up a binding in the
;;;       currently active contexts.
;;;
;;;  2. The `dispatch-fn`
;;;     - When a binding is found of type `:message`, its `target` (the
;;;       message payload) is passed to the `*dispatch-fn*`.
;;;     - In your application's main loop or update function, you must
;;;       bind `*dispatch-fn*` to a function that knows how to send
;;;       messages back into your application's update cycle (e.g., by
;;;       posting to a message queue).
;;;
;;;  3. Event Handling Flow & Bubbling/Capturing
;;;     - The keymap system uses a "context stack" (`*active-contexts*`).
;;;       The most recently activated context is checked first.
;;;     - Within a context, keymaps are checked in the order they were
;;;       added. If a context has a `parent`, its keymaps are checked
;;;       after the child's. This creates a natural bubbling effect from
;;;       the most specific (top of the stack) to the most general (bottom).
;;;
;;;     - **Bubbling (Default):** An event is looked up in the current
;;;       context. If not found, the lookup proceeds to the parent context,
;;;       and so on, up to the global context. The first match found wins.
;;;       This is the standard behavior of `lookup-binding`.
;;;
;;;     - **Capturing (Manual):** To implement capturing, a component would
;;;       need to intercept the key event *before* passing it to the standard
;;;       dispatcher. It could run `lookup-binding` against a specific,
;;;       high-priority context first. If a binding is found and handled,
;;;       the event processing stops, and the event is not passed down.
;;;
;;;     - **Delegation:** A component can choose not to handle an event and
;;;       instead pass it to another component or a parent. In the context
;;;       of this keymap system, this is achieved by simply not having a
;;;       matching binding for that key. The lookup will then naturally
;;;       "delegate" to the next keymap or context in the hierarchy.
;;;
;;;  Example Implementation in an `update` function:
;;;
;;;  (defun handle-key-event (app-instance key-event)
;;;    "This function is called from the main event loop."
;;;    (let ((focus-manager (app-get-focus-manager app-instance))
;;;          (app-state (app-get-state app-instance)))
;;;      ;; The dispatch function posts a message back to the app's queue.
;;;      (flet ((dispatch (msg)
;;;               (app-enqueue-message app-instance msg)))
;;;        (keymaps:process-key-event key-event focus-manager
;;;                                   :app-state app-state
;;;                                   :dispatch-fn #'dispatch))))
;;;
;;;  (defun my-app-update (msg state)
;;;    (match msg
;;;      ((list :key-event raw-event)
;;;       ;; The keymap system handles the event and might dispatch a new
;;;       ;; message (e.g., :quit, :focus-next) via the dispatch-fn.
;;;       ;; The return value of `process-key-event` indicates if the
;;;       ;; event was handled.
;;;       (let ((handled (handle-key-event *app* raw-event)))
;;;         (if handled
;;;             (values state nil) ; Event consumed, no further action
;;;             (values state nil)))) ; Or maybe pass to a default handler
;;;      ...))
;;;
;;; ==========================================================================

(uiop:define-package :elmtui.keymaps
  (:use :cl :alexandria :log4cl)
  (:nicknames :et.keymaps)
  (:import-from :elmtui.core.event-types
                #:key-event
                #:key-event-key
                #:key-event-modifiers)
  (:export
   ;; bootstrap
   #:initialise
   ;; key helpers
   #:parse-key-string
   #:key-event->normalized-key
   #:normalized-key->string
   #:normalized-key-key
   #:normalized-key-modifiers
   ;; keymap helpers
   #:define-keymap
   #:add-keybinding
   #:remove-keybinding
   ;; contexts
   #:define-keymap-context
   #:keymap!
   #:make-keymap-context
   #:add-keymap-to-context
   #:resolve-keymap-reference
   #:find-context
   #:keymap-context-parent
   #:keymap-context-keymaps
   #:keymap-context-name
   #:keymap-bindings
   #:keymap-context
   #:activate-context
   #:deactivate-context
   #:current-context
   #:lookup-binding
   #:lookup-binding-in
   #:lookup
   ;; event handling
   #:process-key-event
   #:*dispatch-fn*
   ;; default ready-made maps
   #:*global-navigation-keymap*
   #:*dialog-keymap*
   #:*form-keymap*
   #:*editor-keymap*
   #:*list-navigation-keymap*
   #:*global-keymap-context*
   #:*active-contexts*
   #:*contexts*
   #:*registry*
   ;; introspection
   #:list-active-keybindings))

(in-package :elmtui.keymaps)

;;; ------------------------------------------------------------------------
;;; 0.  General Utilities
;;; ------------------------------------------------------------------------
(defvar *registry* (make-hash-table :test 'eq))
(defvar *contexts* (make-hash-table :test 'eq))
(defvar *active-contexts* nil) ; stack (most recent first)
(defvar *global-keymap-context* nil "The root keymap context.")

(defvar *dispatch-fn* nil "Dynamically bound function for dispatching messages from keybindings.")
(declaim (special *dispatch-fn*))

(define-condition keymap-error (simple-error) ())

(defun kw (thing) (alexandria:make-keyword thing))

;;; ------------------------------------------------------------------------
;;; 1.  Normalised Keys
;;; ------------------------------------------------------------------------

(defparameter *modifier-canon*
  '((:control . :ctrl) (:ctrl . :ctrl)
    (:shift . :shift)
    (:meta . :alt)    (:option . :alt) (:alt . :alt)
    (:command . :cmd) (:cmd . :cmd)))

(defparameter *modifier-order* '(:alt :ctrl :cmd :shift))

(defun %canon (m) (or (cdr (assoc m *modifier-canon* :test #'eq)) m))
(defun %rank  (m) (or (position (%canon m) *modifier-order* :test #'eq)
                      most-positive-fixnum))
(defun %normalize-mods (mods)
  (sort (remove-duplicates (mapcar #'%canon mods) :test #'eq) #'< :key #'%rank))

(defstruct (normalized-key (:constructor make-nk (&key key modifiers)))
  (key :none  :type (or character keyword))
  (modifiers nil    :type list))

;;; ------------------------------------------------------------------------
;;; 3.  Sequences
;;; ------------------------------------------------------------------------

(defstruct key-sequence (keys nil :type list))
(defstruct sequence-state
  (current nil)
  (timer nil)
  (timeout 1000)                ; milliseconds
  (last-tick 0))                ; internal time units

(defgeneric normalized-key= (a b))
(defmethod normalized-key= ((a normalized-key) (b normalized-key))
  (and (eql (normalized-key-key a) (normalized-key-key b))
       (equal (%normalize-mods (normalized-key-modifiers a))
              (%normalize-mods (normalized-key-modifiers b)))))

(defun normalized-key->string (nk)
  (with-output-to-string (out)
    (let* ((mods (%normalize-mods (normalized-key-modifiers nk)))
           (k    (normalized-key-key nk))
           (key-str (etypecase k
                      (character (string-upcase k))
                      (keyword   (string-capitalize k)))))
      (loop for m in (sort (copy-list mods) #'string< :key #'string)
            for i from 0
            do (format out "~:[~;-~]~A" (> i 0) (string-capitalize m)))
      (when mods (princ "-" out))
      (princ key-str out))))

;;; --- parsing --------------------------------------------------------------

(defun %special-symbol (sym)
  "Map special key names to keywords.
E.g., :escape → :esc, :enter → :enter, etc.

If no special mapping exists, returns SYM unchanged."
  (case sym
    (:escape  :esc)
    (:enter   :enter)
    (:delete  :delete)
    (:backspace :backspace)
    (:tab     :tab)
    (:space   :space)
    (t sym)))

(defun parse-single-key-string (s)
  "Handle strings like \"C-x\" or \"Shift-F1\" (no spaces)."
  (let* ((parts (str:split "-" s))
         (mods  '())
         (raw   (string-downcase (car (last parts))))
         (sym   (kw raw))
         (key   (cond
                  ((= 1 (length raw)) (char raw 0))
                  (t (%special-symbol sym)))))
    (dolist (p (butlast parts))
      (push (cond ((member p '("C" "CTRL" "CONTROL") :test #'string=) :ctrl)
                  ((member p '("S" "SHIFT")          :test #'string=) :shift)
                  ((member p '("A" "M" "ALT" "META") :test #'string=) :alt)
                  ((member p '("CMD" "COMMAND")      :test #'string=) :cmd)
                  (t (kw p)))
            mods))
    (make-nk :key key :modifiers (%normalize-mods mods))))

(defun parse-key-string (s)
  (if (find #\Space s)            ; warn but still parse first token
      (parse-key-string (subseq s 0 (position #\Space s)))
      (parse-single-key-string s)))

;;; --- platform event → nk --------------------------------------------------

(defgeneric key-event->normalized-key (evt))
;; adapter must exist elsewhere; fallback to accept plist for testing
(defmethod key-event->normalized-key ((evt list))
  (make-nk :key (getf evt :key) :modifiers (%normalize-mods (getf evt :modifiers))))

(defmethod key-event->normalized-key ((evt key-event))
  (make-nk :key (key-event-key evt)
           :modifiers (%normalize-mods (key-event-modifiers evt))))

;;; ------------------------------------------------------------------------
;;; 2.  Keymap
;;; ------------------------------------------------------------------------

(defstruct (keymap (:constructor %make-keymap))
  (bindings (make-hash-table :test 'equal))
  (name     nil :type (or null symbol string)))

(defun make-keymap (&key name)
  (%make-keymap :name name))

(defgeneric lookup (km key)
  (:documentation "Return binding for KEY (NORMALIZED-KEY or KEY-SEQUENCE)."))

(defmethod lookup ((km keymap) (key normalized-key))
  "Return binding for a NORMALIZED-KEY."
  (gethash (normalized-key->string key) (keymap-bindings km)))

(defmethod lookup ((km keymap) (key key-sequence))
  "Return binding for a KEY-SEQUENCE."
  (let ((key-str (mapconcat #'normalized-key->string (key-sequence-keys key) " ")))
    (gethash key-str (keymap-bindings km))))

(defgeneric (setf lookup) (binding km key))

(defmethod (setf lookup) (binding (km keymap) (key normalized-key))
  (setf (gethash (normalized-key->string key) (keymap-bindings km)) binding))

(defmethod (setf lookup) (binding (km keymap) (key key-sequence))
  (let ((key-str (mapconcat #'normalized-key->string (key-sequence-keys key) " ")))
    (setf (gethash key-str (keymap-bindings km)) binding)))

(defun add-keybinding (km key-string &key type target description)
  (let* ((parts (str:split key-string " "))
         (key   (if (> (length parts) 1)
                    (make-key-sequence :keys (mapcar #'parse-key-string parts))
                    (parse-key-string key-string)))
         (bind  `(:type ,type :target ,target :description ,description)))
    (setf (lookup km key) bind)
    bind))

(defun remove-keybinding (km key-string)
  (let* ((parts (str:split key-string " "))
         (key-str (if (> (length parts) 1)
                      (mapconcat #'normalized-key->string (mapcar #'parse-key-string parts) " ")
                      (normalized-key->string (parse-key-string key-string)))))
    (remhash key-str (keymap-bindings km))))

;;; --- DSL ------------------------------------------------------------------

(defmacro define-keymap (var &body bindings)
  "Define a keymap VAR with BINDINGS.

Binds a keymap object to the symbol VAR and DOES NOT register it in *registry*. The
keymap object is returned as the value of the macro.
WARNING: VAR is not quoted, it is a symbol to be defined.

*registry*: A global hash table mapping keymap names (symbols) to keymap objects.
This allows keymaps to be referenced by name in contexts.

BINDINGS is a list of (KEY-STRING . PLIST) pairs, where KEY-STRING is a
string like \"C-x\" or \"Shift-F1\", and PLIST contains:
  :type        - either :action or :message
  :target      - function symbol (for :action) or message payload (for :message
                 e.g., '(:quit
  :description - human-readable description for help overlays
Example:
  (define-keymap *my-keymap*
    (\"C-x\" :type :action  :target 'my-action      :description \"Do something\")
    (\"F1\"  :type :message :target '(:show-help)   :description \"Show help\")
    (\"C-q\" :type :message :target '(:quit)        :description \"Quit application\")
    (\"C-c C-c\" :type :message :target '(:copy)    :description \"Copy selection\")
    (\"C-v\" :type :message :target '(:paste)       :description \"Paste from clipboard\")
    (\"Shift-Tab\" :type :message :target '(:focus-prev) :description \"Focus previous element\")
    (\"Tab\" :type :message :target '(:focus-next)  :description \"Focus next element\")
    (\"Up\"  :type :message :target '(:move-up)     :description \"Move up\")
    (\"Down\":type :message :target '(:move-down)   :description \"Move down\")
    (\"Enter\":type :message :target '(:activate)   :description \"Activate/Select\"))
 Returns the created keymap object."

  `(defparameter ,var
     (let ((km (make-keymap :name ',var)))
       ,@(loop for (key . plist) in bindings
               collect `(add-keybinding km ,key ,@plist))
       km)))
(defmacro keymap! (var &body bindings)
  "Define a keymap VAR with BINDINGS.

creates and returns a keymap object, does NOT bind it to VAR or register it.

*registry*: A global hash table mapping keymap names (symbols) to keymap objects.
This allows keymaps to be referenced by name in contexts.

BINDINGS is a list of (KEY-STRING . PLIST) pairs, where KEY-STRING is a
string like \"C-x\" or \"Shift-F1\", and PLIST contains:
  :type        - either :action or :message
  :target      - function symbol (for :action) or message payload (for :message
                 e.g., '(:quit
  :description - human-readable description for help overlays
Example:
  (keymap! :my-km
    (\"C-x\" :type :action  :target 'my-action      :description \"Do something\")
    (\"F1\"  :type :message :target '(:show-help)   :description \"Show help\")
    (\"C-q\" :type :message :target '(:quit)        :description \"Quit application\")
    (\"C-c C-c\" :type :message :target '(:copy)    :description \"Copy selection\")
    (\"C-v\" :type :message :target '(:paste)       :description \"Paste from clipboard\")
    (\"Shift-Tab\" :type :message :target '(:focus-prev) :description \"Focus previous element\")
    (\"Tab\" :type :message :target '(:focus-next)  :description \"Focus next element\")
    (\"Up\"  :type :message :target '(:move-up)     :description \"Move up\")
    (\"Down\":type :message :target '(:move-down)   :description \"Move down\")
    (\"Enter\":type :message :target '(:activate)   :description \"Activate/Select\"))
 Returns the created keymap object."
  `(let ((km (make-keymap :name ',var)))
     ,@(loop for (key . plist) in bindings
             collect `(add-keybinding km ,key ,@plist))
     km))


(defun seq= (a b)
  (and (= (length (key-sequence-keys a)) (length (key-sequence-keys b)))
       (every #'normalized-key= (key-sequence-keys a) (key-sequence-keys b))))

(defun seq-prefix-p (prefix full)
  (every #'normalized-key=
         (key-sequence-keys prefix)
         (subseq (key-sequence-keys full) 0 (length (key-sequence-keys prefix)))))

;;; ------------------------------------------------------------------------
;;; 4.  Registry  &  Context Stack
;;; ------------------------------------------------------------------------

(defstruct (keymap-context (:constructor %mk-ctx))  ; internal
  (name    nil :read-only t)
  (keymaps '()  :type list)
  (parent  nil  :type (or null keymap-context))
  (active  nil)
  (meta    nil))


(defun register-keymap (name km) (setf (gethash name *registry*) km))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun resolve-keymap-reference (ref)
    (etypecase ref
      (keymap ref)
      (symbol (gethash ref *registry*))))
  )

(defun make-keymap-context (&key name parent keymaps)
  (%mk-ctx :name name
           :parent parent
           :keymaps keymaps))

(defun add-keymap-to-context (context keymap)
  (pushnew (resolve-keymap-reference keymap) (keymap-context-keymaps context)))

(defun find-context (name)
  (gethash name *contexts*))

(defun define-keymap-context (name &key parent keymaps)
  "Creates and registers a keymap context.
- NAME: The keyword name for the context (e.g., :my-context).
- PARENT: The keyword name of the parent context (e.g., :global).
- KEYMAPS: A list of keymap names (e.g., '(:dialog :form)).
Returns the created context object.

  Example:
  (define-keymap-context :my-context
    :parent :global
    :keymaps '(:dialog :form))
If PARENT is not provided, the context will be a root context.
If KEYMAPS is not provided, the context will have no keymaps.
If a keymap name is not found in the registry, an error is raised."
  (let* ((parent-ctx (if parent
                         (or (find-context parent)
                             (error 'keymap-error
                                    :format-control "Parent context ~S not found."
                                    :format-arguments (list parent)))
                         nil))
         (resolved-k-maps (mapcar (lambda (ref)
                                    (or (resolve-keymap-reference ref)
                                        (error 'keymap-error
                                               :format-control "Keymap ~S not found."
                                               :format-arguments (list ref))))
                                  keymaps))
         (context (make-keymap-context :name name
                                       :parent parent-ctx
                                       :keymaps resolved-k-maps)))
    (setf (gethash name *contexts*) context)
    context))

(defun activate-context (ctx)
  (unless (member ctx *active-contexts*)
    (push ctx *active-contexts*) (setf (keymap-context-active ctx) t)))

(defun deactivate-context (ctx)
  (setf *active-contexts* (remove ctx *active-contexts*))
  (setf (keymap-context-active ctx) nil))

(defun current-context () (first *active-contexts*))

(defun %collect-keymaps (ctx)
  (reverse             ; inner → outer priority
   (loop for c = ctx then (keymap-context-parent c)
         while c
         append (mapcar #'resolve-keymap-reference (keymap-context-keymaps c)))))

(defun lookup-binding (nk)
  (loop for ctx in *active-contexts*
        for b = (loop for km in (%collect-keymaps ctx)
                      thereis (lookup km nk))
        when b return b))

(defun lookup-binding-in (context nk &key (include-parents t))
  "Lookup a binding starting at CONTEXT. If INCLUDE-PARENTS is true,
walk up parent contexts; otherwise only search CONTEXT's keymaps."
  (labels ((collect (ctx)
             (when ctx
               (or (loop for km in (%collect-keymaps ctx)
                         thereis (lookup km nk))
                   (and include-parents
                        (collect (keymap-context-parent ctx)))))))
    (collect context)))

;;; ------------------------------------------------------------------------
;;; 5.  Default Keymaps  &  Actions (stubs)
;;; ------------------------------------------------------------------------

(defun %dispatch-msg (msg app)
  "Dispatches a message using the dynamically bound *dispatch-fn*."
  (declare (ignore app))
  (if *dispatch-fn*
      (funcall *dispatch-fn* msg)
      (log-warn "Keymap dispatch function not configured. Dropping message: ~S" msg)))

(defun action-cancel  (app) (declare (ignore app)) (log-info "cancel"))
(defun action-confirm (app) (declare (ignore app)) (log-info "confirm"))
(defun action-help    (app) (declare (ignore app)) (log-info "help"))
(defun action-menu    (app) (declare (ignore app)) (log-info "menu"))

(define-keymap *global-navigation-keymap*
  ("F1"    :type :action  :target 'action-help   :description "Show Help")
  ("F10"   :type :action  :target 'action-menu   :description "Show Menu")
  ("Escape":type :action  :target 'action-cancel :description "Cancel / Back")
  ("C-q"   :type :message :target '(:quit)       :description "Quit"))

(define-keymap *dialog-keymap*
  ("Enter" :type :action  :target 'action-confirm :description "Confirm")
  ("Escape":type :action  :target 'action-cancel  :description "Cancel")
  ("Tab"   :type :message :target '(:focus-next)  :description "Next Field")
  ("S-Tab" :type :message :target '(:focus-prev)  :description "Prev Field"))

(define-keymap *form-keymap*
  ("Enter" :type :message :target '(:form-submit)   :description "Submit")
  ("Escape":type :message :target '(:form-cancel)   :description "Cancel")
  ("Tab"   :type :message :target '(:focus-next)    :description "Next")
  ("S-Tab" :type :message :target '(:focus-prev)    :description "Prev"))

(define-keymap *editor-keymap*
  ("C-a" :type :message :target '(:select-all) :description "Select All")
  ("C-c" :type :message :target '(:copy)       :description "Copy")
  ("C-v" :type :message :target '(:paste)      :description "Paste")
  ("C-x" :type :message :target '(:cut)        :description "Cut")
  ("C-z" :type :message :target '(:undo)       :description "Undo")
  ("C-y" :type :message :target '(:redo)       :description "Redo"))

(define-keymap *list-navigation-keymap*
  ("Up"      :type :message :target '(:select-prev)  :description "Up")
  ("Down"    :type :message :target '(:select-next)  :description "Down")
  ("Home"    :type :message :target '(:select-first) :description "First")
  ("End"     :type :message :target '(:select-last)  :description "Last")
  ("PageUp"  :type :message :target '(:page-up)      :description "PgUp")
  ("PageDown":type :message :target '(:page-down)    :description "PgDn")
  ("Enter"   :type :message :target '(:activate)     :description "Activate"))

(defun %register-defaults ()
  (register-keymap :global-navigation *global-navigation-keymap*)
  (register-keymap :dialog            *dialog-keymap*)
  (register-keymap :form              *form-keymap*)
  (register-keymap :editor            *editor-keymap*)
  (register-keymap :list-navigation   *list-navigation-keymap*)
  ;; create & activate a permanent global context
  (setf *global-keymap-context*
        (define-keymap-context :global-context :keymaps '(:global-navigation)))
  (activate-context *global-keymap-context*))


;;; ------------------------------------------------------------------------
;;; 6.  Event Integration
;;; ------------------------------------------------------------------------

(defvar *sequence-state* (make-sequence-state))

(defun %reset-seq () (setf (sequence-state-current *sequence-state*) nil))

(defun %now-ms ()
  (truncate (* 1000 (/ (coerce (get-internal-real-time) 'double-float)
                       internal-time-units-per-second))))

(defun %update-seq (nk)
  (let* ((now (%now-ms))
         (last (sequence-state-last-tick *sequence-state*))
         (expired (and (> last 0)
                       (> (- now last) (sequence-state-timeout *sequence-state*))))
         (curr (and (not expired) (sequence-state-current *sequence-state*)))
         (new-seq (make-key-sequence :keys (append (and curr (key-sequence-keys curr))
                                                  (list nk)))))
    (setf (sequence-state-last-tick *sequence-state*) now
          (sequence-state-current *sequence-state*) new-seq)
    new-seq))

(defun %handle-binding (binding app)
  (ecase (getf binding :type)
    (:action  (funcall (getf binding :target) app))
    (:message (%dispatch-msg (getf binding :target) app))))

(defun %maybe-handle-sequence (nk app)
  "Return T if event consumed. Uses string keys for sequence storage."
  (let* ((seq (%update-seq nk))
         (bind (lookup-binding seq)))
    (cond
      (bind (%handle-binding bind app) (%reset-seq) t)
      (t
       (let* ((seq-str (mapconcat #'normalized-key->string (key-sequence-keys seq) " "))
              (prefix (concatenate 'string seq-str " ")))
         (if (some (lambda (km)
                     (loop for k being the hash-keys of (keymap-bindings km)
                           thereis (and (stringp k)
                                        (> (length k) (length seq-str))
                                        (str:starts-with? prefix k))))
                   (mapcar #'resolve-keymap-reference (keymap-context-keymaps (current-context))))
             t
             (progn (%reset-seq) nil)))))))

(defun process-key-event (evt focus-manager &key app-state (handle-sequences t) dispatch-fn)
  "Main dispatcher – converts EVT to NORMALIZED-KEY, runs registry lookup.
   Binds *dispatch-fn* to DISPATCH-FN for the duration of the call."
  (declare (ignore focus-manager))       ; focus integration stays external
  (log-info "KEYMAPS>Processing key event: ~S" evt)
  (let ((nk (key-event->normalized-key evt)))
    (unless nk (return-from process-key-event nil))
    (log-info "KEYMAPS>Processing nkey event: ~S" nk)
    (let ((*dispatch-fn* dispatch-fn))
      (declare (special *dispatch-fn*))
      ;; 1) Focused component keymap (from app-state)
      (let* ((fm (and (listp app-state) (getf app-state :focus-manager)))
             (focused (and (listp fm) (or (getf fm :current-focus-id)
                                          (getf fm :current-focus))))
             (component-keymaps (and (listp app-state) (getf app-state :component-keymaps)))
             (km (and focused (assoc focused component-keymaps)))
             (ckm (and km (cdr km)))
             (cbind (and (typep ckm 'keymap) (lookup ckm nk))))
        (when cbind
          (%handle-binding cbind app-state)
          (return-from process-key-event t))

        ;; 2) Key sequences against global contexts
        (when (and handle-sequences (%maybe-handle-sequence nk app-state))
          (return-from process-key-event t))
        ;; 3) Global contexts, single key
        (let ((bind (lookup-binding nk)))
          (when bind (%handle-binding bind app-state) t))))))

;;; ------------------------------------------------------------------------
;;; 7.  System Bootstrap
;;; ------------------------------------------------------------------------

(defun initialise ()
  "Call once on application start."
  (log-info "ELMTUI.KEYMAPS initialising…")
  (setf *active-contexts* nil)
  (%register-defaults)
  t)

;;; ------------------------------------------------------------------------
;;; 8.  Introspection
;;; ------------------------------------------------------------------------
(defun mapconcat (fn lst sep)
  "Like CL:MAPCONCAT but works on lists of strings."
  (reduce (lambda (a b) (concatenate 'string a sep b)) lst :initial-value "" :key fn))

(defun list-active-keybindings ()
  "Return list of plists {:key … :description … :source-keymap …}"
  (loop for ctx in *active-contexts*
        append
        (loop for km in (%collect-keymaps ctx)
              append
              (loop for k being the hash-keys of (keymap-bindings km)
                      using (hash-value v)
                    collect (list :key (typecase k
                                         (string k)
                                         (normalized-key (normalized-key->string k))
                                         (list (mapconcat #'normalized-key->string k " "))
                                         (t (prin1-to-string k)))
                                  :description (getf v :description)
                                  :source (keymap-name km))))))

;;; == end/keymaps.lisp ======================================================
