;;; -*- Mode: Lisp -*-
;;; ---------------------------------------------------------------------------
;;;  update-dsl.lisp
;;; ---------------------------------------------------------------------------
;;;  Elm-style update/command DSL for Elmtui
;;;
;;;  State Integration:
;;;    This DSL is designed to work with Elmtui's tea-state API, which uses
;;;    the `application-state` struct (see [`src/tea-state/state.lisp`](src/tea-state/state.lisp:31)).
;;;    State is NOT assumed to be a plist; it is typically an application-state object
;;;    with hash-table data, transaction history, observer support, and thread safety.
;;;
;;;    To access or mutate state, always use the tea-state API:
;;;      - Reading:   (state-ref STATE KEY) or (get-path PATH STATE)
;;;      - Writing:   (setf (state-ref STATE KEY) VALUE) or (state-set STATE KEY VALUE)
;;;      - Transactions: (with-transaction (STATE :name ...) ...)
;;;      - Patches:   (apply-patches STATE PATCHES)
;;;      - Undo/Redo: (undo STATE), (redo STATE)
;;;      - Observers: (add-observer STATE KEY FN)
;;;
;;;    See [`src/tea-state/api.lisp`](src/tea-state/api.lisp:1) for the exported API.
;;;    See [`src/tea-state/transactions.lisp`](src/tea-state/transactions.lisp:47) for transaction macros.
;;;
;;;  DSL Usage:
;;;    - All update functions should accept and return application-state objects.
;;;    - Patch and command helpers operate on application-state, not plists.
;;;    - To merge patches, use (apply-patches STATE PATCHES) for atomic updates.
;;;    - Command runners should use tea-state transactions for side-effect safety.
;;;
;;;  Example Integration:
;;;    (defun my-update (state msg)
;;;      (with-transaction (state :name :my-update)
;;;        (cond
;;;          ((eq msg :inc) (state-set state :counter (+ (state-ref state :counter 0) 1)))
;;;          ((eq msg :reset) (state-set state :counter 0))
;;;          (t state))))
;;;
;;;    ;; To process a batch of patches:
;;;    (apply-patches state '((:counter 42) (:flag t)))
;;;
;;;    ;; To observe changes:
;;;    (add-observer state :counter (lambda (old new) (format t "Counter changed: ~A -> ~A~%" old new)))
;;;
;;;    ;; Undo/redo:
;;;    (undo state)
;;;    (redo state)
;;;
;;;  Exposed public API
;;;  ------------------
;;;    (with-cycle (ctx initial-app-state &key component-path) . body)
;;;        → VALUES new-app-state  patches  commands
;;;
;;;    State accessors & mutators (via generics)
;;;       (state>  path        &optional default)
;;;       (cstate> slot        &optional default)
;;;       (setf (state>  …)  newval)
;;;       (setf (cstate> …)  newval)
;;;    These macros use generic functions:
;;;       (state-get STATE PATH &optional DEFAULT)
;;;       (state-set STATE PATH VALUE)
;;;       (state-patch STATE PATCHES)
;;;       (state-observe STATE KEY FN)
;;;    Default methods support plists; tea-state/api.lisp provides application-state specializations.
;;;
;;;    Command & message helpers
;;;       (cmd> thunk  &key then err)
;;;       (msg> payload)                      ; thin cmd> wrapper
;;;
;;;    Cycle delimiters
;;;       (>>)           ; harvest & clear patches / commands mid-update
;;;       (<< [path])    ; switch component context + clear accumulators
;;;
;;;  NOTE  ▸  This DSL is drop-in friendly and does not depend on the rest of **elmtui**
;;;            beyond the expectation of an application-state object.
;;; ---------------------------------------------------------------------------


(uiop:define-package #:elmtui.update-dsl.api
                                        ; (:use #:cl #:sb-mop #:sb-thread #:elmtui.tea-state.api)
                                        ; (:import-from #:elmtui.tea-state.state
                                        ;               #:application-state
                                        ;               #:application-state-p
                                        ;               #:application-state-data
                                        ;               #:application-state-lock
                                        ;               #:application-state-log
                                        ;               #:application-state-history
                                        ;               #:application-state-undone
                                        ;               #:application-state-observers
                                        ;               #:state-ref)
                                        ; (:import-from #:elmtui.tea-state.transactions
                                        ;               #:with-transaction
                                        ;               #:apply-patches
                                        ;               #:undo
                                        ;               #:redo)
                                        ; (:import-from #:elmtui.tea-state.observers
                                        ;               #:add-observer
                                        ;               #:remove-observer)
                                        ; (:import-from #:alexandria
                                        ;               #:when-let)
  (:use #:cl)
  (:import-from :elmtui.utils #:as #:struct->plist #:copy-hash-table)
  (:import-from :log4cl #:log-info)
  (:export
    #:to-list
    #:state-get
    #:state-set
    #:state-observe
    #:state-patch
    #:patch
    #:command
    #:with-read-only-cycle
    #:cycle-context
    #:with-cycle
    #:state>
    #:as
    #:setfn
    #:cstate>
    #:cmd>
    #:msg>
    #:>>
    #:<<))

(in-package #:elmtui.update-dsl.api)

;;;; ---------------------------
;;;;  Data Model
;;;; ---------------------------

(defstruct patch
  "Struct: PATCH
Arguments:
  PATH (list) — The key path in the state to be patched.
  VALUE (t)   — The new value to set at PATH.
Returns: PATCH struct.
Type: (list, t) => PATCH
Side-effects: None (pure data struct).
"
  (path nil :type list)
  (value nil :type t))

(defmethod to-list ((p patch))
  "Convert PATCH struct to a list of (path value)."
  (list (patch-path p) (patch-value p)))

(defgeneric state-observe (state key fn)
  (:documentation
    "Generic function to observe changes in STATE at KEY.
   Calls FN with old and new values when KEY changes.
   STATE can be an application-state or a plist.

  ARGS:
    STATE - The application state or plist to observe.
    KEY   - The key to observe for changes.
    FN    - A function of two arguments (old-value new-value) called on changes.
  RETURNS:
    Updated STATE with the observer registered (if supported).
  SIDE-EFFECTS:
    Registers FN to be called on changes to KEY in STATE.
  NOTE:
    This is a no-op for plist states, as they do not support observers.
    Application-state support must be implemented separately.
    FN should handle its own errors to avoid disrupting state changes.

    EXAMPLE:
        (state-observe app-state :counter
(lambda (old new)
                         (format t \"Counter changed from ~A to ~A~%\" old new)))
    => Registers an observer on :counter in app-state. When :counter changes,
       the lambda is called with the old and new values, this happens by nature
       asynchronously, as soon as the patch is applied and the state updated.
       The handler FN is executed asynchronously and may enqueue further messages
       into the event loop.")
  (:method ((state list) key fn)
    "No-op for plist STATE, as plists do not support observers."
    (declare (ignore key fn))
    state)

  (:method ((state t) key fn)
    (declare (ignore key fn))
    (error "state-observe not implemented for application-state ~A: ~A yet." (type-of state) state)))

(defgeneric state-get (state path &optional default)
  (:documentation
    "Generic function to get a value from STATE at PATH.
   If PATH is not found, returns DEFAULT if provided, otherwise NIL.
   STATE can be an application-state or a plist.")
  (:method ((state list) (path list) &optional default)
    "Get value from a plist STATE at PATH, returning DEFAULT if not found."
    (if (null path)
      state
      (let ((value (getf state (car path) default)))
        (if (= 1 (length path))
          (or value default)
          (if (and value (or (listp value) (hash-table-p value)))
            (state-get value (cdr path) default)
            default)))))
  (:method ((state list) path &optional default)
    (state-get state (list path) default))
  (:method ((state hash-table) (path list) &optional default)
    "Get value from a hash-table STATE at PATH, returning DEFAULT if not found."
    (if (null path)
      state
      (let ((value (gethash (car path) state default)))
        (if (= 1 (length path))
          (or value default)
          (if (and value (or (listp value) (hash-table-p value)))
            (state-get value (cdr path) default)
            default)))))
  (:method ((state hash-table) path &optional default)
    (state-get state (list path) default))
  (:method ((state t) path &optional default)
    (declare (ignore default))
    (error 'elmtui.core.errors:state-error
      :operation "get"
      :path path
      :state-type (type-of state)
      :context (format nil "State value: ~A" state)
      :suggestions (elmtui.core.errors:suggest-fixes
                     "Use hash-table or plist states with state-get"
                     "For application-state objects, use tea-state:get-path instead"
                     "Ensure state is properly initialized before accessing"
                     (when (null state)
                       "The state object is nil - did you forget to initialize it?")
                     (when (and path (listp path) (not (keywordp (first path))))
                       "State paths should start with keywords, e.g., '(:counter) not '(counter)")))))

;; == elmtui.state/setf-plist-path.lisp ==
(defgeneric state-set (state path value)
  (:documentation
    "Functional update: returns a new plist with VALUE set at PATH in STATE.
    PATH is a list of keys; intermediate nodes are plists as well.")

  ;; Recursive path-based update
  (:method ((state list) (path list) value)
    (let ((new-state (if state (copy-list state) '())))
      (if (= 1 (length path))
        (progn (setf (getf new-state (car path)) value) new-state)
        (let* ((key (car path))
                (child (getf new-state key))
                (new-child (state-set child (cdr path) value)))
          (setf (getf new-state key) new-child)
          new-state))))

  ;; Shortcut for path = single key
  (:method ((state list) path value)
    (state-set state (list path) value))

  ;; Hash-table support
  (:method ((state hash-table) (path list) value)
    (let ((new-state (copy-hash-table state)))
      (if (= 1 (length path))
        (progn (setf (gethash (car path) new-state) value) new-state)
        (let* ((key (car path))
                (child (gethash key new-state))
                (new-child (state-set child (cdr path) value)))
          (setf (gethash key new-state) new-child)
          new-state))))

  ;; Shortcut for path = single key
  (:method ((state hash-table) path value)
    (state-set state (list path) value))

  ;; Error fallback
  (:method ((state t) path value)
    (error 'elmtui.core.errors:state-error
      :operation "set"
      :path path
      :state-type (type-of state)
      :context (format nil "Attempted to set value: ~A" value)
      :suggestions (elmtui.core.errors:suggest-fixes
                     "Use state-set with hash-table or plist states only"
                     "For application-state objects, use tea-state:state-set instead"
                     "Ensure the state object supports functional updates"
                     (when (null state)
                       "The state object is nil - did you forget to initialize it?")
                     (when (and path (listp path) (not (keywordp (first path))))
                       "State paths should start with keywords, e.g., '(:counter) not '(counter)")))))
;; == end/setf-plist-path.lisp ==


;; (let (current-sub-state (getf state (car path)))
;;   (if (= 1 (length path))
;;     (setf (getf current-sub-state) value))
;; (if (null current-sub-state))

;;   (if (= 1 (length path))
;;     (setf (getf state (car path)) value)
;;     (let ((cnt (getf state (car path) nil)))
;;       (if (null cnt)
;;         (setf (getf state (car path)) (list (state-set nil (cdr path) value)))
;;         (setf (getf state (car path)) (state-set cnt (cdr path) value)))))
;;   state)

;; (defgeneric state-set (state path value)
;;   (:documentation
;;     "Generic function to set a value in STATE at PATH.
;;    Returns the updated STATE. If PATH is not found, it is created.
;;    STATE can be an application-state or a plist.")
;;   (:method ((state list) (path list) value)
;;     "Set VALUE in a plist STATE at PATH, returning the updated state."
;;     (let ((current (getf state (car path))))
;;       (if (= 1 (length path))
;;         (setf (getf state (car path)) value)
;;         (let ((cnt (getf state (car path) nil)))
;;           (if (null cnt)
;;             (setf (getf state (car path)) (list (state-set nil (cdr path) value)))
;;             (setf (getf state (car path)) (state-set cnt (cdr path) value))))
;;         state)
;;       state))
;;   (:method ((state list) path value)
;;     (state-set state (list path) value))
;;   (:method ((state t) path value)
;;     (declare (ignore path value))
;;     (error "state-set not implemented for application-state ~A: ~A yet." (type-of state) state)))

;; ((state elmtui.tea-state.state:application-state) (path t) &optional default)
(defmethod elmtui.utils:as ((enforced-type (eql :plist)) (obj patch) &key default err &allow-other-keys)
  "Convert a PATCH struct to a plist for compatibility with legacy code.
   Returns a plist of the form (:path PATH :value VALUE).
   If DEFAULT is provided, returns it if OBJ is not a PATCH."
  (declare (ignore default err))
  (list :path (patch-path obj) :value (patch-value obj)))

;; (as 'plist (multiple-value-bind (st patches cmds)
;;     (with-cycle (ctx (list))
;;       (setf (state> :foo) 42)
;;       ;; (is (= (state> :foo) 42))
;;       )
;;     (first patches)))
(defstruct command
  "Struct: COMMAND
Arguments:
  THUNK (function) — The function to execute.
  THEN  (function|null) — Success continuation.
  ERR   (function|null) — Error continuation.
  WHO   (list|null) — Component path producing the command.
Returns: COMMAND struct.
Type: (function, function|null, function|null, list|null) => COMMAND
Side-effects: None (pure data struct).
"
  (thunk nil :type function)
  (then  nil :type (or function null))
  (err   nil :type (or function null))
  (who   nil :type (or list null)))

(defstruct cycle-context
  "Struct: CYCLE-CONTEXT
Arguments:
  APP-STATE (t) — The whole application state.
  COMPONENT-PATH (list|null) — Current component path.
  PATCHES (list) — List of PATCH structs.
  COMMANDS (list) — List of COMMAND structs.
Returns: CYCLE-CONTEXT struct.
Type: (t, list|null, list, list) => CYCLE-CONTEXT
Side-effects: None (pure data struct).
"
  (app-state      nil   :type t)
  (component-path nil   :type (or list null))
  (patches        '()   :type list)
  (commands       '()   :type list))

(defun context-path-sanitizer (ctx path &optional (component nil))
  "Sanitize PATH by removing nils and ensuring it is a list.
   If COMPONENT is provided, prepend it to the path."
  (when (null path)
    (error "Path cannot be nil in context-path-sanitizer."))
  (when (not (listp path))
    (setf path (list path)))  ; ensure path is a list
  (let* ((sanitized (remove nil path)))
    (if component
      (append (cycle-context-component-path ctx) sanitized)
      sanitized)))

;;;; ---------------------------
;;;;  Helper Macros
;;;; ---------------------------
(defmacro with-cycle ((ctx-sym initial-app-state &key component-path)
                       &body body)
  "Evaluate BODY with a fresh CYCLE-CONTEXT threaded through.
   Returns 3 values: new-state, patches, commands.

   CTX-SYM is a symbol for the cycle context variable.
   INITIAL-APP-STATE is the initial application state to use.
   COMPONENT-PATH is an optional path for the component context.
   If COMPONENT-PATH is a list, it is used as-is; otherwise, it is wrapped in a list.
   The context is created with the given initial state and component path.
   The BODY is evaluated with the context bound to CTX-SYM, allowing access to the update-dsl
   functions like (state>), (cstate>), (cmd>), etc.

   The body is expected to use the context to mutate state and register commands.
   The macro returns three values:
     1. The updated application state after evaluating BODY.
     2. A list of patches recorded during the update.
     3. A list of commands registered during the update.
   The application state is the final state after all mutations, and is exactly the
   same by reference as the one passed in INITIAL-APP-STATE.

   EXAMPLE USAGE:
     (with-cycle (ctx initial-state :component-path '(:my-component))
       (setf (state> :counter) (+ (state> :counter 0) 1))
       (cmd> (lambda () (format t \"Counter incremented~%\"))))
     => Returns three values: new-state, patches, commands."
  (let ((ctx-var (gensym "CTX")))              ; one real lexical var
    `(let ((,ctx-var (make-cycle-context
                       :app-state      ,initial-app-state
                       :component-path (if (listp ,component-path)
                                         (if (eq :components (car ,component-path))
                                           ,component-path
                                           (progn
                                             (push :components ,component-path)
                                             ,component-path))
                                         (list :components ,component-path)))))
       (log-info "Cycle context: ~A Component-Path" ,ctx-var)
       ;; Alias BOTH symbols to that one var
       (symbol-macrolet ((,ctx-sym ,ctx-var)   ; pleasant short name for caller
                          (elmtui.update-dsl.api::ctx ,ctx-var))
         (values
           (progn ,@body
             (cycle-context-app-state ,ctx-var))
           (mapcar #'to-list
             (nreverse (cycle-context-patches  ,ctx-var)))
           (nreverse (cycle-context-commands ,ctx-var)))))))

(defmacro with-read-only-cycle ((ctx-sym initial-app-state &key component-path)
                                 &body body)
  "Evaluate BODY with a fresh CYCLE-CONTEXT in read-only mode.
   Returns the updated application state after evaluating BODY.
   This is similar to `with-cycle`, but does not allow mutations or command registration."
  (let ((ctx-var (gensym "CTX")))              ; one real lexical var
    `(let ((,ctx-var (make-cycle-context
                       :app-state      ,initial-app-state
                       :component-path (if (listp ,component-path)
                                         ,component-path
                                         (list ,component-path)))))
       (symbol-macrolet ((,ctx-sym ,ctx-var)   ; pleasant short name for caller
                          (elmtui.update-dsl.api::ctx ,ctx-var))
         (progn ,@body
           (cycle-context-app-state ,ctx-var))))))


(defmethod state-patch ((state list) patches)
  "Apply a list of PATCH objects to STATE using state-patch generic.
   Returns the updated state. PATCHES may be PATCH structs or (path value) pairs."
  (reduce (lambda (s p) (state-set s (patch-path p) (patch-value p)))
    patches
    :initial-value state))


(defmethod state-patch ((state t) patches)
  "Apply a list of PATCH objects to STATE using state-patch generic.
   Returns the updated state. PATCHES may be PATCH structs or (path value) pairs."
  (declare (ignore patches))
  (error "state-patch not implemented for application-state ~A: ~A yet." (type-of state) state))

(defmacro state> (path &optional default)
  "Access global app state at PATH, optionally providing DEFAULT."
  `(state-get (cycle-context-app-state ctx)
     (context-path-sanitizer ctx ,path nil) ,default))

(defun compute-cstate-path (slot)
  "Compute the full component path for SLOT, ensuring the :state prefix.
Handles list arguments that may already include :state and returns a fresh list." 
  (cond
    ((and (listp slot) (eq (first slot) :state))
      slot)
    ((listp slot)
      (append '(:state) slot))
    (t
      (list :state slot))))

(defmacro cstate> (slot &optional default)
  "Access component-scoped state at SLOT, optionally providing DEFAULT."
  `(get-component-state ctx
     (elmtui.update-dsl.api::compute-cstate-path ,slot)
     ,default))

;; Some tests build simplified hash-table states where each key is the
;; complete path (e.g., '(:components :rv :state :width)) instead of a
;; nested tree.  Detect and support those so cstate> can interoperate.
(defun nested-hash-state-p (state component-path)
  (and (hash-table-p state)
    (consp component-path)
    (multiple-value-bind (child present)
      (gethash (first component-path) state)
      (and present (hash-table-p child)))))

(defun maybe-strip-components-prefix (path)
  (when (and path (eq (first path) :components))
    (rest path)))

(defun %flat-hash-get (state path)
  (multiple-value-bind (value presentp) (gethash path state)
    (if presentp
      (values value t path)
      (let ((alt (maybe-strip-components-prefix path)))
        (if alt
          (multiple-value-bind (alt-value alt-presentp) (gethash alt state)
            (values alt-value alt-presentp (if alt-presentp alt path)))
          (values nil nil path))))))

;;; --- writer (setf-expander) ---
(defsetf state> (path &optional default) (newval)
  "Set PATH in the current cycle context and record a patch."
  ;; ignore DEFAULT when storing — it is only for reading
  `(let ((val ,(or newval default)))
     ;; record the mutation for diffing -- adjust helper name if needed
     (push (make-patch :path (context-path-sanitizer ctx ,path nil) :value val)
       (cycle-context-patches ctx))
     (setf
       (cycle-context-app-state ctx)
       (state-set (cycle-context-app-state ctx)
         (context-path-sanitizer ctx ,path nil) val))))

;;; ===============================================================

;; (defmacro cstate> (slot &optional default)
;;   `(let* ((comp-path (cycle-context-component-path ctx))
;;           (full-path (append comp-path (list ,slot))))
;;      (get-component-state ctx full-path ,default)))

(defsetf cstate> (slot &optional default) (newval)
  "Set SLOT in *component* state and record a patch."
  `(let* ((path (elmtui.update-dsl.api::compute-cstate-path ,slot))
           (val ,(or newval default)))
     (set-component-state ctx path val)))

;;;; ---------------------------
;;;;  State Helpers
;;;; ---------------------------

(defun get-component-state (ctx path &optional default)
  "Function: GET-COMPONENT-STATE
Arguments:
  CTX (cycle-context) — The cycle context.
  PATH (list) — Key path in app state.
  DEFAULT (t, optional) — Default value if not present.
Returns: Value at PATH or DEFAULT.
Type: (cycle-context, list, t) => t
Side-effects: None (pure accessor).
"
  ;; Returns value at PATH in app-state, or DEFAULT if not present.
  (let* ((app-state (cycle-context-app-state ctx))
          (component-path (cycle-context-component-path ctx))
          (full-path (context-path-sanitizer ctx path t)))
    (cond
      ((hash-table-p app-state)
        (multiple-value-bind (value presentp _actual-path)
          (%flat-hash-get app-state full-path)
          (declare (ignore _actual-path))
          (cond
            (presentp value)
            ((nested-hash-state-p app-state component-path)
              (state-get app-state full-path default))
            (t default))))
      ((listp app-state)
        ;; Support plist states that omit the :components prefix in tests
        (let ((val (state-get app-state full-path :__missing__)))
          (if (eq val :__missing__)
            (let ((maybe (if (and full-path (eq (first full-path) :components))
                           (rest full-path)
                           full-path)))
              (state-get app-state maybe default))
            val)))
      (t (state-get app-state full-path default)))))

(defun set-component-state (ctx path value)
  "Function: SET-COMPONENT-STATE
Arguments:
  CTX (cycle-context) — The cycle context.
  PATH (list) — Key path in app state.
  VALUE (t) — Value to set.
Returns: VALUE
Type: (cycle-context, list, t) => t
Side-effects: Mutates app state and pushes PATCH to context.
"
  ;; Pushes a PATCH struct and sets value at PATH in app-state.
  (let* ((app-state (cycle-context-app-state ctx))
          (full-path (context-path-sanitizer ctx path t)))
    (push (make-patch :path full-path :value value)
      (cycle-context-patches ctx))
    (cond
      ((and (hash-table-p app-state)
         (not (nested-hash-state-p app-state (cycle-context-component-path ctx))))
        (multiple-value-bind (_ present actual-path)
          (%flat-hash-get app-state full-path)
          (declare (ignore _ present))
          (let ((key (or actual-path
                       (maybe-strip-components-prefix full-path)
                       full-path)))
            (setf (gethash key app-state) value))))
      (t
        (setf (cycle-context-app-state ctx)
          (state-set app-state full-path value))))))

;;;; ---------------------------
;;;;  Command Helpers
;;;; ---------------------------

(defmacro cmd> (thunk &key then err)
  "Register a command thunk with optional continuations.

  THUNK is a function of no arguments to execute.
   THEN is an optional function of one argument (the result) called on success.
   ERR is an optional function of one argument (the error info) called on failure.

   The command is recorded in the current cycle context with the component path.

   EXAMPLE USAGE:
     (cmd> (lambda () (format t \"Hello, World!~%\")))
     (cmd> (lambda () (do-something))
           :then (lambda (result) (format t \"Success: ~A~%\" result))
           :err  (lambda (error)  (format t \"Error: ~A~%\" error)))
   => Registers commands to be executed after the update cycle."
  `(push (make-command :thunk ,thunk :then ,then :err ,err
           :who  (cycle-context-component-path ctx))
     (cycle-context-commands ctx)))

(defmacro msg> (msg)
  "Register a pure message command.

  MSG is the message payload to wrap in a command thunk.

   EXAMPLE USAGE:
     (msg> :refresh)
     (msg> '(:update-data 42))
   => Registers a command that returns MSG when executed."
  `(cmd> (lambda () ,msg)))

;;;; ---------------------------
;;;;  Cycle Delimiters
;;;; ---------------------------

(defmacro >> ()
  "Return & clear patches/commands *without* ending the update."
  `(prog1
     (values (nreverse (cycle-context-patches  ctx))
       (nreverse (cycle-context-commands ctx)))
     (setf (cycle-context-patches  ctx) '()
       (cycle-context-commands ctx) '())))

(defmacro << (&optional (component-path '()))
  "Enter a (sub-)component context; clears accumulators."
  `(progn
     (setf (cycle-context-component-path ctx) ,component-path
       (cycle-context-patches  ctx) '()
       (cycle-context-commands ctx) '())
     ctx))

;;;; ---------------------------
;;;;  Utility
;;;; ---------------------------





;;; ---------------------------------------------------------------------------
;;;  Patch Application Utility
;;; ---------------------------------------------------------------------------

;; (defun merge-patch (state patches)
;;   "Apply a list of PATCH objects to STATE using state-patch generic.
;;    Returns the updated state. PATCHES may be PATCH structs or (path value) pairs."
;;   (state-patch state patches))

;;; ---------------------------------------------------------------------------
;;;  Command Processing Utility
;;; ---------------------------------------------------------------------------

(defun process-commands (commands)
  "Process a list of COMMAND structs.
   For each command, executes its thunk. If successful, calls :then continuation.
   If an error occurs, calls :err continuation and tags error with :who.
   Returns a list of results or error objects."
  (mapcar
    (lambda (cmd)
      (handler-case
        (let ((result (funcall (command-thunk cmd))))
          (if (command-then cmd)
            (funcall (command-then cmd) result)
            result))
        (error (e)
          (let ((err-fn (command-err cmd)))
            (if err-fn
              (funcall err-fn (list :error e :who (command-who cmd)))
              (list :error e :who (command-who cmd)))))))
    commands))

;;; ---------------------------------------------------------------------------
;;;  Linter Macro: check-state-access
;;; ---------------------------------------------------------------------------

;; (defmacro check-state-access (form)
;;   "Macro-expand FORM and signal a warning if (state> ...) is used inside a component context.
;;    Intended for use in tests or CI to catch improper global state access."
;;   (labels ((scan (expr)
;;              (cond
;;                ((and (consp expr)
;;                   (eq (car expr) 'state>))
;;                  (warn "Improper global state access: ~S" expr))
;;                ((consp expr)
;;                  (mapc #'scan expr)))))
;;     (scan (macroexpand-all form))
;;     form))
;;; ---------------------------------------------------------------------------
;;;  Ergonomic Sugar: setfn macro and path reader-macro
;;; ---------------------------------------------------------------------------

;; (defmacro setfn (place fn)
;;   "Functional update: (setfn (cstate> slot) fn) applies FN to the current value."
;;   (let ((val-sym (gensym "VAL")))
;;     `(let ((,val-sym ,place))
;;        (setf ,place (funcall ,fn ,val-sym)))))

(defmacro setfn (place fn)
  "Apply FN to PLACE, storing the result back into PLACE.
   Works with any SETF-able place."
  (multiple-value-bind (temps vals store-vars store-form access-form)
    (get-setf-expansion place)
    (let ((old (gensym "OLD")))
      `(let* (,@(mapcar #'list temps vals)
               (,old ,access-form))
         ;; `store-form` is the form that actually performs the setf.
         (let ((,(first store-vars) (funcall ,fn ,old)))
           ,store-form)))))

;; Reader macro for path literals: #P(:foo :bar) => '(:foo :bar)
(defun |#P-reader| (stream subchar arg)
  "Reader macro for path literals."
  (declare (ignore subchar arg))
  (let ((form (read stream t nil t)))
    form))

;; (set-dispatch-macro-character #\# #\P #'|#P-reader|)

;;; ---------------------------------------------------------------------------
;;;  FOOTER: Comparison & Integration Suggestion for Async Command Dispatch
;;; ---------------------------------------------------------------------------

;; Comparison:
;; - The process-commands utility in this DSL executes command thunks synchronously and handles continuations/errors inline.
;; - The async infrastructure in clevelib/async.lisp and core/async.lisp provides robust async-task, promise, and cancellation primitives,
;;   supporting thread pools, error handling, and promise chaining.
;; - core/async.lisp interprets commands as async tasks, batches, or dispatches, integrating with app-level sender and error restarts.
;; - event-async.lisp extends async dispatch to event channels, promises, timers, and event-driven workflows.
;; - threads.lisp provides macros for interruptible threads and condition signaling.

;; Recommendation:
;; To connect this DSL's command dispatch to the existing async facilities:
;; - Extend the command struct to support an :async flag or metadata.
;; - In process-commands, detect commands intended for async execution and wrap their thunk in a clevelib async-task (new-task, async-exec).
;; - Return or store the resulting promise in the command struct for later awaiting or cancellation.
;; - For integration with event channels, dispatch command results or errors via the appropriate event channel (see event-async.lisp).
;; - For batch or recurring commands, leverage core/async.lisp's cmd-batch and cmd-recurring utilities.
;; - For cancellation/interruption, expose the async-task or promise to the caller and use cancel-async-task or promise-cancel.

;; Example integration:
;;   (defun process-commands-async (commands)
;;     (mapcar (lambda (cmd)
;;               (if (command-async-p cmd)
;;                   (let ((task (cleve-elm.async:new-task (command-thunk cmd))))
;;                     (cleve-elm.async:async-exec task)
;;                     (setf (command-promise cmd) (async-task-promise task))
;;                     task)
;;                   (process-commands (list cmd))))
;;             commands))

;; This approach ensures that commands can be dispatched either synchronously or asynchronously,
;; leveraging the project's robust async infrastructure for scalable, cancellable, and event-driven workflows.

(uiop:define-package #:elmtui.update-dsl
  (:use #:cl #:sb-mop #:sb-thread #:elmtui.tea-state.api #:elmtui.update-dsl.api)
  (:import-from #:elmtui.tea-state.api
    #:application-state
    #:application-state-p
    #:application-state-data
    #:application-state-lock
    #:application-state-log
    #:application-state-history
    #:application-state-undone
    #:application-state-observers)
  (:import-from #:elmtui.core.errors
    #:state-error
    #:suggest-fixes
    )
  (:import-from #:elmtui.tea-state.transactions
    #:with-transaction
    #:apply-patches
    #:undo
    #:redo)
  (:import-from #:elmtui.tea-state.observers
    #:add-observer
    #:remove-observer)
  (:import-from #:alexandria
    #:when-let)
  (:reexport
    :elmtui.update-dsl.api)
  (:export
    ;; Application-State Specializations
    state-get
    state-set
    state-patch
    state-observe
    ;; Transaction Helpers
    with-update-transaction
    undo-update-state
    redo-update-state))

;;;; ---------------------------------------------------------------------------
;;;;  Application-State Specializations for update-dsl API
;;;; ---------------------------------------------------------------------------
;; (eval-when (:compile-toplevel :load-toplevel :execute)
;;   (unless (find-package :elmtui.tea-state.api)
;;     (error "elmtui.tea-state.api not loaded!")))

(in-package :elmtui.update-dsl)

;; --- Specialize generics for application-state ---

(defmethod elmtui.update-dsl.api:state-get ((state elmtui.tea-state.state:application-state) (path t)  &optional default)
  "Access value at PATH in application-state, using tea-state get-path."
  (elmtui.tea-state:get-path path state default))

(defmethod elmtui.update-dsl.api:state-set ((state elmtui.tea-state.state:application-state) (path t) value)
  "Set value at PATH in application-state, using tea-state state-set."
  (elmtui.tea-state.state:state-set state path value)
  state)

(defmethod elmtui.update-dsl.api:state-patch ((state elmtui.tea-state.state:application-state) patches)
  "Apply PATCHES to application-state using tea-state apply-patches."
  (elmtui.tea-state:apply-patches state
    (mapcar
      (lambda (patch)
        (if (typep patch 'patch)
          (list (elmtui.update-dsl.api::patch-path patch)
            (elmtui.update-dsl.api::patch-value patch))
          patch))
      patches)))

(defmethod elmtui.update-dsl.api:state-observe ((state elmtui.tea-state.state:application-state) key fn)
  "Register observer FN for KEY in application-state."
  (elmtui.tea-state:add-observer state key fn))

(defmethod elmtui.update-dsl.api:state-get ((state elmtui.tea-state:application-state) (path null) &optional default)
  "Access root data in application-state."
  (elmtui.tea-state:get-path nil state default))

(defmethod elmtui.update-dsl.api:state-set ((state elmtui.tea-state.state:application-state) (path null) value)
  "Set root data in application-state."
  (elmtui.tea-state.state:state-set state nil value))

;; --- Transaction helpers ---

(defun with-update-transaction (state name fn)
  "Run FN inside a tea-state transaction named NAME."
  (elmtui.tea-state:with-transaction (state :name name)
    (funcall fn state)))

(defun undo-update-state (state)
  "Undo last transaction in application-state."
  (elmtui.tea-state:undo state))

(defun redo-update-state (state)
  "Redo last undone transaction in application-state."
  (elmtui.tea-state:redo state))

;;;; ---------------------------------------------------------------------------
;;;;  End Application-State Specializations
;;;; ---------------------------------------------------------------------------
