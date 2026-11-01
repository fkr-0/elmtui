;;; == elmtui/app/tea-core.lisp ==

(uiop:define-package :elmtui.app.tea-core
  (:use :cl)
  (:import-from :elmtui.core.event-channels
    #:make-message-channel)
  (:import-from :elmtui.app.api
    #:make-runtime-app-spec
    #:app-config-message-queue)
  (:import-from :elmtui.app
    #:defapplication
    #:quit-requested-p)
  (:import-from :elmtui.core.globals #:*applications*)
  (:import-from :elmtui.state.api #:make-update-result #:state-ref)
  (:export
    #:deftea-app))

(in-package :elmtui.app.tea-core)

(defun %ensure-root-keyword (id)
  "Internal helper.

ID may be:
  - a keyword (returned as-is),
  - a symbol (its name is INTERNed in the KEYWORD package),
  - a string (INTERNed in the KEYWORD package).

Signals an error for all other types."
  (etypecase id
    (keyword id)
    (symbol  (intern (string id) :keyword))
    (string  (intern id :keyword))))

(defmacro deftea-app (name
                       &key
                       init
                       transition
                       update
                       view
                       subscriptions
                       command-processor
                       (root-viewport-id :root-viewport)
                       (anchor :below-cursor)
                       height
                       (handle-quit t))
  "Define a supported minimal direct-transition TEA application and RUN-NAME.

DEFTEA-APP is intentionally the small/pedagogical constructor, not the normative
full application constructor for the next stable major version. Use
ELMTUI.APP:DEFAPPLICATION for production application composition, component and
root-viewport initialization, CL-STATE patch/context updates, CLI/binary
configuration, keymaps, and selectable transaction semantics. DEFTEA-APP remains
compatible for direct model-replacement programs. It expands into
DEFAPPLICATION with :STRICT-ELM state semantics, keeping the model under the
:TEA-MODEL key of the application state, so both constructors share one runtime.
Ctrl-C quits; so does a transition that returns a plist model with :SHOULD-QUIT
true.

Syntax:

  (deftea-app NAME
    :init       INIT-FN
    :transition TRANSITION-FN
    :view       VIEW-FN
    &key
      :subscriptions      SUBS-FN
      :command-processor  CMD-FN
      :root-viewport-id   ROOT-ID
      :anchor             ANCHOR      ; default :BELOW-CURSOR
      :height             ROWS        ; default: sized by the content
      :handle-quit        BOOL)       ; default T; auto-handle :APP-QUIT-REQUESTED

Required arguments:

  NAME
    A non-keyword symbol naming the application. This is used to derive:

      * *NAME-APP-SPEC* — a DEFparameter holding the app spec plist
      * RUN-NAME        — the DEFAPPLICATION runner for the application

  :INIT
    A function designator (symbol or lambda) called with no arguments:

      INIT-FN :: () -> (values MODEL COMMANDS)

    MODEL
      Arbitrary application model object (often a plist or hash table).
    COMMANDS
      A list of \"commands\" understood by the command processor,
      or NIL if there are no startup side-effects.

  :TRANSITION
    The canonical direct transition function designator called for each message:

      TRANSITION-FN :: (MSG MODEL) -> (values NEXT-MODEL COMMANDS)

    :UPDATE is retained as a legacy compatibility alias for :TRANSITION. Do not
    specify both; new code should use :TRANSITION.

    MSG
      An arbitrary message object (often a keyword or small list).
    MODEL / NEXT-MODEL
      The current / next model. NEXT-MODEL must be suitable for
      subsequent calls to TRANSITION and VIEW.
    COMMANDS
      A list of commands to execute after the update, or NIL.

  :VIEW
    A function designator that renders the current model into a DSL tree:

      VIEW-FN :: MODEL -> DSL-TREE

    DSL-TREE
      A tree of view nodes understood by the rendering pipeline.
      In a typical setup the root node is a ROOT-VIEWPORT widget,
      often of the form:

        (:root-viewport :id ROOT-ID ...)

    where ROOT-ID matches the :ROOT-VIEWPORT-ID argument below.

Optional keywords:

  :SUBSCRIPTIONS
    A function designator

      SUBS-FN :: MODEL -> LIST-OF-SUBSCRIPTIONS

    or NIL.  If NIL, it is replaced with a function that always
    returns NIL.  This function is passed to the driver in the
    :SUBSCRIPTIONS-FN slot of the app spec and may be used by the
    event loop to (re-)establish subscriptions after each update.

  :COMMAND-PROCESSOR
    A function designator

      CMD-FN :: (CMD QUEUE MODEL APP-CONFIG) -> *

    or NIL.  If non-NIL, the driver calls it for each command
    produced by TRANSITION, passing:

      CMD        — the command object
      QUEUE      — the app's message queue (for enqueuing new MSGs)
      MODEL      — the current model *after* the update
      APP-CONFIG — optional configuration object (may be NIL)

    For a minimal TEA app you can omit this entirely.

  :ROOT-VIEWPORT-ID
    A symbol, keyword, or string naming the logical root viewport.
    It is converted to a keyword via a small helper and passed as
    :ROOT-VIEWPORT-ID in the app spec.  The platform driver uses this
    to compute the root component path.

    If omitted, defaults to :ROOT-VIEWPORT.

Expansion / side effects:

  (deftea-app NAME ...) expands to:

    - Adapter functions %TEA-INIT-NAME, %TEA-UPDATE-NAME, %TEA-VIEW-NAME and
      %TEA-SUBSCRIPTIONS-NAME that translate between the direct model and
      the application state (the model is stored under :TEA-MODEL; a new
      model becomes one patch). A view that returns a :ROOT-VIEWPORT tree is
      unwrapped to its children, because the application owns the viewport.

    - (DEFAPPLICATION NAME ...), which defines RUN-NAME:

        (RUN-NAME &key (platform :tty) platform-options argv
                       log-file log-buffer &allow-other-keys)

    - A DEFparameter *NAME-APP-SPEC*: the MAKE-RUNTIME-APP-SPEC plist of the
      generated application, for callers of ELMTUI.APP.API:RUN-APPLICATION.

Contracts / validation:

  * NAME must be a non-keyword symbol.
  * :INIT, :VIEW, and one of canonical :TRANSITION or legacy :UPDATE must be
    non-NIL and suitable as FUNCALL arguments (symbol or lambda).
  * :ROOT-VIEWPORT-ID must resolve to a keyword; an error is signaled
    at macro-expansion time for unsupported types.

  If the ELMTUI.CONTRACTS package is loaded and provides the function
  VALIDATE-ELM-APPLICATION, a sanity check is run once at load-time:

    (validate-elm-application UPDATE-FN VIEW-FN SUBS-FN)

  using a synthetic test model.  If this check fails, an error is
  signaled during load, so application contracts fail fast."
  ;; --- basic macro-time validation ------------------------------------
  (unless (and (symbolp name) (not (keywordp name)))
    (error "DEFTEA-APP: NAME must be a non-keyword symbol, got: ~S" name))

  (when (null init)
    (error "DEFTEA-APP ~S: :INIT is required." name))
  (when (and transition update)
    (error "DEFTEA-APP ~S: specify :TRANSITION or legacy :UPDATE, not both." name))
  (when (and (null transition) (null update))
    (error "DEFTEA-APP ~S: :TRANSITION is required (legacy :UPDATE is accepted)." name))
  (setf update (or transition update))
  (when (null view)
    (error "DEFTEA-APP ~S: :VIEW is required." name))

  (let* ((root-key (%ensure-root-keyword root-viewport-id))
         (app-spec-var (intern (format nil "*~A-APP-SPEC*" name)
                               (symbol-package name)))
         ;; Names DEFAPPLICATION generates (interned in *PACKAGE*, as it does).
         (init-fn-sym (intern (format nil "INITIALIZE-APP-STATE-~A" name)))
         (proc-fn-sym (intern (format nil "PROCESS-MESSAGE-~A" name)))
         (view-fn-sym (intern (format nil "WRAPPED-VIEW-~A" name)))
         (tea-init (intern (format nil "%TEA-INIT-~A" name)))
         (tea-update (intern (format nil "%TEA-UPDATE-~A" name)))
         (tea-view (intern (format nil "%TEA-VIEW-~A" name)))
         (tea-subscriptions (intern (format nil "%TEA-SUBSCRIPTIONS-~A" name)))
         (subs-expr (or subscriptions
                        '(lambda (model)
                           (declare (ignore model))
                           nil))))
    `(progn
       ;; --------------------------------------------------------------
       ;; 1. Adapters from the direct model to DEFAPPLICATION's state.
       ;;    The model lives under :TEA-MODEL of the application state.
       ;; --------------------------------------------------------------
       (defun ,tea-init ()
         (multiple-value-bind (model commands) (funcall ,init)
           (values (list :tea-model model :should-quit nil) commands)))

       (defun ,tea-update (message state)
         (let ((model (state-ref state :tea-model)))
           (multiple-value-bind (next commands) (funcall ,update message model)
             (make-update-result
              :patches (append
                        (unless (eq next model) `(((:tea-model) ,next)))
                        (when (or (quit-requested-p message)
                                  (and (listp next) (getf next :should-quit)))
                          '(((:should-quit) t))))
              :commands commands))))

       (defun ,tea-view (state)
         (%unwrap-root-viewport (funcall ,view (state-ref state :tea-model))))

       (defun ,tea-subscriptions (state)
         (funcall ,subs-expr (state-ref state :tea-model)))

       ;; --------------------------------------------------------------
       ;; 2. The application itself; this defines RUN-NAME.
       ;; --------------------------------------------------------------
       (defapplication ,name
         :root-viewport-id ,root-key
         :root-component-dsl '(:root-viewport :id ,root-key :anchor ,anchor
                               ,@(when height `(:height ,height))
                               :child-dsl-spec (:view nil))
         :initial-state-fn ',tea-init
         :update-fn ',tea-update
         :view-fn ',tea-view
         :subscriptions-fn ,tea-subscriptions
         ,@(when command-processor `(:command-processor-fn ,command-processor))
         :handle-quit ,handle-quit
         :state-semantics :strict-elm)

       ;; --------------------------------------------------------------
       ;; 3. The runtime spec, for callers of RUN-APPLICATION.
       ;; --------------------------------------------------------------
       (defparameter ,app-spec-var
         (make-runtime-app-spec
           :name ',name
           :init #',init-fn-sym
           :transition #',proc-fn-sym
           :view #',view-fn-sym
           :subscriptions #',tea-subscriptions
           :state-semantics :strict-elm
           :command-processor ,command-processor
           :message-queue (app-config-message-queue (gethash ',name *applications*))
           :root-viewport-id ',root-key)
         ,(format nil
            "Application spec for ~S.

This plist is consumed by ELMTUI.APP.API:RUN-APPLICATION and the
platform driver.  It is generated by DEFTEA-APP and normally not
modified directly at runtime." name))

       ;; --------------------------------------------------------------
       ;; 4. Optional contract validation (if elmtui.contracts is around)
       ;; --------------------------------------------------------------
       (when (fboundp 'elmtui.contracts:validate-elm-application)
         (elmtui.contracts:validate-elm-application
           ,update
           ,view
           ,subs-expr))

       ',name)))

(defun %unwrap-root-viewport (tree)
  "Return the content of a view TREE whose root is a :ROOT-VIEWPORT node.
DEFTEA-APP views may return the whole tree, root viewport included; the
application already owns that viewport, so only its children are rendered."
  (if (and (consp tree) (eq (first tree) :root-viewport))
      (let ((children (getf (rest tree) :children)))
        (if (and children (null (rest children)))
            (first children)
            `(:container :id :tea-view :children ,children)))
      tree))

;;; == end/tea-core.lisp ==
